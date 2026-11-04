#!/usr/bin/env python3
# Narrow bare '#ifdef XP_MACOSX' to the Cocoa toolkit in compiled files whose
# XP_MACOSX blocks reference cocoa-only symbols (defined only in cocoa-gated .cpp).
# Usage: patch-cpp-cocoa-gate.py <worksrcpath> <relfile> <expected_count> [...]
import io, sys
W = sys.argv[1]
args = sys.argv[2:]
for i in range(0, len(args), 2):
    rel, exp = args[i], int(args[i+1])
    p = W + "/" + rel
    s = io.open(p, encoding="utf-8").read()
    old = "#ifdef XP_MACOSX\n"
    n = s.count(old)
    if n != exp:
        raise SystemExit("%s: expected %d bare '#ifdef XP_MACOSX', found %d" % (rel, exp, n))
    s = s.replace(old, "#if defined(XP_MACOSX) && defined(MOZ_WIDGET_COCOA)\n")
    io.open(p, "w", encoding="utf-8").write(s)
    print("gated %d in %s" % (n, rel))
