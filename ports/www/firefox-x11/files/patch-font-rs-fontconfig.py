#!/usr/bin/env python3
# Wall #21 (WebRender font binding) — gfx/wr/webrender_api/src/font.rs.
# This edit is NOT in the complete-delta (lost with the work tree, like SkTArray).
# webrender's font.rs picks FontInstancePlatformOptions/FontHinting/FontLCDFilter
# per target_os: on Darwin (target_os="macos") the Mac variant (CoreText-style)
# is chosen, but our GTK/X11 build renders via Fontconfig and both the C++
# (gfx/2d/ScaledFontFontconfig.cpp) and the cbindgen-generated header need the
# UNIX variant (hinting/lcd_filter). Flip every macos/ios font gate on the custom
# cfg `moz_wr_fontconfig` (set via RUSTFLAGS): with it, Mac gates go false and unix
# gates go true, so our Darwin build uses the unix/Fontconfig font path throughout
# font.rs — ABI-consistent with -DMOZ_WR_FONTCONFIG (C++) and the cbindgen
# [defines] mapping "moz_wr_fontconfig" = "MOZ_WR_FONTCONFIG" (in the delta).
import io, sys

F = sys.argv[1] + "/gfx/wr/webrender_api/src/font.rs"
s = io.open(F, encoding="utf-8").read()

edits = [
    # Mac/iOS variant: only when NOT using the fontconfig backend.
    ('#[cfg(any(target_os = "macos", target_os = "ios"))]',
     '#[cfg(all(any(target_os = "macos", target_os = "ios"), not(moz_wr_fontconfig)))]',
     4),
    # unix variant (2-target exclusion): also when moz_wr_fontconfig is set.
    ('#[cfg(not(any(target_os = "macos", target_os = "ios")))]',
     '#[cfg(any(not(any(target_os = "macos", target_os = "ios")), moz_wr_fontconfig))]',
     2),
    # unix variant (3-target exclusion): also when moz_wr_fontconfig is set.
    ('#[cfg(not(any(target_os = "macos", target_os = "ios", target_os = "windows")))]',
     '#[cfg(any(not(any(target_os = "macos", target_os = "ios", target_os = "windows")), moz_wr_fontconfig))]',
     5),
]

for old, new, expect in edits:
    n = s.count(old)
    if n != expect:
        raise SystemExit("font.rs: expected %d of %r, found %d" % (expect, old[:50], n))
    s = s.replace(old, new)

io.open(F, "w", encoding="utf-8").write(s)
print("font.rs fontconfig gates flipped (4 mac / 2+5 unix)")
