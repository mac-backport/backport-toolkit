#!/bin/bash
# publish-archives.sh <port>...  --  sign the ACTIVE MacPorts archive of each overlay port
# and publish it as GitHub release <port> in mac-backport/packages, so other 10.9 Macs
# install it as a binary instead of compiling (see README: "Binary packages").
#
# Signing key (private, never in the repo): ~/.config/mac-backport/archive-signing-key.pem
# Public key (in the repo, goes into pubkeys.conf): keys/mac-backport-archives.pem
# Archive URL MacPorts builds: <archive_sites url>/<port>/<archive>  ->  release tag = port name.
# Only ports whose license allows redistribution (never claude-code: Restrictive/NoMirror).
set -u
unset DYLD_INSERT_LIBRARIES
TOOLKIT="$(cd "$(dirname "$0")/.." && pwd)"
REPO=mac-backport/packages
KEY="$HOME/.config/mac-backport/archive-signing-key.pem"
PUB="$TOOLKIT/keys/mac-backport-archives.pem"
SIGS="${TMPDIR:-/tmp}/mac-backport-sigs"
mkdir -p "$SIGS"
[ -f "$KEY" ] || { echo "signing key missing: $KEY"; exit 1; }

for p in "$@"; do
  case "$p" in claude-code) echo "skip $p (license forbids redistribution)"; continue ;; esac
  v=$(port -q installed "$p" and active | awk '{print $2}' | sed 's/^@//' | head -1)
  [ -n "$v" ] || { echo "not installed/active: $p"; continue; }
  a="$p-${v%%+*}$(echo "$v" | grep -o '+.*').darwin_13.x86_64.tbz2"
  f="/opt/local/var/macports/software/$p/$a"
  [ -f "$f" ] || { echo "archive missing: $f"; continue; }
  /opt/local/bin/openssl dgst -ripemd160 -sign "$KEY" -out "$SIGS/$a.rmd160" "$f"
  /opt/local/bin/openssl dgst -ripemd160 -verify "$PUB" -signature "$SIGS/$a.rmd160" "$f" >/dev/null \
    || { echo "signature check failed: $a"; continue; }
  if gh release view "$p" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$p" --repo "$REPO" --clobber "$f" "$SIGS/$a.rmd160"
  else
    gh release create "$p" --repo "$REPO" --title "$p" \
      --notes "MacPorts binary archive(s) of \`$p\` for OS X 10.9 (darwin_13, x86_64), signed with keys/mac-backport-archives.pem of mac-backport/backport-toolkit. MacPorts uses them automatically via archive_sites.conf." \
      "$f" "$SIGS/$a.rmd160"
  fi && echo "OK $a"
done
