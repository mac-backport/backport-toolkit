#!/bin/sh
set -eu

binary=${1:?usage: ripgrep-macos109-audit.sh staged-rg-binary}
test -f "$binary"

target=$(/usr/bin/otool -l "$binary" | /usr/bin/awk '
    /LC_VERSION_MIN_MACOSX/ { in_min = 1; next }
    in_min && /version/ { print $2; exit }
')

if test "$target" != 10.9; then
    /usr/bin/printf '%s\n' \
        "FEHLER: $binary hat Deployment Target ${target:-unbekannt}, erwartet 10.9" >&2
    exit 1
fi

/usr/bin/printf '%s\n' 'ripgrep Mach-O deployment-target audit: OK (10.9)'
