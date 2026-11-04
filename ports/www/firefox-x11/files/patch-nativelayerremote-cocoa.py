#!/usr/bin/env python3
# gfx/layers/moz.build — NativeLayerCommandQueue.{h,cpp} + NativeLayerRemoteChild.h
# + NativeLayerRemoteParent.h sit in UNCONDITIONAL blocks, but their only consumers
# are the (already cocoa-gated) NativeLayerRootRemoteMac* files, and they pull the
# PNativeLayerRemote ipdl -> IOSurfacePort (mach, unavailable in our POSIX-IPC/GTK
# build). X11 doesn't use native layers -> gate the whole remote-native-layer
# cluster to cocoa. Not in the delta. (Runs after patch-iosurfaceport-cocoa.py.)
import io, sys
M = sys.argv[1] + "/gfx/layers/moz.build"
s = io.open(M, encoding="utf-8").read()

def rm(line):
    global s
    if s.count(line) != 1:
        raise SystemExit("expected 1 of %r, found %d" % (line, s.count(line)))
    s = s.replace(line, "")

rm('    "NativeLayerCommandQueue.h",\n')
rm('    "NativeLayerRemoteChild.h",\n')
rm('    "NativeLayerRemoteParent.h",\n')
rm('    "NativeLayerCommandQueue.cpp",\n')

# add the 3 headers to the cocoa EXPORTS.mozilla.layers block (after GpuFence anchor)
a = '    EXPORTS.mozilla.layers += [\n        "GpuFenceMTLSharedEvent.h",\n'
if s.count(a) != 1:
    raise SystemExit("cocoa EXPORTS anchor count=%d" % s.count(a))
s = s.replace(a, a + '        "NativeLayerCommandQueue.h",\n'
                    '        "NativeLayerRemoteChild.h",\n'
                    '        "NativeLayerRemoteParent.h",\n', 1)

# add the .cpp to the cocoa SOURCES block (after GpuFence anchor)
b = '    SOURCES += [\n        "GpuFenceMTLSharedEvent.cpp",\n'
if s.count(b) != 1:
    raise SystemExit("cocoa SOURCES anchor count=%d" % s.count(b))
s = s.replace(b, b + '        "NativeLayerCommandQueue.cpp",\n', 1)

io.open(M, "w", encoding="utf-8").write(s)
print("gfx/layers/moz.build: NativeLayerRemote cluster gated to cocoa")
