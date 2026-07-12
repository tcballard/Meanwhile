#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repository}"

export CONFIGURATION=release
export CODE_SIGN_IDENTITY=-
export SWIFT_BUILD_PATH="${SWIFT_BUILD_PATH:-${TMPDIR:-/tmp}/meanwhile-unsigned-release-build}"
APP="$("$ROOT/Scripts/package-app.sh")"
BASE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
VERSION="$BASE_VERSION-unsigned"
ZIP="$ROOT/dist/Meanwhile-$VERSION.zip"

ditto -c -k --keepParent "$APP" "$ZIP"
SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
"$ROOT/Scripts/make-cask.sh" "$GITHUB_REPOSITORY" "$VERSION" "$SHA256" unsigned

echo "UNSIGNED PRE-RELEASE — FOR TESTING ONLY"
echo "$ZIP"
echo "$ROOT/dist/meanwhile.rb"
