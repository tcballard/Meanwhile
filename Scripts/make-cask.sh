#!/bin/zsh
set -euo pipefail

if (( $# < 3 || $# > 4 )); then
    echo "usage: $0 owner/repository version sha256 [unsigned]" >&2
    exit 64
fi

ROOT="${0:A:h:h}"
REPOSITORY="$1"
VERSION="$2"
SHA256="$3"
CHANNEL="${4:-stable}"
OUTPUT="${CASK_OUTPUT_PATH:-$ROOT/dist/meanwhile.rb}"

if [[ "$CHANNEL" == "unsigned" ]]; then
    DESCRIPTION="Unsigned pre-release of Meanwhile — for testing only"
    CAVEATS=$'\n  caveats <<~EOS\n    This is an unsigned pre-release for testing only. macOS Gatekeeper will\n    block its first launch. If you trust this build, explicitly remove quarantine:\n\n      xattr -dr com.apple.quarantine /Applications/Meanwhile.app\n  EOS'
else
    DESCRIPTION="Use coding-agent wait time for reviews and failing CI"
    CAVEATS=""
fi

mkdir -p "${OUTPUT:h}"
cat > "$OUTPUT" <<EOF
cask "meanwhile" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$REPOSITORY/releases/download/v#{version}/Meanwhile-#{version}.zip"
  name "Meanwhile"
  desc "$DESCRIPTION"
  homepage "https://github.com/$REPOSITORY"

  depends_on macos: :sonoma

  app "Meanwhile.app"

  zap trash: [
    "~/Library/Application Support/Meanwhile",
    "~/Library/Preferences/com.meanwhile.Meanwhile.plist",
  ]
$CAVEATS
end
EOF

echo "$OUTPUT"
