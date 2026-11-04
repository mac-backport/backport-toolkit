# TODO — backport-toolkit

Offene Punkte (Stand 2026-11-04). Erledigtes abhaken, nicht löschen.

## Ports
- [ ] **`recaulk`-Port** (devel/recaulk) aus Quelle (github.com/Mavergreen/recaulk, build/build-lib.sh:
      MLS-Pin v1.5.2 f89c155, drydock/shipyard) und `llm/claude-code` darauf umstellen statt
      `files/mavericks/libSystemWrapper.dylib`. Grund: die kevent64-Stash-Logik des alten
      libSystemWrapper verliert EVFILT_READ-Events → Claude „Connection dropped (ECONNRESET)“.
      Mit dem Recaulk-Prebuilt seit 2026-11-04 07:20: 0 Hänger (vorher 61/90 neue Verbindungen).
      Messung: `~/Library/Caches/claude-netdebug/stalls.py <seit>`. Achtung: bis dahin
      überschreibt `port -n upgrade/activate claude-code` das interimistisch getauschte libS.dylib.
- [ ] **`net/bgutil-pot-server`** (für Sofa, siehe Sofa NOTES.md): node_modules-Vendor-Tarball
      ans Release `distfiles`.
- [ ] **`multimedia/sofa`** (Hauptanwendungsfall, github.com/robertkleinschuster/sofa).

## Infrastruktur
- [ ] **Binärarchive**: signierte MacPorts-Archive (`archive_sites` + Public Key in
      `pubkeys.conf`) für clang-22, rust, go-1.27, nodejs26, mpv … auf GitHub-Releases →
      neuer Mac lädt statt stundenlang zu bauen.
- [ ] **CI** (GitHub Actions): `port lint` der geänderten Portfiles + Scan auf private Daten
      (Pfade, Tokens, Tailnet).
- [ ] **Upstream**: generische 10.9-Fixes an MacPorts anbieten (legacy-support-Ergänzungen,
      gh-Quellbuild für <10.13, go) → Overlay schrumpft auf das wirklich 10.9-Spezifische.
- [ ] `retired/` und `ports/www/firefox-x11/files/_COMPLETE-worktree-delta-*.diff` aufräumen
      (Historie, nicht mehr benötigt?).
