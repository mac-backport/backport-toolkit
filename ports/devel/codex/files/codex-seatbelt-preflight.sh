#!/bin/sh
set -eu

src=${1:?usage: codex-seatbelt-preflight.sh source-root}
policy_dir="$src/codex-rs/sandboxing/src"
sandbox=/usr/bin/sandbox-exec

# MacPorts fuehrt die Build-Phasen selbst in einem sandbox-exec aus; sandbox-exec
# laesst sich auf Mavericks NICHT verschachteln (sandbox_apply_container:
# Operation not permitted, Exit 71). In diesem Fall kann der Parser-Test nicht
# laufen -> sauber ueberspringen statt den Build faelschlich abzubrechen. Der Check
# bleibt bei manueller Ausserhalb-der-Sandbox-Ausfuehrung voll wirksam.
if ! "$sandbox" -p '(version 1)(allow default)' /usr/bin/true >/dev/null 2>&1; then
    /usr/bin/printf '%s\n' \
        'Mavericks Seatbelt parser preflight: SKIPPED (laeuft in MacPorts-Sandbox; sandbox-exec nicht verschachtelbar)'
    exit 0
fi

test_fragment() {
    file=$1
    {
        /usr/bin/printf '%s\n' '(version 1)' '(deny default)' \
            '(allow process-exec)' '(allow file-read*)'
        /bin/cat "$file"
    } | /usr/bin/env DYLD_INSERT_LIBRARIES= DYLD_FORCE_FLAT_NAMESPACE= \
        "$sandbox" -f /dev/stdin /usr/bin/true
}

{
    /bin/cat "$policy_dir/seatbelt_base_policy.sbpl"
    # Nur der Parser-Test braucht dies, damit /usr/bin/true libSystem laden kann.
    /usr/bin/printf '%s\n' '(allow file-read*)'
} | /usr/bin/env DYLD_INSERT_LIBRARIES= DYLD_FORCE_FLAT_NAMESPACE= \
    "$sandbox" -f /dev/stdin /usr/bin/true
if test -f "$policy_dir/seatbelt_preferences_policy.sbpl"; then
    test_fragment "$policy_dir/seatbelt_preferences_policy.sbpl"
fi
test_fragment "$policy_dir/seatbelt_network_policy.sbpl"
test_fragment "$policy_dir/seatbelt_read_only_platform_defaults.sbpl"

# Die auf Mavericks unbekannten xpc-service-name-prefix- und system-fcntl-
# Regeln muessen entfernt sein. Die geschlossene Basispolicy bleibt die sichere
# Rueckfallebene; die geschuetzten Fcntl-Kommandos existieren auf 10.9 nicht.
/usr/bin/grep -Fq '(deny default)' "$policy_dir/seatbelt_base_policy.sbpl"
if /usr/bin/grep -q 'xpc-service-name-prefix\|system-fcntl' "$policy_dir/seatbelt.rs"; then
    /usr/bin/printf '%s\n' \
        'FEHLER: Mavericks-unbekannter dynamischer Seatbelt-Filter verblieben' >&2
    exit 1
fi

# Repraesentative dynamisch von seatbelt.rs erzeugte Regeln.
for fragment in \
    '(allow system-socket (socket-domain AF_UNIX))' \
    '(allow network-bind (local unix-socket))' \
    '(allow network-outbound (remote unix-socket))' \
    '(deny network-outbound (remote unix-socket))' \
    '(allow network-bind (local ip "*:*") )' \
    '(allow network-outbound (remote ip "localhost:1234"))' \
    '(deny file-ioctl (ioctl-command 2147578994))' \
    '(deny file-write-unlink (require-all (vnode-type DIRECTORY) (literal "/tmp/codex-test")))' \
    '(allow file-write* (require-all (subpath "/tmp") (require-not (subpath "/tmp/codex-test"))))'
do
    /usr/bin/env DYLD_INSERT_LIBRARIES= DYLD_FORCE_FLAT_NAMESPACE= \
        "$sandbox" -p "(version 1) (deny default) (allow process-exec) (allow file-read*) $fragment" \
        /usr/bin/true
done

/usr/bin/printf '%s\n' 'Mavericks Seatbelt parser preflight: OK'
