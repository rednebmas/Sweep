# Notification & Lifecycle Bugfixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix three notification/lifecycle bugs: (1) badge not incrementing, (2) app not refreshing when opened via notification tap, (3) stale emails briefly displayed (~2s) when returning from background due to suspended Task.

**Architecture:** Bug 1: Add badge count to APNs payload in backend. Bug 2: Post NotificationCenter notification on push tap, observe in SweepApp to trigger refresh. Bug 3: Use `beginBackgroundTask` to ensure processing completes before iOS suspends the app.

**Tech Stack:** iOS 17+ / SwiftUI / UserNotifications / APNS

---

## Bug Analysis

### Bug 1: Badge Not Incrementing
**Root Cause:** The `sendNotification` function in `server/functions/src/apns.ts` builds the APNs payload without a `badge` field. iOS only updates the app badge when the push payload includes `"badge": N`.

**Fix:** Add `badge` parameter to `sendNotification()` and include `pendingEmails.length` in the APNs payload. The client already handles badges correctly (`.badge` in presentation options).

### Bug 2: No Refresh on Notification Tap
**Root Cause:** When user taps a notification (not the "Mark All Read" action), `didReceive` calls `completionHandler()` immediately without triggering any refresh. The app opens but `scenePhase` changing to `.active` doesn't trigger `loadThreads()`.

**Fix:** Post a notification when a push is tapped, observe it in SweepApp, trigger `loadThreads()`.

### Bug 3: Stale Emails Briefly Displayed on Return (~2s)
**Root Cause:** When app enters background, a Task is created for `processNonKeptThreads()`. iOS suspends the app before this Task completes (network call interrupted). When user returns, the Task **resumes** and takes ~2s to complete the network call before `threads.removeAll` executes.

**Fix:** Use `UIApplication.beginBackgroundTask` to request execution time. This tells iOS we have critical work to complete, giving us ~30s before suspension. The Task will finish while backgrounded, so `threads` is already empty when user returns.

---

### Task 1: Request Background Execution Time (Bug 3 Fix)

**Files:**
- Modify: `Sweep/SweepApp.swift:59-70`

**Step 1: Review current implementation**

Current flow in SweepApp.swift:
```swift
.onChange(of: scenePhase) {
    if scenePhase == .background {
        Task {
            await viewModel.processNonKeptThreads()  // iOS suspends before this completes
        }
    }
    // ...
}
```

The Task is created but iOS suspends the app before it finishes. When the user returns, the Task resumes and takes ~2s to complete.

**Step 2: Wrap in background task request**

Use `UIApplication.beginBackgroundTask` to request execution time. This tells iOS we have critical work that needs to complete.

In `Sweep/SweepApp.swift`, replace the background handling (lines 60-63):

```swift
if scenePhase == .background {
    let app = UIApplication.shared
    var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    backgroundTaskId = app.beginBackgroundTask {
        app.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }
    Task {
        await viewModel.processNonKeptThreads()
        if backgroundTaskId != .invalid {
            app.endBackgroundTask(backgroundTaskId)
        }
    }
}
```

**Step 3: Build and verify**

Run: `xcodebuild -scheme Sweep -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build`
Expected: Build succeeds

**Step 4: Manual test**

1. Open app with emails displayed
2. Press home button to background
3. Wait 30+ seconds
4. Return to app
5. Expected: Empty inbox immediately (no brief stale display)

**Step 5: Commit**

```bash
git add Sweep/SweepApp.swift
git commit -m "$(cat <<'EOF'
fix: Request background execution time for email processing

Wrap processNonKeptThreads in beginBackgroundTask to ensure the
network call completes before iOS suspends the app. Prevents stale
emails from briefly displaying when user returns from background.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Refresh on Notification Tap (Bug 2 Fix)

**Files:**
- Modify: `Sweep/Services/NotificationDelegate.swift:15-27`
- Modify: `Sweep/SweepApp.swift:59-70`

**Step 1: Add notification name constant to NotificationDelegate**

In `Sweep/Services/NotificationDelegate.swift`, add after line 9 (after `static let shared`):

```swift
static let didTapNotification = Notification.Name("NotificationDelegate.didTapNotification")
```

**Step 2: Post notification when push is tapped**

In `Sweep/Services/NotificationDelegate.swift`, modify `userNotificationCenter(_:didReceive:withCompletionHandler:)` (lines 15-27):

```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    if response.actionIdentifier == NotificationService.markAllReadAction {
        Task {
            await handleMarkAllRead()
            completionHandler()
        }
    } else {
        // User tapped the notification itself (default action)
        NotificationCenter.default.post(name: Self.didTapNotification, object: nil)
        completionHandler()
    }
}
```

**Step 3: Observe notification in SweepApp and trigger refresh**

In `Sweep/SweepApp.swift`, modify the `WindowGroup` section to add an `onReceive`:

Add import at top if not present (it should already be there via SwiftUI):
```swift
import Combine
```

After the `.onChange(of: scenePhase)` block (after line 70), add:

```swift
.onReceive(NotificationCenter.default.publisher(for: NotificationDelegate.didTapNotification)) { _ in
    Task {
        await viewModel.loadThreads()
    }
}
```

**Step 4: Build and verify**

Run: `xcodebuild -scheme Sweep -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build`
Expected: Build succeeds

**Step 5: Manual test**

1. Background the app
2. Send a test push notification (via backend or simulator push)
3. Tap the notification banner
4. Expected: App opens AND shows fresh emails (not old state)

**Step 6: Commit**

```bash
git add Sweep/Services/NotificationDelegate.swift Sweep/SweepApp.swift
git commit -m "$(cat <<'EOF'
fix: Refresh email list when app opened via notification tap

Post NotificationCenter notification when user taps push notification,
observe in SweepApp to trigger loadThreads() refresh.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Add Badge Count to Push Notifications (Bug 1 Fix)

**Files:**
- Modify: `server/functions/src/apns.ts:51-109`
- Modify: `server/functions/src/index.ts:72,142`

**Step 1: Add badge parameter to sendNotification**

In `server/functions/src/apns.ts`, modify the `sendNotification` function signature (line 51) to accept a badge count:

```typescript
export function sendNotification(deviceToken: string, title: string, body: string, badge: number): Promise<APNsResult> {
```

**Step 2: Add badge to APNs payload**

In `server/functions/src/apns.ts`, modify the payload (lines 56-63) to include badge:

```typescript
const payload = JSON.stringify({
  aps: {
    alert: { title, body },
    badge,
    'mutable-content': 1,
    'interruption-level': 'passive',
    category: 'NEW_EMAIL'
  }
});
```

**Step 3: Update Gmail notification handler**

In `server/functions/src/index.ts`, modify the Gmail sendNotification call (line 72):

```typescript
await sendNotification(user.deviceToken, title, body, pendingEmails.length);
```

**Step 4: Update Outlook notification handler**

In `server/functions/src/index.ts`, modify the Outlook sendNotification call (line 142):

```typescript
await sendNotification(user.deviceToken, title, body, pendingEmails.length);
```

**Step 5: Build and verify**

```bash
cd server/functions && npm run build
```
Expected: Build succeeds with no TypeScript errors

**Step 6: Commit**

```bash
git add server/functions/src/apns.ts server/functions/src/index.ts
git commit -m "$(cat <<'EOF'
fix: Include badge count in push notifications

Add badge parameter to sendNotification and include pendingEmails.length
in APNs payload so iOS updates the app icon badge on new emails.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Summary

| Bug | Root Cause | Fix Location | Type |
|-----|-----------|--------------|------|
| Badge not incrementing | APNs payload missing badge field | Backend | Code change |
| No refresh on notification tap | No handler for default notification action | Client | Code change |
| Stale emails on return | Task suspended before completion | Client | Code change |

---

## Verification Checklist

After all tasks complete:

- [ ] iOS build succeeds: `xcodebuild -scheme Sweep -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build`
- [ ] Backend build succeeds: `cd server/functions && npm run build`
- [ ] Background app → return after 30s → no stale emails displayed
- [ ] Tap notification → app refreshes with new emails
- [ ] Receive push → badge increments on app icon
