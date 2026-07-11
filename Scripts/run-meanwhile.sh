#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$("$ROOT/Scripts/package-app.sh")"
open "$APP"
