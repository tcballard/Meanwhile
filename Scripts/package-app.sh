#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-debug}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP="$ROOT/dist/Meanwhile.app"
CONTENTS="$APP/Contents"
BUILD_PATH="${SWIFT_BUILD_PATH:-$ROOT/.build}"

cd "$ROOT"
swift build --disable-sandbox --scratch-path "$BUILD_PATH" --configuration "$CONFIGURATION" --product Meanwhile >&2
swift build --disable-sandbox --scratch-path "$BUILD_PATH" --configuration "$CONFIGURATION" --product MeanwhileHook >&2
BIN_DIR="$(swift build --disable-sandbox --scratch-path "$BUILD_PATH" --configuration "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Helpers" "$CONTENTS/Resources"
cp "$ROOT/App/Info.plist" "$CONTENTS/Info.plist"
cp "$BIN_DIR/Meanwhile" "$CONTENTS/MacOS/Meanwhile"
cp "$BIN_DIR/MeanwhileHook" "$CONTENTS/Helpers/MeanwhileHook"
xattr -cr "$APP"

if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
    xattr -cr "$CONTENTS/Helpers/MeanwhileHook"
    codesign --force --sign - "$CONTENTS/Helpers/MeanwhileHook"
    xattr -cr "$CONTENTS/MacOS/Meanwhile"
    codesign --force --sign - "$CONTENTS/MacOS/Meanwhile"
    xattr -cr "$APP"
    codesign --force --sign - "$APP"
else
    xattr -cr "$CONTENTS/Helpers/MeanwhileHook"
    codesign --force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$CONTENTS/Helpers/MeanwhileHook"
    xattr -cr "$CONTENTS/MacOS/Meanwhile"
    codesign --force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$CONTENTS/MacOS/Meanwhile"
    xattr -cr "$APP"
    codesign --force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"

echo "$APP"
