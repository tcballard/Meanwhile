#!/bin/zsh
set -euo pipefail

if (( $# != 3 )); then
    echo "usage: $0 owner/repository version sha256" >&2
    exit 64
fi

ROOT="${0:A:h:h}"
REPOSITORY="$1"
VERSION="$2"
SHA256="$3"
OUTPUT="$ROOT/dist/meanwhile.rb"

mkdir -p "$ROOT/dist"
cat > "$OUTPUT" <<EOF
cask "meanwhile" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$REPOSITORY/releases/download/v#{version}/Meanwhile-#{version}.zip"
  name "Meanwhile"
  desc "Use coding-agent wait time for reviews and failing CI"
  homepage "https://github.com/$REPOSITORY"

  depends_on macos: ">= :sonoma"
  app "Meanwhile.app"

  zap trash: [
    "~/Library/Application Support/Meanwhile",
    "~/Library/Preferences/com.meanwhile.Meanwhile.plist",
  ]
end
EOF

echo "$OUTPUT"
