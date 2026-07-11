#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-debug}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP="$ROOT/dist/Meanwhile.app"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build --disable-sandbox --configuration "$CONFIGURATION" --product Meanwhile
swift build --disable-sandbox --configuration "$CONFIGURATION" --product MeanwhileHook
BIN_DIR="$(swift build --disable-sandbox --configuration "$CONFIGURATION" --show-bin-path)"

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
