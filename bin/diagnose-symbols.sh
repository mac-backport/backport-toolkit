#!/bin/bash
# diagnose-symbols.sh <mach-o-binary-oder-dylib> [weitere...]
# Zeigt fuer ein Prebuilt-Binary, welche undefinierten Symbole auf macOS 10.9
# FEHLEN und ob sie bereits durch MacportsLegacySupport oder unseren Extras-Shim
# abgedeckt sind. Der Rest = neue Shim-Arbeit.
#
# Nutzung typischerweise auf dem Binary UND seinen mitgelieferten dylibs.
set -e
[ $# -ge 1 ] || { echo "usage: $0 <binary> [more...]"; exit 1; }

MLS_DYL=/opt/local/lib/libMacportsLegacySupport.dylib
EXTRA_DYL="$HOME/rust-backport/shim/libmacos109extras.dylib"
GO_DYL="$HOME/rust-backport/shim/libmacos109go.dylib"

tmp=$(mktemp -d -t backportdiag)
trap 'rm -rf "$tmp"' EXIT

# 1) alle auf 10.9 real vorhandenen exportierten System-Symbole sammeln
#    dylibs + ALLE Framework-Binaries (inkl. Sub-Frameworks) -> sonst False Positives
#    bei CF/SC/IOKit/FSEvents/CFNetwork-Symbolen. (Cache, da find teuer ist.)
CACHE="$HOME/backport-toolkit/.sys-symbols-10.9.txt"
if [ -f "$CACHE" ] && [ "${REFRESH_SYS:-0}" != 1 ]; then
  cp "$CACHE" "$tmp/sys.txt"
else
  {
    for d in /usr/lib/*.dylib /usr/lib/system/*.dylib; do
      [ -f "$d" ] && nm -gU "$d" 2>/dev/null | awk '{print $NF}'
    done
    # jedes Framework-Binary unter /System/Library/Frameworks (auch Sub-Frameworks):
    for fw in $(find /System/Library/Frameworks -name '*.framework' 2>/dev/null); do
      name=$(basename "$fw" .framework)
      bin="$fw/Versions/Current/$name"; [ -f "$bin" ] || bin="$fw/$name"
      [ -f "$bin" ] && nm -gU "$bin" 2>/dev/null | awk '{print $NF}'
    done
  } | sort -u > "$tmp/sys.txt"
  cp "$tmp/sys.txt" "$CACHE" 2>/dev/null || true
fi
# 2) Shim-Abdeckung
{ nm -gU "$MLS_DYL" 2>/dev/null; nm -gU "$EXTRA_DYL" 2>/dev/null; nm -gU "$GO_DYL" 2>/dev/null; } | awk '{print $NF}' | sort -u > "$tmp/shim.txt"
cat "$tmp/sys.txt" "$tmp/shim.txt" | sort -u > "$tmp/covered.txt"

for bin in "$@"; do
  echo "===================================================================="
  echo "  $bin"
  echo "===================================================================="
  otool -l "$bin" 2>/dev/null | awk '/LC_VERSION_MIN_MACOSX/{f=1} f&&/version/{print "  deployment-target:",$2; f=0}'
  nm -u "$bin" 2>/dev/null | sort -u > "$tmp/undef.txt"

  # fehlend = undef - (sys ∪ shim)
  comm -23 "$tmp/undef.txt" "$tmp/covered.txt" > "$tmp/missing.txt"
  # davon: durch shim geloest (undef ∩ shim, aber nicht in sys)
  comm -23 "$tmp/undef.txt" "$tmp/sys.txt" | comm -12 - "$tmp/shim.txt" > "$tmp/byshim.txt"

  nby=$(wc -l < "$tmp/byshim.txt" | tr -d ' ')
  nmiss=$(wc -l < "$tmp/missing.txt" | tr -d ' ')
  echo
  echo "  [OK] $nby fehlende 10.9-Symbole werden vom Shim (MLS+extras) geliefert."
  echo "  [!!] $nmiss Symbole FEHLEN noch (weder System noch Shim) -> neue Shim-Arbeit:"
  if [ "$nmiss" -gt 0 ]; then
    # offensichtliche libc-basics ausblenden (sammelfehler bei umbrella-libs)
    grep -vE '^_(bzero|memchr|memcmp|memcpy|memmove|memset|memset_pattern16|strchr|strcmp|strncmp|strlen|strcpy|strncpy|strcat|strstr|strrchr|strlcpy|strlcat|strnlen|strtol|strtoul|abort|malloc|free|calloc|realloc)$' "$tmp/missing.txt" | sed 's/^/       /' || true
    echo "       (offensichtliche libc-basics ausgeblendet; falls dennoch Fehler -> Umbrella-Lib-Sammelluecke)"
  fi
done
