#!/bin/sh
set -eu

libexec=${1:?usage: codex-macos109-audit.sh staged-libexec-dir}

for binary in \
    "$libexec/bin/codex" \
    "$libexec/bin/codex-code-mode-host" \
    "$libexec/codex-path/rg" \
    "$libexec/libnsworkspace_shim.dylib"
do
    test -f "$binary"
    target=$(/usr/bin/otool -l "$binary" | /usr/bin/awk '
        /LC_VERSION_MIN_MACOSX/ { in_min = 1; next }
        in_min && /version/ { print $2; exit }
    ')
    if test "$target" != 10.9; then
        /usr/bin/printf '%s\n' "FEHLER: $binary hat Deployment Target ${target:-unbekannt}, erwartet 10.9" >&2
        exit 1
    fi
done

/usr/bin/printf '%s\n' 'Codex Mach-O deployment-target audit: OK (10.9)'
