# Sweep

Email inbox management app. Swipe to keep, archive the rest. See `~/code/brain/projects/sweep/CLAUDE.md` for full spec.

## Build & Run

```bash
# Build
xcodebuild -scheme Sweep -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build

# DRY check
npx jscpd . --ignore "**/*.xcodeproj/**,**/Assets.xcassets/**"

# File line limit check (200 lines)
find . -name "*.swift" ! -path "*/.*" -exec awk 'END{if(NR>200)print NR" "FILENAME}' {} \; | sort -rn
```

## Tech Stack

- iOS 17+ / SwiftUI
- MVVM with ObservableObject
- Gmail API (OAuth 2.0)
- UserDefaults + SwiftData for local storage

## Rules

- **DRY (CRITICAL):** Search before adding code. Refactor to share. NON-DRY CODE IS A BUG. YOU ARE NOT ALLOWED TO WRITE CODE THAT IS REPETITIVE. ALWAYS CHECK jscpd AFTER MAKING CHANGES.
- **Logic out of Views:** Views render state + forward intent. Logic in ViewModels/Services.
- **Small units:** Functions ~25 lines, files ~150 lines, one type per file.
  - The line limit is about **separation of concerns**, not formatting tricks.
  - If a file is too long, extract logical components (helpers, subviews, services).
  - Do NOT reduce line count by cramming code onto single lines or removing whitespace.
- **Simplicity:** Prefer deleting code over adding code.
- **No comments:** Code is self-documenting.
- **Type safety:** No force unwraps, no Any.

## Push Notifications (Production Checklist)

Before releasing to production, update these settings:

1. **APNs Environment** - In `deploy-functions.sh`, remove or set `APNS_SANDBOX=false`:
   ```bash
   --set-env-vars="APNS_SANDBOX=false"  # or remove the line entirely
   ```

2. **iOS Entitlements** - In `Sweep/Sweep.entitlements`, change:
   ```xml
   <key>aps-environment</key>
   <string>production</string>  <!-- change from "development" -->
   ```

3. **Redeploy** - Run `./server/scripts/deploy-functions.sh` after changes

## Testing Accounts

- **Outlook:** sweep.app.testing@outlook.com / Testing1!
- **Gmail:** sweep.app.testing@gmail.com / Testing1!
