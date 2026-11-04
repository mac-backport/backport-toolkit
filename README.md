# macOS 10.9 (Mavericks) Backport-Toolkit

Wiederverwendbare Infrastruktur, um moderne Software auf macOS 10.9.5 zu bauen und
laufen zu lassen. Entstanden beim Portieren der OpenAI Codex CLI (Rust 1.95, edition
2024) — die Bausteine sind aber allgemein.

Zielgerät bleibt bewusst auf 10.9 (stabilste Basis). Kein OS-Update.

---

## Neues 10.9-System aufsetzen (Bootstrap)

Voraussetzung: macOS 10.9.5 (x86_64), Xcode-CLT, MacPorts 2.12+ (Mavericks-pkg).

```sh
sudo port -n install git                      # aus dem Standard-Tree
git clone https://github.com/mac-backport/backport-toolkit.git ~/backport-toolkit
~/backport-toolkit/setup-local-ports.sh        # Overlay vor rsync in sources.conf + portindex
sudo port -n install legacy-support            # der eine 10.9-Shim (MLS, Overlay)
sudo port -n install clang-22                  # Compiler (llvm-22-Overlay, cfg-Dir einkompiliert)
~/backport-toolkit/bin/apply-clang-backport-cfg.sh
sudo port -n install macports-libcxx           # libc++ 22 Runtime passend zu clang-22
sudo port -n install go-1.27 rust              # weitere Toolchains, dann Apps (gh, tailscale, ...)
```

- Updates: `sudo port selfupdate` macht im Overlay selbst `git pull --rebase` +
  `portindex` (weil `ports/` in einem git-Checkout liegt). Danach gezielt
  `sudo port -n upgrade <name>` -- **nie** `port upgrade outdated` (DOCTRINE §1b).
- Eigene Distfiles (vendor-Tarballs, vorgebaute Bundles) liegen als Assets am
  Release-Tag [`distfiles`](https://github.com/mac-backport/backport-toolkit/releases/tag/distfiles);
  Upstream-Quellen kommen direkt von Upstream (Checksummen identisch).
- Verbindliche Regeln: [`DOCTRINE.md`](DOCTRINE.md).

---

## Die 3 wiederkehrenden Backport-Probleme & ihre Lösungen

### 1. C/C++ mit MacPorts-clang: moderne libc++ / SDK-Lücken
**Symptome:** `std::visit/variant/optional ... unavailable: introduced in macOS 10.13`,
`aligned allocation ... 10.13 or newer`, `bad_variant_access` beim Linken,
Linux-Codepfade werden gewählt (z. B. `TARGET_OS_OSX` fehlt).
**Lösung — globale clang-Config** (auto-geladen, EINMALIG + nach clang-Upgrades):
`bin/apply-clang-backport-cfg.sh` schreibt die Config in alle modernen
`/opt/local/etc/clang-backport/clang.cfg` (regulaer clang-22):
- `-D_LIBCPP_DISABLE_AVAILABILITY`  (Availability-Annotationen aus)
- `-DTARGET_OS_OSX=1`               (10.9-SDK definiert es nicht)
- `-faligned-allocation`            (aligned new/delete)
- `-L/opt/local/lib/libcxx -Wl,-rpath,/opt/local/lib/libcxx`  (modernes libc++ von `macports-libcxx`; System-libc++ ist zu alt)
Damit bauen die meisten modernen C++17-Ports/Libs auf 10.9.

### 2. Fehlende libSystem-Funktionen (10.10–10.14 APIs)
`clock_gettime`, `getentropy`, die `*at`-Familie, `os_unfair_lock`, `clonefile`, …
- **Selbst gebauter C/C++-Code:** gegen **MacportsLegacySupport** linken (`-lMacportsLegacySupport`;
  die MacPorts `legacysupport`-PortGroup macht das automatisch). Liefert fast alles.
- **Fremde Prebuilt-Binaries (nicht neu linkbar):** per `DYLD_INSERT_LIBRARIES` +
  `DYLD_FORCE_FLAT_NAMESPACE=1` einschleusen: MLS-dylib + unser Extras-Shim.
- **Was MLS NICHT hat** (in `~/rust-backport/shim/macos109_extras.c`):
  `CCRandomGenerateBytes` + GCD `dispatch_workloop_create[_inactive]` /
  `dispatch_queue_create_with_target$V2` / `dispatch_set_qos_class_floor`.
- Neue Lücken finden: `bin/diagnose-symbols.sh <binary>` — sagt, welche Symbole
  weder System noch Shim liefern (= neue Shim-Arbeit).

### 3. Alter Linker / alte Toolchain
Xcode-6.0-System-`ld` (2014) crasht an modernen Objektdateien.
→ **MacPorts clang-mp-22 + ld64-274** benutzen (nicht `/usr/bin/ld`). Clang
16/19 sind nur noch historische Bootstrap-Staende.

---

## Vorhandene Bausteine

- **Rust-Toolchain (10.9-tauglich):** `~/rust-backport/toolchain-1.95` (auch 1.85, 1.73).
  Aktivieren: `source ~/rust-backport/env-1.95.sh`. Prebuilt rustc/cargo laufen via
  DYLD-Shim-Wrapper (`toolchain-*/bin-wrapped/`). Output-Binaries linken MLS.a+extras.o
  statisch → laufen selbstgenügsam. Details/Config: `~/.cargo/config.toml`.
- **Symbol-Shim:** `~/rust-backport/shim/` (macos109_extras.{c,o,dylib}; alter Voll-Shim
  macos109_shim.c als Referenz).
- **Chunked Downloader:** `~/rust-backport/chunkdl.sh URL OUT` — große Downloads werden
  hier per SIGKILL abgeschossen; lädt in 30-MB-HTTP-Range-Häppchen.
- **Codex-Update:** massgeblich ist der lokale MacPorts-Port
  `ports/devel/codex`. `~/rust-backport/update-codex.sh` ist nur noch ein
  historischer Referenzweg und darf nicht fuer regulaere Updates verwendet werden.

## Toolkit-Skripte (dieses Verzeichnis)
- `bin/diagnose-symbols.sh <binary...>` — fehlende 10.9-Symbole + Shim-Abdeckung.
- `bin/apply-clang-backport-cfg.sh` — globale clang-Backport-Config (neu) setzen.
- `bin/update-system-trust.sh` — System-Roots/CA-Bundle aktualisieren.
- `setup-local-ports.sh` — Overlay bei MacPorts registrieren (Bootstrap).
- (`bin/port`-Wrapper ist abgeschafft -> `retired/`; clang-22 liest die cfg selbst.)

## Codex kontrolliert aktualisieren

1. Sicherstellen, dass kein anderer MacPorts-/Cargo-Build laeuft, und freien Platz
   pruefen.
2. Im `Portfile` Release-Tag/Version und gemeinsam damit alle Checksummen anpassen;
   den Mavericks-Patch gegen den neuen Quellstand pruefen. Der `post-patch`-Schritt
   muss dabei den Mavericks-Seatbelt-Parser-Preflight erfolgreich abschliessen.
3. Vor dem langen Build kontrollieren, dass `configure.ccache no` aktiv ist und
   `/opt/local/bin/cargo` auf den aktuellen `rust-backport`-Wrapper zeigt. Dieser
   setzt clang-22, die Shims und den letzten Linkerparameter explizit auf 10.9.
4. Im Wurzelverzeichnis `ports/` `/opt/local/bin/portindex` ausfuehren.
5. Nur den betroffenen Port mit `sudo port -n` bauen/installieren; kein pauschales
   `upgrade outdated`.
6. Der `post-destroot`-Audit muss fuer `codex`, `codex-code-mode-host` und den
   Browser-Shim `LC_VERSION_MIN_MACOSX 10.9` bestaetigen. Danach Symbolaudit,
   Version, Start, TLS, Login/Browser-Shim, Code-Mode-Host sowie echte
   `read-only`-/`workspace-write`-/`apply_patch`-Sandboxtests ausfuehren.

Codex-Seatbelt verwendet auf neueren macOS-Versionen Filter und Operationen, die
Mavericks nicht kennt (`process-info*` mit `target`, `path`, `sysctl-name*`,
`iokit-registry-entry-class`, `ipc-posix-name-prefix`, `file-test-existence`,
`file-map-executable` sowie APFS-/Container-Regeln). Der Port transformiert diese
vor dem Build konservativ und prueft alle statischen Policy-Fragmente sowie
repraesentative dynamische Netzwerk-/Pfadregeln direkt mit `/usr/bin/sandbox-exec`.
Dieser Preflight ist bei jeder Codex-Version neu ernst zu nehmen; nicht nur den
jeweils ersten Parserfehler wegpatchen.

clang-16 und clang-19 waren Bootstrap-Toolchains frueher Codex-/Rust-
Portrevisionen. Fuer neue Builds ist ausschliesslich clang-22 mit der globalen
Backport-Config vorgesehen; erst nach erfolgreichem C-/C++17-/10.9-Linktest
lange Builds starten.

Der lokale Port installiert die echten Programme nach `/opt/local/libexec/codex`
und den Wrapper nach `/opt/local/bin/codex`. Eine vorhandene historische
Installation unter `~/bin` ist nicht die Source of Truth.

## Wichtige Fakten
- MacPorts sudo-Installs: Klassifikator blockiert sudo sporadisch → einzeln/erneut.
- `TARGET_OS_OSX` fehlt im 10.9-SDK (`TARGET_OS_MAC=1` ist gesetzt) — Ursache vieler
  Fehldetektionen in Cross-Platform-C-Code.
- Moderne prebuilt Rust/Go/C++-Binaries scheitern auf 10.9 fast immer nur an einer
  Handvoll Symbolen → `diagnose-symbols.sh` + DYLD-Insert-Shim ist der Standardweg.
- MacPorts protobuf: `protobuf3-cpp` braucht KEIN abseil; `protobuf5-cpp` schon.
