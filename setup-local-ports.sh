#!/bin/bash
# setup-local-ports.sh - registriert den Backport-Ports-Tree dieses Repos bei
# MacPorts (file://-Quelle VOR der rsync-Standardquelle) und baut den PortIndex.
# Weil ports/ in einem git-Checkout liegt, macht `port sync`/`selfupdate`
# danach selbst `git pull --rebase` (als Eigentuemer des Checkouts) + portindex.
# Braucht sudo (sources.conf).
set -e
TREE="$(cd "$(dirname "$0")/ports" && pwd)"
SRC=/opt/local/etc/macports/sources.conf

echo "==> PortIndex bauen in $TREE"
(cd "$TREE" && /opt/local/bin/portindex)

echo "==> Overlay in sources.conf eintragen (vor der rsync-Zeile)"
if ! grep -q "^file://$TREE" "$SRC"; then
  sudo sed -i.bak "1i\\
file://$TREE
" "$SRC"
  echo "   eingetragen."
else
  echo "   schon vorhanden."
fi

echo "==> fertig. Ports einzeln installieren, immer mit -n, z.B.:"
echo "   sudo port -n install legacy-support"
echo "   sudo port -n install clang-22"
echo "   (Reihenfolge + Doktrin: README.md / DOCTRINE.md)"
