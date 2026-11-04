# TODO — backport-toolkit

Offene Punkte (Stand 2026-11-04). Erledigtes abhaken, nicht löschen.

## Ports
- [x] **Claude-ECONNRESET dauerhaft behoben** (2026-11-04, claude-code rev 1): Port bezieht
      `libRecaulkSystem.dylib` aus dem Mavergreen/recaulk-Release (checksummed .pkg, nur die
      Bibliotheks-Komponente) statt `files/mavericks/libSystemWrapper.dylib`. Ursache: dessen
      kevent64-Stash verlor EVFILT_READ → 61/90 neue TLS-Verbindungen hingen 16 s; mit Recaulk 0.
      Messung: `~/Library/Caches/claude-netdebug/stalls.py <seit>`.
- [ ] **Recaulk aus Quelle** (devel/recaulk, build/build-lib.sh: MLS-Pin v1.5.2 f89c155,
      drydock/shipyard von Mavergreen) statt Release-Binary; danach `files/mavericks/libSystemWrapper.dylib` löschen.
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
