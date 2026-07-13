#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repository}"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/meanwhile-unsigned-release.XXXXXX")"
cleanup() {
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT INT TERM

export CONFIGURATION=release
export CODE_SIGN_IDENTITY=-
export SWIFT_BUILD_PATH="${SWIFT_BUILD_PATH:-${TMPDIR:-/tmp}/meanwhile-unsigned-release-build}"
export APP_OUTPUT_DIR="$TEMP_ROOT/package"

OUTPUT_DIR="${RELEASE_OUTPUT_DIR:-$ROOT/dist}"
mkdir -p "$OUTPUT_DIR"

APP="$("$ROOT/Scripts/package-app.sh")"
BASE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
VERSION="$BASE_VERSION-unsigned"
ZIP="$OUTPUT_DIR/Meanwhile-$VERSION.zip"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

VERIFY_DIR="$TEMP_ROOT/verify"
mkdir -p "$VERIFY_DIR"
ditto -x -k "$ZIP" "$VERIFY_DIR"
codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/Meanwhile.app"

SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
export CASK_OUTPUT_PATH="$OUTPUT_DIR/meanwhile.rb"
"$ROOT/Scripts/make-cask.sh" "$GITHUB_REPOSITORY" "$VERSION" "$SHA256" unsigned

echo "UNSIGNED PRE-RELEASE — FOR TESTING ONLY"
echo "$ZIP"
echo "$CASK_OUTPUT_PATH"
