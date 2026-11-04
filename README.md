# mac-backport / backport-toolkit

**Modern toolchains and apps, built natively from source on OS X 10.9 Mavericks — as a MacPorts overlay.**

Old Intel Macs are still great machines. Apple stopped updating them, and most modern
software stopped building for them. This repository is a [MacPorts](https://www.macports.org)
ports overlay plus the know-how to bring them forward again: a current compiler, current
language runtimes and current apps — built from source on the Mac itself, running
**natively** on 10.9.5 (no `DYLD_INSERT_LIBRARIES` tricks in the end result).

| Area | Ports in this overlay |
|---|---|
| Compiler | `llvm-22` / `clang-22` (+ `llvm-19`, `llvm-21` history), `macports-libcxx` (libc++ 22 runtime) |
| 10.9 shim | `legacy-support` (MacportsLegacySupport with extra 10.10–10.15 APIs) |
| Languages | `rust` 1.95 + `cargo` (self-hosting), `rust-backport`, `go-1.27`, `nodejs26` |
| Tools | `gh`, `ripgrep`, `util-linux`, `codex`, `claude-code` (10.9 override) |
| Apps | `mpv` / libmpv 0.41, `tailscale`, `firefox-x11` (ESR, GTK3/X11, WIP), `kodi`, `zathura`, `rustdesk-mavericks` |

## Main use case: Sofa

My main reason for all of this is **[Sofa](https://github.com/robertkleinschuster/sofa)** —
a native smart-TV app that turns an old iMac into a web TV, operated with the little
Apple Remote. Sofa needs a modern toolchain (clang-22), a current libcurl/OpenSSL for
TLS 1.3, `mpv`/libmpv for VP9/AV1 and Python/yt-dlp — all coming from this overlay.

## Bootstrap a fresh 10.9 Mac

Requirements: OS X 10.9.5 (x86_64), Command Line Tools, MacPorts 2.12+ (Mavericks pkg).

```sh
sudo port -n install git
git clone https://github.com/mac-backport/backport-toolkit.git ~/backport-toolkit
~/backport-toolkit/setup-local-ports.sh          # adds ports/ to sources.conf (before rsync) + portindex
sudo port -n install legacy-support              # the one 10.9 shim
sudo port -n install clang-22                    # modern compiler
~/backport-toolkit/bin/apply-clang-backport-cfg.sh
sudo port -n install macports-libcxx             # libc++ runtime matching clang-22
sudo port -n install go-1.27 rust                # then whatever you need: gh, mpv, nodejs26, ...
```

- **Updates:** `ports/` lives in a git checkout, so `sudo port selfupdate` runs
  `git pull --rebase` + `portindex` on its own. Upgrade single ports with
  `sudo port -n upgrade <name>` — avoid `port upgrade outdated` (dependency cascades).
- **Distfiles:** upstream sources are fetched from upstream (checksums identical);
  generated ones (Go vendor tarballs, prebuilt bundles) are assets of the
  [`distfiles` release](https://github.com/mac-backport/backport-toolkit/releases/tag/distfiles).
- **Rules of the game:** [`DOCTRINE.md`](DOCTRINE.md) — native via Portfiles, minimal
  documented patches over upstream, one shim (legacy-support), clean compilers.
  Detailed notes (German): [`docs/toolkit-notes.de.md`](docs/toolkit-notes.de.md).

## Helpers

- `bin/diagnose-symbols.sh <binary>` — which symbols a binary needs that 10.9 (or the shim) lacks.
- `bin/apply-clang-backport-cfg.sh` — the 10.9 clang config (availability off, `TARGET_OS_OSX`, aligned new, libc++ path).
- `bin/update-system-trust.sh` — refresh system root certificates.

## Inspiration & thanks

- **[Mavericks Forever](https://mavericksforever.com)** — the community keeping 10.9 alive;
  their libSystem wrapper and tooling showed what is possible and still power parts of
  the `claude-code` port.
- **[Mavergreen](https://github.com/Mavergreen)** ([recaulk](https://github.com/Mavergreen/recaulk)) —
  the successor project around modern binaries on Mavericks.
- The [MacPorts](https://www.macports.org) project and the
  [legacy-support](https://github.com/macports/macports-legacy-support) maintainers.

Each port keeps its upstream license; the patches here follow the license of the patched project.
