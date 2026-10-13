#!/bin/zsh
set -eu
cd "$(dirname "$0")"
if [[ ! -x dist/DesktopFly.app/Contents/MacOS/DesktopFly ]]; then
    ./package-app.sh
fi
open dist/DesktopFly.app
