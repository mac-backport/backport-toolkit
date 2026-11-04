#!/bin/bash
# apply-clang-backport-cfg.sh — schreibt die macOS-10.9-Backport-Base-Config in
# das EXTERNE, upgrade-feste System-Config-Dir /opt/local/etc/clang-backport.
#
# HINTERGRUND (2026-08-28, Wrapper-Abschied):
#   clang-22 (und jedes kuenftige clang, das wir aus dem llvm-NN-Overlay mit
#   -DCLANG_CONFIG_FILE_SYSTEM_DIR=/opt/local/etc/clang-backport bauen) liest
#   seine Config selbststaendig aus DIESEM Verzeichnis:
#       $ clang -v -c x.c ...
#       System configuration file directory: /opt/local/etc/clang-backport
#   Das Verzeichnis liegt AUSSERHALB jedes Ports -> ein `port upgrade clang-NN`
#   kann es nicht mehr ueberschreiben. Damit entfaellt das frueher noetige
#   Nachheilen der cfg im Port-bin-dir (/opt/local/libexec/llvm-NN/bin) und der
#   ~/backport-toolkit/bin/port-Wrapper ist ersatzlos weg.
#
#   Dieses Skript ist daher nur noch der dokumentierte, reproduzierbare Weg, um
#   den cfg-INHALT (neu) zu erzeugen — normalerweise EINMALIG noetig. Nach dem
#   Editieren des Inhalts hier erneut ausfuehren.
#
# Aufruf:  sudo apply-clang-backport-cfg.sh
#
# DESIGN (Rolle statt Version): Die cfg enthaelt NUR die legitime, 10.9-gerechte
#   Base-Config (TARGET_OS_OSX / libc++ / aligned-alloc). Sie macht KEINEN
#   Unterschied zwischen Bootstrap- und App-Compiler; jeder clang ist damit
#   sauber und fuer beide Rollen nutzbar. Der 10.9-Symbol-Shim wird NICHT global
#   per cfg gelinkt, sondern nativ pro Port ueber `PortGroup legacysupport`
#   (bzw. `PortGroup rust` = statisches MLS). Kein _LIBCPP_DISABLE_AVAILABILITY:
#   das war nur fuer libc++<19 noetig und ist bei modernem libc++ schaedlich
#   (erzwingt 10.13+-Dylib-Symbole). Alle aktiven clangs sind >=19 -> weglassen.
set -e

CFGDIR=/opt/local/etc/clang-backport

read -r -d '' CXXCFG <<'CFG' || true
# macOS 10.9 Backport-Defaults (clang++). Auto-geladen von clang (SystemConfigDir).
# 10.9-SDK definiert TARGET_OS_OSX nicht -> C/C++-Libs erkennen macOS sonst nicht:
-DTARGET_OS_OSX=1
# aligned new/delete (C++17) ist 10.13-gated -> erzwingen (modernes libc++ liefert die symbole):
-faligned-allocation
# modernes MacPorts-libc++ (macports-libcxx) zum Linken + zur Laufzeit bevorzugen:
-L/opt/local/lib/libcxx
-Wl,-rpath,/opt/local/lib/libcxx
# -L in Compile-only-Aufrufen nicht als Fehler werten:
-Wno-unused-command-line-argument
CFG

read -r -d '' CCFG <<'CFG' || true
# macOS 10.9 Backport-Defaults (clang, C). Auto-geladen von clang (SystemConfigDir).
-DTARGET_OS_OSX=1
-L/opt/local/lib/libcxx
-Wl,-rpath,/opt/local/lib/libcxx
-Wno-unused-command-line-argument
CFG

sudo mkdir -p "$CFGDIR"
echo "$CXXCFG" | sudo tee "$CFGDIR/clang++.cfg" >/dev/null
echo "$CCFG"   | sudo tee "$CFGDIR/clang.cfg"   >/dev/null
echo "installiert (base-only, beide Rollen): $CFGDIR/clang++.cfg + clang.cfg"

# Smoke-Test mit dem Default-clang++ (muss das externe Dir selbst finden):
cxx=/opt/local/bin/clang++
if [ -x "$cxx" ]; then
    echo "--- $cxx liest cfg aus: ---"
    "$cxx" -v -c /dev/null -x c++ -o /dev/null 2>&1 | grep -iE 'configuration file' || true
    printf '#include <variant>\nint main(){std::variant<int,double>v=1;return 0;}\n' > /tmp/_cfgtest.cc
    if "$cxx" -std=c++17 -mmacosx-version-min=10.9 /tmp/_cfgtest.cc -o /tmp/_cfgtest 2>/tmp/_cfgtest.log; then
        echo "  OK: C++17 baut+linkt gegen modernes libc++ ($cxx)"
    else
        echo "  FEHLER ($cxx) — siehe /tmp/_cfgtest.log"
    fi
fi
