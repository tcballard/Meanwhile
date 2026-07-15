#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
pkill -x Meanwhile 2>/dev/null || true
APP="$("$ROOT/Scripts/package-app.sh")"
open "$APP"
