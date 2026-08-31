# Privacy Policy

Public copy: [erboland.github.io/mac-gtasks/privacy.html](https://erboland.github.io/mac-gtasks/privacy.html)

Tasks for Mac (“Tasks”) is a native macOS app and desktop widget that syncs with Google Tasks. It does not run its own servers.

## What we collect

Sign-in uses Google OAuth on your Mac. The app requests:

- `https://www.googleapis.com/auth/tasks` — read and update your Google Task lists
- `https://www.googleapis.com/auth/userinfo.email` — your Google account email, shown in the sidebar

## Where data lives

- OAuth tokens and a local copy of your lists are stored on your Mac (App Group / Application Support for `com.googletasks.Tasks`).
- Completing a task in the widget or the app sends that change to Google’s Tasks API.
- Nothing is sent to the app’s author.

## What we do not do

- No analytics SDK
- No advertising
- No account other than the Google account you sign in with

## Sign out

Use **Sign Out** in the sidebar to delete the local tokens and restore sample tasks.

## Contact

Open a GitHub issue on [erboland/mac-gtasks](https://github.com/erboland/mac-gtasks).
