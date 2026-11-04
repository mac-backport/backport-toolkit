#!/bin/bash
# update-system-trust.sh — bringt den System-Trust-Store von OS X 10.9 auf den
# aktuellen Mozilla-CA-Satz (Quelle: MacPorts curl-ca-bundle).
#
# Fuegt jeden Root aus dem Bundle als vertrauenswuerdigen Root in
# /Library/Keychains/System.keychain ein (idempotent — add-trusted-cert
# aktualisiert bestehende Eintraege, erzeugt keine Duplikate).
# Der Built-in /System/Library/Keychains/SystemRootCertificates.keychain bleibt
# unangetastet; das Anchor-Set ist die Vereinigung beider Keychains.
#
# Muss als root laufen:  sudo bash update-system-trust.sh
# Verifikation danach:    siehe Ende der Ausgabe.
# Reversibel:             Keychain Access -> System -> Certificate loeschen, bzw.
#                         security delete-certificate -c "<CN>" /Library/Keychains/System.keychain
set -u

BUNDLE="${1:-/opt/local/share/curl/curl-ca-bundle.crt}"
KC=/Library/Keychains/System.keychain
OPENSSL=/opt/local/bin/openssl
[ -x "$OPENSSL" ] || OPENSSL=openssl

if [ "$(id -u)" != "0" ]; then echo "FEHLER: bitte als root ausfuehren (sudo)."; exit 1; fi
[ -f "$BUNDLE" ] || { echo "FEHLER: CA-Bundle nicht gefunden: $BUNDLE"; exit 1; }

TMP=$(mktemp -d /tmp/systrust.XXXXXX) || exit 1
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1

# Bundle in Einzel-Certs splitten (fn nur zwischen BEGIN/END -> keine Open-File-Flut)
awk '/-----BEGIN CERTIFICATE-----/{n++; fn=sprintf("c%04d.pem", n)}
     fn!=""{print > fn}
     /-----END CERTIFICATE-----/{close(fn); fn=""}' "$BUNDLE"

total=$(ls c*.pem 2>/dev/null | wc -l | tr -d ' ')
echo "Roots im Bundle: $total"
ok=0; fail=0
for f in c*.pem; do
  if security add-trusted-cert -d -r trustRoot -k "$KC" "$f" >/dev/null 2>&1; then
    ok=$((ok+1))
  else
    fail=$((fail+1))
    echo "FAIL: $("$OPENSSL" x509 -in "$f" -noout -subject 2>/dev/null | sed 's/subject=//')"
  fi
done
echo "=== Fertig: $ok/$total hinzugefuegt/aktualisiert, $fail fehlgeschlagen ==="
echo -n "Verifikation ISRG Root X1: "
security find-certificate -c "ISRG Root X1" "$KC" >/dev/null 2>&1 && echo "vorhanden" || echo "FEHLT"
