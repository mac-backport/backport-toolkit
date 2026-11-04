/*
 * MacPorts backport-toolkit extension for MacportsLegacySupport.
 *
 * aligned_alloc() — C11 aligned allocation, first available on macOS 10.15.
 * Emulated via posix_memalign(), which is available since 10.6 (and provided
 * by MLS below that).  Needed on 10.9 because modern libc++ built with
 * -faligned-allocation / -D_LIBCPP_DISABLE_AVAILABILITY assumes aligned_alloc
 * exists when lowering aligned operator new.
 *
 * Guarded by the MLS per-target feature idiom.
 */

#include "MacportsLegacySupport.h"

#define __MPLS_LIB_SUPPORT_ALIGNED_ALLOC__   (__MPLS_TARGET_OSVER < 101500)

#if __MPLS_LIB_SUPPORT_ALIGNED_ALLOC__

#include <stdlib.h>
#include <errno.h>

void *aligned_alloc(size_t alignment, size_t size);

void *aligned_alloc(size_t alignment, size_t size) {
    void *result = NULL;
    int err = posix_memalign(&result, alignment, size);
    if (err != 0) {
        errno = err;
        return NULL;
    }
    return result;
}

#endif /* __MPLS_LIB_SUPPORT_ALIGNED_ALLOC__ */
