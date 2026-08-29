# Tasks for Mac

A native macOS widget that matches the system Reminders **List** widget — colored list header, circular checkboxes, due dates, interactive complete — and keeps the items in sync with [Google Tasks](https://tasks.google.com).

The widget lives on the desktop or in Notification Center. Checking an item off updates Google immediately. Clicking the widget opens the companion Tasks app.

Requires **macOS 14 Sonoma** or later and **Xcode 15+**.

## What you get

- **List widget** in Small, Medium, Large, and Extra Large, with the same layout language as Reminders: list color, 22pt ring checkboxes, hairline separators, Today / overdue dates, and an All Done empty state.
- **Interactive checkboxes** via WidgetKit App Intents — no need to open the app to complete a task.
- **Configurable list** — Control-click the widget → Edit Tasks → pick which Google list to show. Add as many widgets as you want, one per list.
- **Companion app** that looks like Reminders: sidebar of lists, circular checkboxes, new-task field, completed section.
- **Demo data** so you can run and add the widget before connecting Google.

## 1. Connect Google Tasks

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project (or pick an existing one).
3. Enable **Google Tasks API** under *APIs & Services → Library*.
4. Configure the OAuth consent screen (External is fine for personal use). Add yourself as a test user. Scopes used:
   - `https://www.googleapis.com/auth/tasks`
   - `https://www.googleapis.com/auth/userinfo.email`
5. *APIs & Services → Credentials → Create credentials → OAuth client ID*.
6. Application type: **Desktop app**.
7. Copy the client ID and client secret into `Shared/GoogleAuthConfig.swift`:

```swift
static let clientID = "123456789-abcdef.apps.googleusercontent.com"
static let clientSecret = "GOCSPX-your-secret"
```

Desktop clients already allow the `http://127.0.0.1` loopback redirect the app uses. You do not need to register a custom URL scheme.

Until those two strings are filled in, the app and widget run against a local demo list so you can still preview the UI.

## 2. Build and run

The widget uses App Sandbox and an App Group, so Xcode will not run it with “Sign to Run Locally”. You need a development certificate. A free Apple ID is enough — you do not need a paid Developer Program membership to run this on your own Mac.

1. Open `Tasks.xcodeproj` in Xcode.
2. If you are not signed in: **Xcode → Settings → Accounts → + → Apple ID**.
3. In the project navigator, click the blue **Tasks** project (top of the left sidebar).
4. Select the **Tasks** target → **Signing & Capabilities**.
5. Check **Automatically manage signing**.
6. Set **Team** to your name (Personal Team). If the menu says *None*, choose **Add an Account…**.
7. Select the **TasksWidget** target and repeat steps 5–6. Both targets must have the same Team.
8. Choose the **Tasks** scheme and a **My Mac** destination, then Run (⌘R).

If Xcode complains about the App Group `group.com.googletasks.Tasks`, open **Signing & Capabilities** on each target, click **+ Capability** → **App Groups**, and enable that group (or the `group.` identifier Xcode creates for your team). Update `Shared/AppGroup.swift` if the identifier changes.

## 3. Add the widget

1. Leave the app running at least once so macOS registers the extension.
2. Control-click the desktop (or open Notification Center) → **Edit Widgets**.
3. Search for **Tasks**.
4. Add **List**, then pick Small / Medium / Large / Extra Large.
5. Control-click the widget → **Edit Tasks** to choose a Google list.

Checking a circle completes that task in Google Tasks. The widget refreshes on its own about every 15 minutes, and immediately after you change something in the app or the widget.

## How sync works

```
Google Tasks API  ←→  Tasks.app  ←→  App Group snapshot  ←→  Widget
                              ↖ complete from widget (App Intent)
```

OAuth tokens live in the App Group container so the widget can complete tasks even when the main window is closed. The widget never runs the browser sign-in flow.

## Project layout

```
Tasks.xcodeproj     Xcode project (app + widget extension)
Tasks/              Companion macOS app
TasksWidget/        WidgetKit extension (Reminders-style List widget)
Shared/             Models, Google Tasks client, App Group store, intents
```

## Notes

- Google Task lists have no color of their own. Each list is assigned a stable color from the Reminders palette based on its id, so the widget still looks like a Reminders list.
- Completing a task from the widget hides it the same way Reminders does. Open the app and enable **Show Completed** to see it again.
- If sign-in fails, confirm the Tasks API is enabled and that your Google account is listed as a test user on the consent screen.
