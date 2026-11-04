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

echo "==> Binärpakete: archive site + Signatur-Schlüssel (sonst baut MacPorts alles selbst)"
TOOLKIT="$(dirname "$TREE")"
AS=/opt/local/etc/macports/archive_sites.conf
PK=/opt/local/etc/macports/pubkeys.conf
if ! grep -q "^name[[:space:]]*mac-backport" "$AS"; then
  printf '\n# mac-backport overlay: signierte Binärarchive (GitHub-Releases, ein Release je Port)\nname                mac-backport\nurls                https://github.com/mac-backport/packages/releases/download/\n' \
    | sudo tee -a "$AS" >/dev/null
  echo "   archive site eingetragen."
else
  echo "   archive site schon vorhanden."
fi
# Root-eigene Kopie des Public Keys: MacPorts prüft damit als root, was es installiert -> der
# Schlüssel darf nicht in einem benutzer-schreibbaren Checkout liegen. Erneut ausführen, wenn
# sich keys/mac-backport-archives.pem ändert.
KEYDIR=/opt/local/etc/macports/keys
KEY="$KEYDIR/mac-backport-archives.pem"
sudo install -d -o root -g wheel -m 0755 "$KEYDIR"
sudo install -o root -g wheel -m 0644 "$TOOLKIT/keys/mac-backport-archives.pem" "$KEY"
if ! grep -qxF "$KEY" "$PK"; then
  echo "$KEY" | sudo tee -a "$PK" >/dev/null
  echo "   Schlüssel eingetragen ($KEY)."
else
  echo "   Schlüssel aktualisiert ($KEY)."
fi
# früherer Eintrag (Schlüssel direkt im Checkout) entfernen
if grep -qxF "$TOOLKIT/keys/mac-backport-archives.pem" "$PK"; then
  sudo sed -i.bak "\|^$TOOLKIT/keys/mac-backport-archives.pem\$|d" "$PK"
  echo "   alten Schlüssel-Pfad aus pubkeys.conf entfernt."
fi

echo "==> fertig. Ports einzeln installieren, immer mit -n, z.B.:"
echo "   sudo port -n install legacy-support"
echo "   sudo port -n install clang-22"
echo "   (Reihenfolge + Doktrin: README.md / DOCTRINE.md)"
