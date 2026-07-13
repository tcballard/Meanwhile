#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
: "${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY to a Developer ID Application identity}"
: "${NOTARYTOOL_PROFILE:?Set NOTARYTOOL_PROFILE to an xcrun notarytool keychain profile}"
: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repository}"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/meanwhile-release.XXXXXX")"
cleanup() {
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT INT TERM

export CONFIGURATION=release
export SWIFT_BUILD_PATH="${SWIFT_BUILD_PATH:-${TMPDIR:-/tmp}/meanwhile-release-build}"
export APP_OUTPUT_DIR="$TEMP_ROOT/package"

OUTPUT_DIR="${RELEASE_OUTPUT_DIR:-$ROOT/dist}"
mkdir -p "$OUTPUT_DIR"

APP="$("$ROOT/Scripts/package-app.sh")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ZIP="$OUTPUT_DIR/Meanwhile-$VERSION.zip"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

VERIFY_DIR="$TEMP_ROOT/verify"
mkdir -p "$VERIFY_DIR"
ditto -x -k "$ZIP" "$VERIFY_DIR"
VERIFIED_APP="$VERIFY_DIR/Meanwhile.app"
codesign --verify --deep --strict --verbose=2 "$VERIFIED_APP"
spctl --assess --type execute --verbose=2 "$VERIFIED_APP"
xcrun stapler validate "$VERIFIED_APP"

SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
export CASK_OUTPUT_PATH="$OUTPUT_DIR/meanwhile.rb"
"$ROOT/Scripts/make-cask.sh" "$GITHUB_REPOSITORY" "$VERSION" "$SHA256"

echo "$ZIP"
echo "$CASK_OUTPUT_PATH"
