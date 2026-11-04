#!/usr/bin/env python3
# gfx/layers/ipc/CompositorBridgeParent.{h,cpp} — RecvPCompositorWidgetConstructor
# is declared/implemented with move semantics (&&) under #ifdef XP_MACOSX, but our
# GTK build's IPDL generates the base with const& (non-cocoa), so the override
# signature mismatches ("non-virtual member function marked override"). Narrow the
# gate to the Cocoa toolkit: on GTK we simply don't override (the comment says
# "Other platforms don't need to override"). XP_MACOSX-vs-MOZ_WIDGET_COCOA pattern.
# Not in the delta.
import io, sys
W = sys.argv[1]
def patch(path, old, new):
    s = io.open(path, encoding="utf-8").read()
    if s.count(old) != 1:
        raise SystemExit("%s: expected 1, found %d" % (path, s.count(old)))
    io.open(path, "w", encoding="utf-8").write(s.replace(old, new))
    print("patched", path.split('/firefox-153.1.0/')[-1])

patch(W + "/gfx/layers/ipc/CompositorBridgeParent.h",
      "#ifdef XP_MACOSX\n  // macOS platform-specific initdata uses move semantics, which",
      "#if defined(XP_MACOSX) && defined(MOZ_WIDGET_COCOA)\n  // macOS platform-specific initdata uses move semantics, which")
patch(W + "/gfx/layers/ipc/CompositorBridgeParent.cpp",
      "#ifdef XP_MACOSX\nmozilla::ipc::IPCResult\nCompositorBridgeParent::RecvPCompositorWidgetConstructor(",
      "#if defined(XP_MACOSX) && defined(MOZ_WIDGET_COCOA)\nmozilla::ipc::IPCResult\nCompositorBridgeParent::RecvPCompositorWidgetConstructor(")
