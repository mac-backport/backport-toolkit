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
      Recherchiert 2026-11-04, **zurückgestellt**: braucht Mavergreens shipyard (SDK-Fetch) + drydock,
      Recaulk selbst baut mit seinem Release-Binary; das Release-pkg ist gegen Upstream-SHA256SUMS geprüft.
- [x] **`net/bgutil-pot-server`** 2.0.2 (2026-11-04): offline gebaut (vendor node_modules am Release
      `distfiles`, Node-Header-Distfile für node-gyp, canvas nativ), LaunchDaemon als `nobody` nur auf
      127.0.0.1:4416 (Handaufbau 1.3.1 lauschte auf allen Interfaces → nach
      /Library/LaunchDaemons/disabled-handbuilt/). Update: neue Version → vendor-Tarball neu
      (`npm ci --ignore-scripts`), hochladen, Checksummen. Sofa zieht das yt-dlp-Plugin selbst nach.
- [x] **`multimedia/sofa`** 0.1.0 (2026-11-04): GitHub-Tag, clang-22, depends curl sqlite3 mpv(+libmpv)
      ffmpeg quickjs librsvg python314, run: bgutil-pot-server; Sofa.app nach ${applications_dir};
      LaunchAgents de.sofa.remote/de.sofa.app per startupitems (custom_file). destroot verifiziert.
      Offen: diese Maschine darauf umstellen (siehe Sofa NOTES), Lizenz für Sofa festlegen.

## Infrastruktur
- [x] **Binärarchive** (2026-11-04): 16 Ports in `mac-backport/packages` (ein Release je Port,
      `bin/publish-archives.sh`), `setup-local-ports.sh` trägt Site + Key ein; Signatur + Site-Auswahl
      durch MacPorts geprüft. Bei jedem Port-Update erneut publizieren. Signierte MacPorts-Archive (`archive_sites` + Public Key in
      `pubkeys.conf`) für clang-22, rust, go-1.27, nodejs26, mpv … auf GitHub-Releases →
      neuer Mac lädt statt stundenlang zu bauen.
- [x] **Sofa-Installer**: statt mdmg (hätte ~160 Ports neu gebaut und kollidiert mit /opt/local)
      eigenständige DMG aus dem Sofa-Repo (`tools/make-release`): Runtime + Dylibs im Bundle, kein
      MacPorts beim Nutzer. MacPorts nur noch Werkbank für den Release-Build.
- [x] **CI** (GitHub Actions): Scan auf private Daten, ASCII-Descriptions, kein file:// (läuft);
      offen: `port lint` der geänderten Portfiles + Scan auf private Daten
      (Pfade, Tokens, Tailnet).
- [ ] **Upstream**: generische 10.9-Fixes an MacPorts anbieten (legacy-support-Ergänzungen,
      gh-Quellbuild für <10.13, go) → Overlay schrumpft auf das wirklich 10.9-Spezifische.
      Kandidaten + Vorgehen (MacPorts-KI-Regeln: Mensch reicht ein, `Assisted-by: LLM`):
      `docs/upstream-proposals.md`. aligned_alloc/mkostemp/CCRandomGenerateBytes sind schon in MLS master.
      MLS-Patchserie (QoS, _mbstate_t, dispatch) lokal fertig + getestet, wartet auf Review/Einreichung
      durch Robert (Branch `mavericks-qos-dispatch`, format-patch + PR.md).
- [ ] `retired/` und `ports/www/firefox-x11/files/_COMPLETE-worktree-delta-*.diff` aufräumen
      (Historie, nicht mehr benötigt?).
