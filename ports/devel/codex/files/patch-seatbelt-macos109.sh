#!/bin/sh
set -eu

src=${1:?usage: patch-seatbelt-macos109.sh source-root}
dir="$src/codex-rs/sandboxing/src"

rewrite() {
    target=$1
    generated=$2
    test -s "$generated"
    /bin/mv -f "$generated" "$target"
}

# Basispolicy: Mavericks kennt mehrere spaeter eingefuehrte Filter nicht.
base="$dir/seatbelt_base_policy.sbpl"
base_new="$base.macos109-new"
/usr/bin/awk '
    /\(allow process-info\* \(target same-sandbox\)\)/ {
        print "; macOS 10.9: target filters are unsupported for process-info*."
        print "(allow process-info*)"
        process_fixed = 1
        next
    }
    /\(path "\/dev\/null"\)/ {
        print "    (literal \"/dev/null\")"
        path_fixed = 1
        next
    }
    /\(allow ipc-posix-shm-read\* \(ipc-posix-name-prefix "apple.cfprefs\."\)\)/ {
        print "; macOS 10.9 lacks ipc-posix-name-prefix filters."
        print "(allow ipc-posix-shm-read*)"
        next
    }
    /^; sysctls permitted\.$/ {
        print "; macOS 10.9 lacks sysctl-name filters; reads remain read-only."
        print "(allow sysctl-read)"
        print ""
        print "; macOS 10.9 lacks iokit-registry-entry-class filters."
        print "(allow iokit-open)"
        skip_modern = 1
        next
    }
    skip_modern && /^; needed to look up user info/ {
        skip_modern = 0
        print ""
        print
        next
    }
    skip_modern { next }
    { print }
    END {
        if (!process_fixed || !path_fixed || skip_modern)
            exit 2
    }
' "$base" > "$base_new" || {
    /bin/rm -f "$base_new"
    echo "FEHLER: unerwartete Upstream-Basispolicy; Mavericks-Transformation abgebrochen" >&2
    exit 1
}
rewrite "$base" "$base_new"

# Der pfadgefilterte Unix-Socket-Matcher wurde erst nach Mavericks eingefuehrt.
# Ein breites deny bewahrt die Sicherheitsgrenze zum privilegierten Codex-Daemon;
# sandboxierte Befehle koennen auf 10.9 dafuer keine Unix-Sockets nach aussen nutzen.
daemon="$dir/seatbelt_daemon.rs"
daemon_new="$daemon.macos109-new"
/usr/bin/grep -Fq '(deny network-outbound (remote unix-socket (subpath {quoted})))' "$daemon" || {
    echo "FEHLER: unerwartete Daemon-Socket-Policy" >&2
    exit 1
}
/usr/bin/sed 's/(deny network-outbound (remote unix-socket (subpath {quoted})))/(deny network-outbound (remote unix-socket))/' \
    "$daemon" > "$daemon_new"
/usr/bin/grep -Fq '(deny network-outbound (remote unix-socket))' "$daemon_new" || {
    /bin/rm -f "$daemon_new"
    echo "FEHLER: Daemon-Socket-Policy konnte nicht transformiert werden" >&2
    exit 1
}
rewrite "$daemon" "$daemon_new"

# xpc-service-name-prefix und system-fcntl/fcntl-command sind neuere
# Seatbelt-Filter. Mavericks behandelt die Namen als ungebundene Variablen und
# verwirft das gesamte Profil. Die von der zweiten Regel geschuetzten Kommandos
# F_MAKECOMPRESSED=80 und F_TRANSFEREXTENTS=110 gibt es im 10.9-SDK nicht.
# Die Basispolicy beginnt bereits mit (deny default), sodass unbekannte
# Mach-/XPC-Lookups auch ohne diesen zusaetzlichen modernen Catch-all gesperrt
# bleiben; nur die explizit erlaubten global-name-Dienste werden geoeffnet.
seatbelt="$dir/seatbelt.rs"
seatbelt_new="$seatbelt.macos109-new"
if test "$(/usr/bin/grep -c 'xpc-service-name-prefix' "$seatbelt")" -ne 1 || \
        ! /usr/bin/grep -Fq 'policy_sections.push("(deny mach-lookup (xpc-service-name-prefix \"\"))".to_string());' "$seatbelt" || \
        test "$(/usr/bin/grep -c 'system-fcntl' "$seatbelt")" -ne 1 || \
        ! /usr/bin/grep -Fq 'policy_sections.push("(deny system-fcntl (fcntl-command 80 110))".to_string());' "$seatbelt"; then
    echo "FEHLER: unerwartete dynamische Mavericks-Seatbelt-Policy" >&2
    exit 1
fi
/usr/bin/sed -e '/xpc-service-name-prefix/d' -e '/deny system-fcntl/d' \
    "$seatbelt" > "$seatbelt_new"
if /usr/bin/grep -q 'xpc-service-name-prefix\|system-fcntl' "$seatbelt_new"; then
    /bin/rm -f "$seatbelt_new"
    echo "FEHLER: dynamische Mavericks-Seatbelt-Policy konnte nicht transformiert werden" >&2
    exit 1
fi
rewrite "$seatbelt" "$seatbelt_new"

# Preferences: der Namenspraefix-Filter existiert auf 10.9 noch nicht.
prefs="$dir/seatbelt_preferences_policy.sbpl"
if test -f "$prefs"; then
    /usr/bin/grep -q 'ipc-posix-name-prefix "apple.cfprefs."' "$prefs" || {
        echo "FEHLER: unerwartete Preferences-Policy" >&2
        exit 1
    }
    /usr/bin/sed 's/(allow ipc-posix-shm-read\* (ipc-posix-name-prefix "apple.cfprefs."))/(allow ipc-posix-shm-read*)/' \
        "$prefs" > "$prefs.macos109-new"
    rewrite "$prefs" "$prefs.macos109-new"
fi

# Network: sysctl-read ist bereits in der Basispolicy erlaubt; der Regexfilter
# ist auf Mavericks unbekannt.
network="$dir/seatbelt_network_policy.sbpl"
/usr/bin/grep -q 'sysctl-name-regex' "$network" || {
    echo "FEHLER: unerwartete Network-Policy" >&2
    exit 1
}
/usr/bin/awk '
    /^\(allow sysctl-read$/ { skip = 1; next }
    skip && /^\)$/ { skip = 0; removed = 1; next }
    skip { next }
    { print }
    END { if (!removed || skip) exit 2 }
' "$network" > "$network.macos109-new" || {
    /bin/rm -f "$network.macos109-new"
    echo "FEHLER: Network-sysctl-Block konnte nicht entfernt werden" >&2
    exit 1
}
rewrite "$network" "$network.macos109-new"

# Restricted defaults enthalten APFS-/Container-Operationen und Filter, die es
# auf 10.9 nicht gibt. Die zugehoerigen modernen Pfade/Funktionen existieren auf
# Mavericks ebenfalls nicht; Dateilesen wird auf die alte Operation abgebildet.
restricted="$dir/seatbelt_read_only_platform_defaults.sbpl"
restricted_new="$restricted.macos109-new"
/usr/bin/grep -q 'file-test-existence' "$restricted" || {
    echo "FEHLER: unerwartete Restricted-Read-Policy" >&2
    exit 1
}
/usr/bin/sed -e 's/ file-test-existence//g' -e 's/file-map-executable/file-read*/g' "$restricted" | \
/usr/bin/awk '
    /^; Allow guarded vnodes\.$/ { skip = 1; next }
    skip && /^; Allow resolution of standard system symlinks\.$/ {
        skip = 0; print; next
    }
    /^; Allow stat.interior.*firmlink parent path components\.$/ ||
    /^; Allow stat.ing of firmlink parent path components\.$/ {
        skip_firmlink = 1; next
    }
    skip_firmlink && /^; Allow processes to get their current working directory\.$/ {
        skip_firmlink = 0; print; next
    }
    /^; Allow FSIOC_CAS_BSDFLAGS as alternate chflags\.$/ {
        skip_fsctl = 1; next
    }
    skip_fsctl && /^; Allow access to standard special files\.$/ {
        skip_fsctl = 0; print; next
    }
    /^; IOKit access for root domain services\.$/ {
        print "; macOS 10.9 lacks iokit-registry-entry-class filters."
        print "(allow iokit-open)"
        skip_iokit = 1
        next
    }
    skip_iokit && /^; macOS Standard library queries/ {
        skip_iokit = 0; print ""; print; next
    }
    skip || skip_firmlink || skip_fsctl || skip_iokit { next }
    { print }
    END {
        if (skip || skip_firmlink || skip_fsctl || skip_iokit) exit 2
    }
' > "$restricted_new" || {
    /bin/rm -f "$restricted_new"
    echo "FEHLER: Restricted-Read-Policy konnte nicht transformiert werden" >&2
    exit 1
}
rewrite "$restricted" "$restricted_new"

echo "Mavericks Seatbelt source transformation: OK"
