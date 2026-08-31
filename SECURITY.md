# Security

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems.

Email the maintainer (see the git log / GitHub profile) with:

- A description of the issue
- Steps to reproduce
- Impact (for example: token theft, data leak, sandbox escape)

## Secrets

Never commit:

- `Shared/GoogleAuthSecrets.swift`
- OAuth client secrets or refresh tokens
- `oauth-tokens.json` from `~/Library/Application Support/com.googletasks.Tasks/`

Desktop OAuth client secrets are not as sensitive as server secrets, but they still identify *your* Google Cloud project. If one leaks, rotate it in [Google Cloud Console](https://console.cloud.google.com/apis/credentials).

## Tokens on disk

Signed-in tokens are stored under the App Group / Application Support folder so the widget can complete tasks. Treat that folder like a password store. Sign out in the app to delete them.
