# backport-toolkit — DOKTRIN (verbindlich für alle Agents)

> Dieses Gerät bleibt **dauerhaft auf macOS 10.9.5 (x86_64, Darwin 13)**. Wir
> modernisieren die 10.9-Basis **sauber, nativ und reproduzierbar** über
> MacPorts — Schicht für Schicht bis zu aktuellem clang, rust, node, firefox …
>
> **Kernerkenntnis:** Mit genügend Zeit ist praktisch **alles from-source
> baubar.** Build-Zeit ist daher **kein** Entscheidungskriterium. Lieber ein
> mehrstündiger, sauberer Build als ein schneller Custom-Umweg.

---

## 0. Prime Directives (nie brechen)

1. **Nativ über MacPorts, nie Marke Eigenbau.** Jede Software wird über einen
   **Portfile** gebaut (`port fetch/configure/build/destroot`), nicht über ein
   eigenes Build-Skript. Kein DYLD-Wrapper, kein prebuilt-Binary-Hack, kein
   `DYLD_INSERT_LIBRARIES` als Endzustand. Ergebnis-Binaries laufen **nativ**
   auf 10.9 (statisch gelinkter Shim), ohne Laufzeit-Injektion.
2. **Keine Shortcuts.** Immer die korrekteste Lösung. Wenn eine Wand auftaucht:
   Patch ergänzen, nicht Feature deaktivieren „um durchzukommen" (außer die
   Deaktivierung ist die *korrekte* 10.9-Antwort, s. §5).
3. **Overlays = minimale, dokumentierte Deltas** über die rsync-Standard-Ports.
   Kein Fork. Jede Abweichung mit Kommentar „backport-toolkit overlay: … ;
   entfernen sobald Upstream …".
4. **Reproduzierbar & selfupdate-fest.** Alles liegt versioniert in
   `~/backport-toolkit/ports` (file://-Source **vor** rsync in
   `sources.conf`). `port selfupdate` darf nichts kaputt machen.
5. **Self-hosting, aufsteigend.** Der neueste *saubere* Compiler baut den
   nächsten; natives rust baut das nächste rust. Prebuilt-Stufen sind nur
   **einmalige Bootstrap-Krücken**, nie Endzustand.

---

## 1. „Rolle statt Version" — das zentrale Compiler-Prinzip

Früher gab es eine willkürliche Trennung (clang-16–18 „base-only", clang-19+
„App-Compiler mit MLS-cfg"). **Das ist abgeschafft.** Merke:

- **Bootstrap vs. App ist eine Eigenschaft des Builds, nicht der clang-Version.**
- **Jeder installierte clang ist „sauber"** und für **beide** Rollen nutzbar.
  Seine Base-cfg liegt im **externen, upgrade-festen** System-Config-Dir
  `/opt/local/etc/clang-backport/clang{,++}.cfg` (clang liest es als
  `CLANG_CONFIG_FILE_SYSTEM_DIR`) und enthält **nur** die legitime,
  10.9-ziel-gerechte **Base-cfg**:
  `-DTARGET_OS_OSX=1 -faligned-allocation`,
  `-L/opt/local/lib/libcxx -Wl,-rpath,/opt/local/lib/libcxx`,
  `-Wno-unused-command-line-argument`.
  → verwaltet **ausschließlich** von `bin/apply-clang-backport-cfg.sh`
  (der `bin/port`-Wrapper ist seit 2026-08-28 abgeschafft, s. §1a).
  **Niemals** Shim-/MLS-Link-Args in eine clang-cfg schreiben.
  - **`-D_LIBCPP_DISABLE_AVAILABILITY` NUR fuer clang < 19** (libc++-versions-
    abhaengig, KEINE Rollen-Sache): clang-16/17/18s aelteres libc++ braucht es,
    damit C++17 std::variant/optional auf 10.9 kompilieren. clang-19+s libc++
    (v19) hat die Gating gelockert → dort ist das Flag **unnoetig UND schaedlich**:
    es zwingt libc++, statt inline-abort-Fallbacks das 10.13+-Dylib-Symbol
    `__libcpp_verbose_abort` (u.a.) zu referenzieren, das die 10.9-Runtime nicht
    hat → **Link-Fehler bei jedem -fno-exceptions-Code (LLVM!)**. Folge: nur
    clang>=19 kann modernes LLVM auf 10.9 bauen. `apply-clang-backport-cfg.sh`
    setzt das automatisch richtig (`LIBCPP_MODERN_MAJOR=19`).
- **Der 10.9-Symbol-Shim wird per-Port** eingezogen, nativ:
  - C/C++-Ports: `PortGroup legacysupport` (dynamisch) bzw. mit
    `legacysupport.use_static yes` (statisch — für Compiler/Runtime-Builds).
  - Rust: `PortGroup rust` linkt MLS bereits **statisch** (`.a`) auf altem
    Darwin. Nichts extra nötig.

### 1a. Der `bin/port`-Wrapper — ABGESCHAFFT (2026-08-28)

**Endzustand erreicht.** Der Wrapper ist weg; die Base-cfg lebt jetzt
upgrade-fest **außerhalb des Port-Baums** in `/opt/local/etc/clang-backport/`,
und clang-22 liest sie selbst über den einkompilierten CMake-Schalter
**`-DCLANG_CONFIG_FILE_SYSTEM_DIR=/opt/local/etc/clang-backport`**
(`clang -v` → `System configuration file directory: /opt/local/etc/clang-backport`).
Damit kann keine MacPorts-Op die cfg mehr wegwischen — kein Heal-Hook nötig.

**Was gemacht wurde:**
- `llvm-22`-Portfile trägt den o.g. CMake-Schalter (dokumentiertes Delta, kein
  externer Wrapper — doktrin-konform).
- `bin/apply-clang-backport-cfg.sh` schreibt jetzt in `/opt/local/etc/clang-backport/`
  (nicht mehr in `…/llvm-NN/bin/`). Es ist nur noch der reproduzierbare Weg, den
  cfg-**Inhalt** (neu) zu erzeugen — normalerweise einmalig.
- Alle cfg-Dir-losen Alt-clangs (14/16/19/21) wurden **deinstalliert**, sobald
  clang-22 Default + Bootstrap war und nichts mehr an ihnen hing (clang-19 zuletzt,
  nachdem rust-backport auf clang-22 umgehängt war). Aktiv nur noch **clang-22**
  (+ llvm-3.7 als Linker-Basis für cctools/ld64).
- `bin/port` liegt archiviert unter `~/backport-toolkit/retired/`.

**Historischer Kontext / Faustregel (weiter gültig):** cfg-Dir-lose clangs
**nicht** nachrüsten, sondern **LÖSCHEN** (`port uninstall clang-NN llvm-NN`),
sobald der nächste saubere clang (mit cfg-Dir) Default/Bootstrap ist und nichts
mehr die Alte als `compiler.fallback` braucht — in der aufsteigenden Kette ist
ohnehin eine neuere Version da. **Jedes künftige clang aus dem `llvm-NN`-Overlay
gleich MIT `-DCLANG_CONFIG_FILE_SYSTEM_DIR=/opt/local/etc/clang-backport` bauen**
→ liest die externe cfg automatisch, kein Wrapper kommt je zurück.

**Konsequenz:** Zum Bauen eines neuen LLVM nimm den **neuesten vorhandenen
clang** als Bootstrap (`compiler.fallback clang macports-clang-<neuest>
macports-clang-16`). Alle sind sauber → keine Henne-Ei-Kontamination mehr.

### 1b. Port-Bedienung: IMMER `-n`, NIE `upgrade outdated`

Auf dieser eingefrorenen 10.9-Maschine halten wir viele Ports bewusst auf
funktionierenden (teils overlay-gepatchten) Versionen. `port upgrade <name>`
läuft **rekursiv durch den ganzen Dependency-Baum** und upgradet **jede outdated
Dependency mit** — auf 10.9 ein Regressions-/Zeit-Risiko (neue Version ohne
unsere Patches, baut evtl. nicht, stundenlang, halb-installiert bei Abbruch).

- **Einzelnen Port neu bauen:** `sudo port -n upgrade --force <name>`
  (`-n` = Dependencies NICHT anfassen). **Wichtig:** `--force` ohne `-n` erzwingt
  einen Rebuild der **GANZEN Dependency-Closure** (unabhängig von outdated!) →
  Kaskade. Immer `-n` dazu.
- **Neu installieren:** `sudo port -n install <name>` (fehlende Deps kommen,
  vorhandene werden NICHT geupgradet).
- **`port upgrade outdated` ist verboten** (blind). Auf 10.9 bauen/laufen manche
  neueren Versionen nicht oder brauchen Overlay-Patches. Modernisierung des Base
  ist als **Richtung** richtig (aktueller Base → normales `upgrade <name>`
  kaskadiert nicht), aber nur **deliberat**: outdated-Liste triagieren, sichere
  Leaf-Ports batchweise mit `-n` updaten, Problemfälle einzeln/Freeze-Liste.
  (Lehre 2026-08-28: `upgrade --force rust-backport` **ohne** `-n` startete einen
  Force-Rebuild der 131-Port-Closure — NICHT weil sie outdated war, sondern wegen
  `--force`; früh gestoppt, `rev-upgrade` sauber. Base war schon aktuell.)

---

## 2. Der 10.9-Symbol-Shim = MacportsLegacySupport (MLS), erweitert

Es gibt **einen** Shim: `MacportsLegacySupport` (Port `legacy-support`).
Der frühere Standalone-`libmacos109extras.dylib` ist **eingefaltet** und
**obsolet** (nicht mehr referenzieren).

- Overlay: `ports/devel/legacy-support` (rev +1 über rsync). Zusätzliche,
  MLS-idiomatische, **guarded** `src/*.c` (Makefile globt `src/*.c` automatisch
  in `.a` **und** `.dylib`). Aktuell ergänzt: `CCRandomGenerateBytes`,
  `aligned_alloc`, `pthread_set_qos_class_self_np`, `dispatch_set_qos_class_floor`,
  `dispatch_queue_create_with_target$V2`, `dispatch_workloop_create[_inactive]`.
- **Idiom für neue Symbole:** eigene `src/<feature>.c`, Guard
  `#define __MPLS_LIB_SUPPORT_X__ (__MPLS_TARGET_OSVER < <intro-OSVER>)`,
  Body in `#if __MPLS_LIB_SUPPORT_X__`, eigene Prototyp-Deklaration
  (MLS baut mit `-Wall`, **kein** `-Werror`). Impl über 10.9-vorhandene APIs.
- **Diagnose fehlender Symbole:** `bin/diagnose-symbols.sh <binary…>` zeigt, was
  auf 10.9 fehlt und ob MLS es deckt. Alles, was fehlt, gehört in den
  legacy-support-Overlay (nicht in einen neuen Custom-Shim!).
- Statisches Linken (`.a`) ist der robuste Default für Ergebnis-Binaries →
  läuft selbstgenügsam auf 10.9, kein DYLD-Insert.

---

## 3. Aufsteigende Toolchain-Kette (Self-Hosting)

- **clang/LLVM:** `clang-19 → llvm/clang-21 → llvm/clang-22 → …`. Neues Major =
  Standard-`lang/llvm-NN`-Port ins Overlay kopieren, den 10.9-Delta anwenden
  (§5), mit dem neuesten vorhandenen clang bauen, danach als Default setzen
  (`port select clang mp-clang-NN`) und `apply-clang-backport-cfg.sh` laufen
  lassen. Damit nehmen rust & alles Weitere automatisch den neuen Default.
  - **Reihenfolge:** zuerst `llvm-NN` (die Libs, kein known_fail), dann die
    Subports. Die clang-/lldb-/flang-Subports sind auf altem Darwin von MacPorts
    als **`known_fail yes`** markiert (nicht offiziell getestet, aber baubar) →
    mit **`port install --allow-failing clang-NN`** installieren (Flag VOR dem
    Portnamen!). Sanktioniert, kein Hack — so wurde clang-19 installiert.
- **rust:** natives `lang/rust` (Overlay) baut sich selbst und künftige
  Versionen. Stage0 für einen Bump = das **bereits installierte native**
  `/opt/local/bin/rustc` (kein prebuilt mehr). Rust braucht LLVM ≥ seiner
  Min-Version — gegen das **System-LLVM** linken (`--llvm-config
  /opt/local/libexec/llvm-NN`), nicht gebündeltes LLVM bauen.

---

## 4. sudo (Terminal-sicher!)

**Nie interaktives sudo** (zerstört das Terminal). Immer nicht-interaktiv über
stdin (Passwort steht host-lokal in `~/CLAUDE.md`, **nie** im Repo):

```sh
echo "$PW" | sudo -S -k -p '' <befehl>
```

Lange Builds im **Hintergrund** starten (`run_in_background` / `nohup … &`) und
Logs pollen (`~/backport-toolkit/distfiles/<port>-build.log`).

---

## 5. Die drei wiederkehrenden 10.9-Wände (+ korrekte Antworten)

1. **Modernes libc++ / SDK-Lücken** (C++17/20 auf 10.13+ datiert; `TARGET_OS_OSX`
   im 10.9-SDK undefiniert): → **Base-cfg** (§1).
   **`__darwin_mbstate_t`-Wand** (clang-19+ libc++ `<iosfwd>` zieht den nicht-
   selbstständigen 10.9-SDK-Header `sys/_types/_mbstate_t.h` isoliert herein):
   **toolkitweit gelöst** durch den selbstständigen Wrapper
   `include/sys/_types/_mbstate_t.h` im legacy-support-Overlay — via
   `-isystem LegacySupport` (überall per `PortGroup legacysupport`) automatisch
   aktiv, **kein per-Port-Flag** noetig, C/ASM-Pfad unberuehrt.
2. **Fehlende libSystem/Framework-Symbole** (clock_gettime, getentropy, *at,
   os_unfair_lock, CCRandomGenerateBytes, GCD/QoS …): → **MLS** via
   `PortGroup legacysupport` (§2). Fehlt eins → in den legacy-support-Overlay.
3. **compiler-rt / `os/log.h`** (erst 10.12-SDK): In LLVM 19–21 ziehen
   `GWP_ASAN`, `LIBFUZZER`, `CTX_PROFILE` (default-ON) `sanitizer_common` herein.
   → im `os.major <= 15`-Block der llvm-NN-Portfile zusätzlich
   `-DCOMPILER_RT_BUILD_GWP_ASAN=OFF -DCOMPILER_RT_BUILD_LIBFUZZER=OFF
   -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF` (builtins & profile bleiben an).

Weitere rust-spezifische 10.9-Patches (old_procs/core2, dwarf v2, offline
bootstrap, symlink) liegen als Patch-Serie beim jeweiligen Port.

---

## 6. Checkliste für einen neuen Backport

0. **PFLICHT — Recherche & Nativ-Sauberkeits-Audit VOR jedem teuren Build**
   (gilt für **jedes** Tool / jede Sprache — clang, rust, node, C/CMake, …; ein
   mehrstündiger Build, der wegen übersehener Optionen wiederholt/umgebaut werden
   muss, ist verschenkte Zeit). Bevor ein einziger stundenlanger Build startet,
   **gescheit recherchieren, was wir wirklich brauchen** — und die Antworten dem
   User **vor** dem Build vorlegen:
   - **Anforderungen vollständig?** Alle nötigen Optionen/Features/Abhängigkeiten,
     Ziel-Flags, Versionen, Varianten im Voraus ermittelt — damit **einmal**
     korrekt gebaut wird, nicht mehrfach wegen nachträglich fehlender Teile.
   - **Bietet Upstream selbst den sauberen Weg?** Konkret die **Build-Optionen
     durchsehen** (`cmake -LAH`, `./configure --help`, `CMakeLists.txt`, Meson-
     `meson_options.txt`, Cargo-Features, Upstream-Doku/Release-Notes) — gibt es
     einen Schalter/eine Option, die das nativ, upgrade-fest, idiomatisch löst,
     statt später per Wrapper/Patch/Nacharbeit? (Lehre aus clang-21:
     `CLANG_CONFIG_FILE_SYSTEM_DIR` wurde erst NACH dem Build entdeckt →
     Wrapper-Altlast statt sauberer cfg-Dir.)
   - **Nativster erreichbarer Endzustand** (§0)? Oder baue ich etwas, das ich
     später eh umbauen/aufräumen muss? Aufräum-/Migrationsaufwand ~0?
   → Diese Punkte **explizit beantworten und dem User vorlegen**, bevor der
     mehrstündige Build startet. Unsicherheit = **erst nachforschen, nicht
     losbauen**. Build-Zeit ist teuer genug, dass Vorab-Recherche sich immer lohnt.
1. Standard-Port aus dem rsync-Tree ins Overlay kopieren
   (`ports/<cat>/<name>`), **Portfile + files/**.
2. Minimalen 10.9-Delta anwenden (Kommentar „backport-toolkit overlay: …").
   Meist: `PortGroup legacysupport` (+ `use_static yes` bei Compilern),
   compiler.fallback auf neuesten clang, §5-Fixes.
3. `(cd ~/backport-toolkit/ports && portindex)`; `port file <name>` prüfen.
4. `echo "$PW" | sudo -S -k -p '' port -n -v install <name>`
   im Hintergrund; Log pollen; an jeder Wand einen **dokumentierten Patch**
   ergänzen, reindexen, weiter.
5. Verifizieren: `otool -L`/`diagnose-symbols.sh` → 0 Lücken; Binary läuft
   **nativ ohne DYLD-Insert**; Smoke-Test.
6. Fortschritt in ein `type: project`-Memory schreiben.

---

## 7. Memories (Kontext lesen)

`~/.claude/projects/-Users-imac/memory/`:
`native-toolchain-modernization-mac-10-9` (Nordstern),
`backport-toolkit-mac-10-9`, `clang-modern-toolchain-mac-10-9`,
`rust-backport-toolchain-mac-10-9`, `rust-native-macports-build-mac-10-9`,
`prefer-macports-portfiles`, `sudo-terminal-warning`, `mac-10-9-tls-setup`.
