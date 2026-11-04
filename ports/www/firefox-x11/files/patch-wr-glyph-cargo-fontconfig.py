#!/usr/bin/env python3
# Wall #21 cont'd — gfx/wr/wr_glyph_rasterizer/Cargo.toml.
# The unix (Fontconfig/FreeType) rasterizer we selected needs the freetype+libc
# crates, but they're declared only for non-macOS unix. Cargo target-cfg cannot
# see the custom --cfg moz_wr_fontconfig, so broaden the section to all unix (incl.
# macOS) -> our Darwin build pulls freetype+libc. The mac deps section stays (unused
# now, harmless). Not in the delta (lost with the worktree).
import io, sys
F = sys.argv[1] + "/gfx/wr/wr_glyph_rasterizer/Cargo.toml"
s = io.open(F, encoding="utf-8").read()
old = '[target.\'cfg(any(target_os = "android", all(unix, not(any(target_os = "macos", target_os = "ios")))))\'.dependencies]'
new = '[target.\'cfg(any(target_os = "android", unix))\'.dependencies]'
if s.count(old) != 1:
    raise SystemExit("Cargo.toml: expected 1 match, found %d" % s.count(old))
io.open(F, "w", encoding="utf-8").write(s.replace(old, new))
print("wr_glyph_rasterizer Cargo.toml: freetype/libc now available on Darwin")
