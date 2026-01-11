# Sweep

Email inbox management app. Swipe to keep, archive the rest. See `~/code/brain/projects/sweep/CLAUDE.md` for full spec.

## Build & Run

```bash
# Build
xcodebuild -scheme Sweep -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build

# Or via Xcode
osascript -e 'tell application "Xcode" to build front workspace document'
osascript -e 'tell application "Xcode" to run front workspace document'

# DRY check
npx jscpd . --ignore "**/*.xcodeproj/**,**/Assets.xcassets/**"

# File line limit check (150 lines)
find . -name "*.swift" ! -path "*/.*" -exec awk 'END{if(NR>150)print NR" "FILENAME}' {} \; | sort -rn
```

## Tech Stack

- iOS 17+ / SwiftUI
- MVVM with ObservableObject
- Gmail API (OAuth 2.0)
- UserDefaults + SwiftData for local storage

## Rules

- **DRY (critical):** Search before adding code. Refactor to share. Non-DRY is a bug.
- **Logic out of Views:** Views render state + forward intent. Logic in ViewModels/Services.
- **Small units:** Functions ~25 lines, files ~150 lines, one type per file.
  - The line limit is about **separation of concerns**, not formatting tricks.
  - If a file is too long, extract logical components (helpers, subviews, services).
  - Do NOT reduce line count by cramming code onto single lines or removing whitespace.
- **Simplicity:** Prefer deleting code over adding code.
- **No comments:** Code is self-documenting.
- **Type safety:** No force unwraps, no Any.

## Session Protocol

1. Check git status and recent commits
2. Review spec in brain repo for current requirements
3. Run app to verify baseline
4. Work one feature at a time
