#!/usr/bin/env python3
# Session-2026-08-31 source fixes for firefox-x11, applied in post-patch AFTER
# _COMPLETE-worktree-delta-20260830.diff. These are NOT in that delta (they were
# made the next day). Idempotent-ish: each replacement asserts exactly one match.
#
#   1) dom/ipc/ContentProcess.cpp  — content-process GRE-dir uses the macOS
#      .app-bundle walk gated on XP_MACOSX (platform, true for us) instead of the
#      Cocoa toolkit. Narrow to XP_MACOSX && MOZ_WIDGET_COCOA so the GTK build
#      takes the generic depth=1/no-"Resources" path (GRE dir = dist/bin). Without
#      this every resource://gre and moz-src:// load fails in child processes.
#   2) ipc/glue/SharedMemoryHandle.h + ipc/glue/moz.build — GTK-on-Darwin runs the
#      POSIX IPC personality; shared memory must be fd-based (shm_open), not mach
#      ports (mach handles can't cross the POSIX fd channel) -> tab/content crash.
import io, sys

W = sys.argv[1]  # worksrcpath

def patch(path, edits):
    s = io.open(path, encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            raise SystemExit("%s: match=%d for %r" % (path, n, old[:60]))
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8").write(s)
    print("patched", path)

# 1) ContentProcess.cpp GRE-dir gate
patch(W + "/dom/ipc/ContentProcess.cpp", [
    (
        "#if defined(XP_MACOSX)\n"
        "  // Walk out of [subprocess].app/Contents/MacOS to the real GRE dir\n"
        "  const int depth = 4;\n"
        "#elif defined(XP_IOS)",
        "#if defined(XP_MACOSX) && defined(MOZ_WIDGET_COCOA)\n"
        "  // Walk out of [subprocess].app/Contents/MacOS to the real GRE dir\n"
        "  const int depth = 4;\n"
        "#elif defined(XP_IOS)",
    ),
    (
        "#if defined(XP_MACOSX)\n"
        '  rv = current->SetNativeLeafName("Resources"_ns);\n'
        "  NS_ENSURE_SUCCESS(rv, rv);\n"
        "#elif defined(XP_IOS)",
        "#if defined(XP_MACOSX) && defined(MOZ_WIDGET_COCOA)\n"
        '  rv = current->SetNativeLeafName("Resources"_ns);\n'
        "  NS_ENSURE_SUCCESS(rv, rv);\n"
        "#elif defined(XP_IOS)",
    ),
])

# 2a) SharedMemoryHandle.h: fd-based PlatformHandle + frozen-file member on GTK-Darwin
patch(W + "/ipc/glue/SharedMemoryHandle.h", [
    (
        "#if defined(XP_DARWIN)\nusing PlatformHandle = mozilla::UniqueMachSendRight;\n#else\nusing PlatformHandle = mozilla::UniqueFileHandle;\n#endif",
        "#if defined(XP_DARWIN) && !defined(MOZ_WIDGET_GTK)\nusing PlatformHandle = mozilla::UniqueMachSendRight;\n#else\n// GTK-on-Darwin uses fd-based POSIX shared memory (see ipc/glue/moz.build).\nusing PlatformHandle = mozilla::UniqueFileHandle;\n#endif",
    ),
    (
        "#if !defined(XP_DARWIN) && !defined(XP_WIN) && !defined(ANDROID)\n private:\n  PlatformHandle mFrozenFile;\n#endif",
        "#if (!defined(XP_DARWIN) || defined(MOZ_WIDGET_GTK)) && !defined(XP_WIN) && \\\n    !defined(ANDROID)\n private:\n  PlatformHandle mFrozenFile;\n#endif",
    ),
])

# 2b) moz.build: compile the POSIX shared-memory backend for GTK-on-Darwin
patch(W + "/ipc/glue/moz.build", [
    (
        'if CONFIG["OS_ARCH"] == "Darwin":\n    UNIFIED_SOURCES += ["SharedMemoryPlatform_mach.cpp"]',
        'if CONFIG["OS_ARCH"] == "Darwin" and CONFIG["MOZ_WIDGET_TOOLKIT"] != "gtk":\n    UNIFIED_SOURCES += ["SharedMemoryPlatform_mach.cpp"]',
    ),
])
print("session-0831 patches applied")
