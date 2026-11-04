#!/usr/bin/env python3
# Wall #21 cont'd — gfx/wr/webrender/src/resource_cache.rs. Same font-backend flip:
# the macOS arm reads native.name (CoreText NativeFontHandle); with our unix
# NativeFontHandle it must take the unix arm (native.path/index). Flip on
# moz_wr_fontconfig. Not in the delta (lost with the worktree).
import io, sys
F = sys.argv[1] + "/gfx/wr/webrender/src/resource_cache.rs"
s = io.open(F, encoding="utf-8").read()
edits = [
    ('#[cfg(any(target_os = "macos", target_os = "ios"))]',
     '#[cfg(all(any(target_os = "macos", target_os = "ios"), not(moz_wr_fontconfig)))]', 1),
    ('#[cfg(not(any(target_os = "macos", target_os = "ios")))]',
     '#[cfg(any(not(any(target_os = "macos", target_os = "ios")), moz_wr_fontconfig))]', 1),
]
for old, new, expect in edits:
    n = s.count(old)
    if n != expect:
        raise SystemExit("resource_cache.rs: expected %d of %r, found %d" % (expect, old[:50], n))
    s = s.replace(old, new)
io.open(F, "w", encoding="utf-8").write(s)
print("resource_cache.rs: font gates flipped")
