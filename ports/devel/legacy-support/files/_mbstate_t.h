/*
 * backport-toolkit extension for MacportsLegacySupport.
 *
 * Make the 10.9 SDK header <sys/_types/_mbstate_t.h> self-contained.
 *
 * On macOS 10.9 that header does `typedef __darwin_mbstate_t mbstate_t;`
 * WITHOUT first pulling <sys/_types.h> (where __darwin_mbstate_t is defined).
 * It was made self-contained on 10.10+.  Modern libc++ (<iosfwd> ->
 * __mbstate_t.h) includes it early and in isolation, so on 10.9 it fails with
 * "unknown type name '__darwin_mbstate_t'".  This hits essentially every C++
 * build using a modern libc++ (LLVM, Rust, ...).
 *
 * Since MacportsLegacySupport's include dir is placed on the -isystem search
 * path (PortGroup legacysupport) ahead of /usr/include, this shim is found
 * first: it guarantees the base types exist, then defers to the real SDK
 * header via #include_next.  Fixes the wall toolkit-wide, natively, with no
 * per-port flags and no effect on the C / assembly paths.
 */

#include <sys/_types.h>
#include_next <sys/_types/_mbstate_t.h>
