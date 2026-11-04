# Upstream proposals

Generic 10.9 fixes from this overlay that could go to MacPorts, so the overlay
shrinks to what is really 10.9/backport-specific. Status 2026-11-04.

## macports-legacy-support (github.com/macports/macports-legacy-support)

Already upstream on `master` (after v1.5.2), drop from our overlay with the next release:
`aligned_alloc`, `mkostemp`, `CCRandomGenerateBytes`.

Not upstream yet, candidates for a PR (sources in `ports/devel/legacy-support/files/`):

| Shim | What | Needed by |
|---|---|---|
| `qos.h` + `pthread_qos.c` | `<sys/qos.h>` (`qos_class_t`, `QOS_CLASS_*`) and no-op `pthread_set_qos_class_self_np` / `pthread_attr_set_qos_class_np` / `qos_class_self` for < 10.10 | LLVM 19+, Rust std, Node/V8 |
| `dispatch_compat.c` | `dispatch_workloop_create[_inactive]`, `dispatch_queue_create_with_target$V2`, `dispatch_set_qos_class_floor` mapped to plain serial queues | Rust/Tokio-based prebuilt tools, Codex |
| `_mbstate_t.h` | `mbstate_t` include guard for headers that expect the newer SDK layout | LLVM 21/22 libc++ |

Before a PR: tests in MLS style (`test/`), behaviour on 10.4–10.9 builders, and the
gating macros MLS uses (`__MPLS_SDK_SUPPORT_*`, `__MPLS_LIB_SUPPORT_*`).

## Ports

- `gh`: the official port repackages the 10.10+ binary below macOS 13. A source build
  needs a Go that runs on 10.9; that only exists here (`go-1.27` backport), so this is not
  upstreamable on its own.
- `go-1.27`, `nodejs26`, `llvm-22` patches: large, version-specific backports; upstream
  only makes sense together with a MacPorts policy for these old systems.

## How to submit (MacPorts and AI)

MacPorts has no final policy yet; the draft [macports-base#420](https://github.com/macports/macports-base/pull/420)
(open, 2026-11) asks for an `Assisted-by:` trailer (kernel style, now `Assisted-by: LLM`), no
`Co-authored-by` for tools, and "do not use agents ... to open pull requests or tickets without
human supervision". Maintainers already flag "AI driven submissions" in macports-ports. So:
a human reviews and submits, answers review comments personally, small focused patches with
tests, one at a time; commits there use `Assisted-by: LLM`, not our usual Co-Authored-By line.
