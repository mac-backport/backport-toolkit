/*
 * MacPorts backport-toolkit extension for MacportsLegacySupport.
 *
 * CCRandomGenerateBytes() — CommonCrypto RNG, public since macOS 10.10.
 * On earlier systems, emulate via arc4random_buf() (present since 10.7,
 * and provided by MLS itself below that).  Kept ABI-compatible with the
 * real declaration in <CommonCrypto/CommonRandom.h>.
 *
 * Follows the MLS idiom: guarded by a per-target feature test derived from
 * __MPLS_TARGET_OSVER so the symbol is only compiled in when the deployment
 * target predates the OS that first shipped it.
 */

#include "MacportsLegacySupport.h"

#define __MPLS_LIB_SUPPORT_CCRANDOM__   (__MPLS_TARGET_OSVER < 101000)

#if __MPLS_LIB_SUPPORT_CCRANDOM__

#include <stddef.h>

extern void arc4random_buf(void *buf, size_t nbytes);

/* CCRNGStatus is an int32_t; kCCSuccess == 0 */
int CCRandomGenerateBytes(void *bytes, size_t count);

int CCRandomGenerateBytes(void *bytes, size_t count) {
    arc4random_buf(bytes, count);
    return 0;
}

#endif /* __MPLS_LIB_SUPPORT_CCRANDOM__ */
