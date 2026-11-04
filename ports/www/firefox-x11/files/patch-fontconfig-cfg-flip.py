#!/usr/bin/env python3
# Wall #21 general helper: flip MULTI-target macos/ios font cfg-gates onto
# moz_wr_fontconfig, so our GTK/X11-on-Darwin build takes the unix/Fontconfig
# font path consistently. Only the any(macos,ios) / not(any(macos,ios[,windows]))
# shapes are touched -- NOT single target_os="macos" gates (those guard unrelated
# things like the Cocoa autoreleasepool, which must stay). Usage:
#   patch-fontconfig-cfg-flip.py <worksrcpath> <relfile> [<relfile> ...]
# Not in the delta (lost with the worktree).
import io, sys

def flip(path):
    s = io.open(path, encoding="utf-8").read()
    total = 0
    macos = [
        '#[cfg(any(target_os = "macos", target_os = "ios"))]',
        '#[cfg(any(target_os = "ios", target_os = "macos"))]',
    ]
    unix = [
        '#[cfg(not(any(target_os = "macos", target_os = "ios")))]',
        '#[cfg(not(any(target_os = "ios", target_os = "macos")))]',
        '#[cfg(not(any(target_os = "macos", target_os = "ios", target_os = "windows")))]',
        '#[cfg(not(any(target_os = "ios", target_os = "macos", target_os = "windows")))]',
    ]
    for g in macos:
        inner = g[len('#[cfg('):-len(')]')]           # e.g. any(target_os = "macos", target_os = "ios")
        new = '#[cfg(all(%s, not(moz_wr_fontconfig)))]' % inner
        c = s.count(g); total += c; s = s.replace(g, new)
    for g in unix:
        inner = g[len('#[cfg('):-len(')]')]           # e.g. not(any(...))
        new = '#[cfg(any(%s, moz_wr_fontconfig))]' % inner
        c = s.count(g); total += c; s = s.replace(g, new)
    if total == 0:
        raise SystemExit("%s: no multi-target macos/ios gates found" % path)
    io.open(path, "w", encoding="utf-8").write(s)
    print("flipped %d gate(s) in %s" % (total, path.split('/firefox-153.1.0/')[-1]))

W = sys.argv[1]
for rel in sys.argv[2:]:
    flip(W + "/" + rel)
