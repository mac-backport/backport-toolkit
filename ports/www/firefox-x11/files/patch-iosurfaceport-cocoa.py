#!/usr/bin/env python3
# gfx/layers/moz.build — IOSurfacePort.{h,cpp} and PNativeLayerRemote.ipdl sit in
# UNCONDITIONAL blocks, but they're only used by the (already cocoa-gated) macOS
# NativeLayerRemote compositor. IOSurfacePort.cpp pulls <IOSurface/IOSurfaceRef.h>
# (absent on 10.9) and we don't do IOSurface/CoreAnimation compositing on GTK/X11.
# Move all three into cocoa("cocoa","uikit") blocks. Nothing else manages
# PNativeLayerRemote (verified). Not in the delta.
import io, sys
M = sys.argv[1] + "/gfx/layers/moz.build"
s = io.open(M, encoding="utf-8").read()

def rm(line):
    global s
    if s.count(line) != 1:
        raise SystemExit("expected 1 of %r, found %d" % (line, s.count(line)))
    s = s.replace(line, "")

# 1) remove the 3 unconditional entries
rm('    "ipc/IOSurfacePort.h",\n')
rm('    "ipc/IOSurfacePort.cpp",\n')
rm('    "ipc/PNativeLayerRemote.ipdl",\n')

# 2) add IOSurfacePort.h to the cocoa EXPORTS.mozilla.layers block
a = '    EXPORTS.mozilla.layers += [\n        "GpuFenceMTLSharedEvent.h",\n'
s = s.replace(a, a + '        "ipc/IOSurfacePort.h",\n', 1)

# 3) add IOSurfacePort.cpp to the cocoa SOURCES block
b = '    SOURCES += [\n        "GpuFenceMTLSharedEvent.cpp",\n'
if s.count(b) != 1:
    raise SystemExit("cocoa SOURCES anchor count=%d" % s.count(b))
s = s.replace(b, b + '        "ipc/IOSurfacePort.cpp",\n', 1)

# 4) add PNativeLayerRemote.ipdl into a cocoa IPDL_SOURCES (extend the MacIOSurface OGL block)
c = ('    SOURCES += [\n        "opengl/MacIOSurfaceTextureClientOGL.cpp",\n'
     '        "opengl/MacIOSurfaceTextureHostOGL.cpp",\n    ]\n')
if s.count(c) != 1:
    raise SystemExit("cocoa OGL block anchor count=%d" % s.count(c))
s = s.replace(c, c + '\n    IPDL_SOURCES += [\n        "ipc/PNativeLayerRemote.ipdl",\n    ]\n', 1)

io.open(M, "w", encoding="utf-8").write(s)
print("gfx/layers/moz.build: IOSurfacePort + PNativeLayerRemote gated to cocoa")
