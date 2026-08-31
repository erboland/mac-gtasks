#!/bin/bash
# Build a distributable Tasks.dmg for GitHub Releases.
# Requires Shared/GoogleAuthSecrets.swift (gitignored) with a Desktop OAuth client.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f Shared/GoogleAuthSecrets.swift ]]; then
  echo "Missing Shared/GoogleAuthSecrets.swift — copy the example and paste your Google Desktop OAuth client." >&2
  exit 1
fi
if grep -q 'YOUR_CLIENT_ID\|YOUR_CLIENT_SECRET' Shared/GoogleAuthSecrets.swift; then
  echo "Shared/GoogleAuthSecrets.swift still has placeholders. Fill in a real OAuth client before packaging." >&2
  exit 1
fi

DERIVED="$ROOT/build/DerivedData"
STAGE="$ROOT/build/dmg-stage"
DMG="$ROOT/build/Tasks.dmg"

rm -rf "$DERIVED" "$STAGE" "$DMG"
mkdir -p "$STAGE"

xcodebuild_args=(
  -project Tasks.xcodeproj
  -scheme Tasks
  -configuration Release
  -destination 'platform=macOS'
  -derivedDataPath "$DERIVED"
)

if [[ "${CI:-}" == "true" ]]; then
  # GitHub-hosted runners do not have a Developer ID. Ad-hoc sign so the
  # archive still produces Tasks.app. Other Macs will need Control-click → Open.
  xcodebuild_args+=(
    CODE_SIGN_IDENTITY="-"
    CODE_SIGNING_ALLOWED=YES
    CODE_SIGNING_REQUIRED=YES
    DEVELOPMENT_TEAM=
  )
fi

xcodebuild "${xcodebuild_args[@]}" build

APP="$DERIVED/Build/Products/Release/Tasks.app"
if [[ ! -d "$APP" ]]; then
  echo "Build succeeded but Tasks.app was not found at $APP" >&2
  exit 1
fi

cp -R "$APP" "$STAGE/Tasks.app"
ln -s /Applications "$STAGE/Applications"

# UDZO is a compressed read-only image suitable for GitHub Releases.
hdiutil create \
  -volname "Tasks" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "Created $DMG"
echo "Attach this file to a GitHub Release. Other Macs will need a Developer ID + notarized build to open it without Gatekeeper warnings."
