#!/bin/sh
# cache-stats.sh - show whether the compiler caches are actually working.
#
# Both caches can fail silently: a wrong owner on the cache dir, a missing
# wrapper, a port that disables ccache. Nothing errors out - builds just run
# at full cost. This prints the three caches side by side so that is visible.
#
# Set up 2026-11-07, see memory compiler-caches-macports-mac-10-9.
set -u
PREFIX=/opt/local
CCACHE_MP_DIR=$PREFIX/var/macports/build/.ccache
SCCACHE_MP_DIR=$CCACHE_MP_DIR/sccache

echo "=== ccache: C/C++ in MacPorts builds ==="
if ! grep -qE '^configureccache[[:space:]]+yes' $PREFIX/etc/macports/macports.conf 2>/dev/null; then
    echo "  OFF - configureccache is not yes in macports.conf"
else
    owner=$(stat -f '%Su' "$CCACHE_MP_DIR" 2>/dev/null || echo '?')
    [ "$owner" = macports ] || echo "  WARNING: $CCACHE_MP_DIR is owned by '$owner', expected 'macports'"
    CCACHE_DIR=$CCACHE_MP_DIR $PREFIX/bin/ccache -s 2>/dev/null \
        | grep -iE 'cacheable calls|hits:|misses:|cache size' | sed 's/^/  /'
fi

echo
echo "=== sccache: rust, interactive user ($(id -un)) ==="
if ! grep -q 'rustc-wrapper' "$HOME/.cargo/config.toml" 2>/dev/null; then
    echo "  OFF - no rustc-wrapper in ~/.cargo/config.toml"
else
    $PREFIX/bin/sccache --show-stats 2>/dev/null \
        | grep -iE '^(compile requests|cache hits|cache misses|non-cacheable calls|cache location|max cache size) ' | sed 's/^/  /'
fi

echo
echo "=== sccache: rust inside MacPorts ports (firefox-x11, nodejs26) ==="
if [ ! -d "$SCCACHE_MP_DIR" ]; then
    echo "  no cache dir yet - nothing built through it so far"
else
    # The stats live in the server process, so they must be queried as the user
    # that owns it. Capture first: a pipe would mask an empty/failed result.
    out=$(sudo -n -u macports env SCCACHE_DIR=$SCCACHE_MP_DIR SCCACHE_SERVER_PORT=4227 \
          SCCACHE_CACHE_SIZE=20G $PREFIX/bin/sccache --show-stats 2>/dev/null || true)
    if [ -n "$out" ]; then
        echo "$out" | grep -iE '^(compile requests|cache hits|cache misses|non-cacheable calls|cache location|max cache size) ' | sed 's/^/  /'
    else
        echo "  cannot query - needs root, run: sudo $0"
        echo "  on-disk size: $(du -sh "$SCCACHE_MP_DIR" 2>/dev/null | cut -f1)"
    fi
fi

echo
echo "Ports WITHOUT sccache by design: anything on the stock cargo/rust PortGroup"
echo "(ripgrep, lang/rust, devel/cargo) - only embedded-cargo-legacy is wired."
