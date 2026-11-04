/*
 * MacPorts backport-toolkit extension for MacportsLegacySupport.
 *
 * libdispatch (GCD) additions that postdate macOS 10.9, emulated with the
 * 10.9-era GCD API.  Only compiled in when the deployment target predates the
 * introducing OS.
 *
 *   dispatch_queue_create_with_target()  (10.12) — real export is the
 *       versioned symbol "$V2"; emulate with dispatch_queue_create() plus
 *       dispatch_set_target_queue().
 *   dispatch_workloop_create[_inactive]() (10.14) — approximate with a serial
 *       queue (workloops are serial; the priority-ordering guarantee is a hint
 *       we drop).  Return type is ABI-compatible with dispatch_workloop_t.
 */

#include "MacportsLegacySupport.h"

#define __MPLS_LIB_SUPPORT_DISPATCH_WITH_TARGET__  (__MPLS_TARGET_OSVER < 101200)
#define __MPLS_LIB_SUPPORT_DISPATCH_WORKLOOP__     (__MPLS_TARGET_OSVER < 101400)

#if __MPLS_LIB_SUPPORT_DISPATCH_WITH_TARGET__ || __MPLS_LIB_SUPPORT_DISPATCH_WORKLOOP__

#include <dispatch/dispatch.h>

#if __MPLS_LIB_SUPPORT_DISPATCH_WITH_TARGET__

dispatch_queue_t dispatch_queue_create_with_target(const char *label,
        dispatch_queue_attr_t attr, dispatch_queue_t target)
        __asm__("_dispatch_queue_create_with_target$V2");

dispatch_queue_t dispatch_queue_create_with_target(const char *label,
        dispatch_queue_attr_t attr, dispatch_queue_t target) {
    dispatch_queue_t q = dispatch_queue_create(label, attr);
    if (q && target) {
        dispatch_set_target_queue(q, target);
    }
    return q;
}

#endif /* __MPLS_LIB_SUPPORT_DISPATCH_WITH_TARGET__ */

#if __MPLS_LIB_SUPPORT_DISPATCH_WORKLOOP__

dispatch_queue_t dispatch_workloop_create(const char *label);
dispatch_queue_t dispatch_workloop_create_inactive(const char *label);

dispatch_queue_t dispatch_workloop_create(const char *label) {
    return dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
}

dispatch_queue_t dispatch_workloop_create_inactive(const char *label) {
    return dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
}

#endif /* __MPLS_LIB_SUPPORT_DISPATCH_WORKLOOP__ */

#endif /* any dispatch compat */
