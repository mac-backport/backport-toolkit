#!/usr/bin/env python3
# Wall #21 cont'd — gfx/wr/wr_glyph_rasterizer/src/lib.rs.
# Companion to the font.rs flip: with moz_wr_fontconfig our Darwin build uses the
# UNIX NativeFontHandle/FontInstancePlatformOptions, so WebRender's glyph rasterizer
# must also use its UNIX (Fontconfig/FreeType) backend, not the macOS (CoreText)
# one — otherwise platform/macos/font.rs fails (no field `name` on the unix
# NativeFontHandle, etc.). Flip the platform-module selection: macOS gates off,
# unix gates on, under moz_wr_fontconfig. Not in the delta (lost with the worktree).
import io, sys

F = sys.argv[1] + "/gfx/wr/wr_glyph_rasterizer/src/lib.rs"
s = io.open(F, encoding="utf-8").read()

edits = [
    # macOS platform selection + module -> only when NOT fontconfig
    ('#[cfg(any(target_os = "macos", target_os = "ios"))]',
     '#[cfg(all(any(target_os = "macos", target_os = "ios"), not(moz_wr_fontconfig)))]'),
    ('#[cfg(any(target_os = "ios", target_os = "macos"))]',
     '#[cfg(all(any(target_os = "ios", target_os = "macos"), not(moz_wr_fontconfig)))]'),
    # unix platform selection + module -> also under fontconfig
    ('#[cfg(any(target_os = "android", all(unix, not(any(target_os = "ios", target_os = "macos")))))]',
     '#[cfg(any(target_os = "android", all(unix, not(any(target_os = "ios", target_os = "macos"))), moz_wr_fontconfig))]'),
    ('#[cfg(any(target_os = "android", all(unix, not(any(target_os = "macos", target_os = "ios")))))]',
     '#[cfg(any(target_os = "android", all(unix, not(any(target_os = "macos", target_os = "ios"))), moz_wr_fontconfig))]'),
]

for old, new in edits:
    n = s.count(old)
    if n != 1:
        raise SystemExit("lib.rs: expected 1 of %r, found %d" % (old[:60], n))
    s = s.replace(old, new)

io.open(F, "w", encoding="utf-8").write(s)
print("wr_glyph_rasterizer lib.rs: platform selection flipped to unix under fontconfig")
