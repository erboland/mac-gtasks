# Contributing

Thanks for helping improve Tasks for Mac.

## Development setup

1. macOS 14+ and Xcode 15+.
2. `cp Shared/GoogleAuthSecrets.example.swift Shared/GoogleAuthSecrets.swift` and fill in a Desktop OAuth client (see the README). The first Xcode build also copies the example if the file is missing.
3. Open `Tasks.xcodeproj`, set your **Team** on both the Tasks and TasksWidget targets, then Run.

## Ground rules

- Do not commit `Shared/GoogleAuthSecrets.swift` or any OAuth tokens.
- Match the existing Swift style: small types, no extra abstractions, Reminders-like UI.
- Keep the App Sandbox on. Prefer Application Support + the documented home-relative entitlements over turning sandbox off.
- Widget and app must stay able to complete the same task. If you change `Shared/`, check both.

## Pull requests

- One focused change per PR.
- Describe *why*, not only *what*.
- If you touch UI, note what you verified (app list switch, complete a task, widget checkbox).
