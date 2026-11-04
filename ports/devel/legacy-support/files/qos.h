/*
 * <sys/qos.h> — MacportsLegacySupport backport-toolkit overlay shim for macOS 10.9.
 *
 * Apple added <sys/qos.h> (QoS scheduling classes) in macOS 10.10; the 10.9 SDK
 * has neither the header nor qos_class_t. Modern sources (Firefox dom/ipc/*,
 * V8, ...) do `#include <sys/qos.h>` unconditionally under XP_MACOSX and reference
 * QOS_CLASS_*.  This self-contained shim provides the type + constants (Apple ABI
 * values) so those `#include <sys/qos.h>` compile on 10.9.
 *
 * The qos_class_t typedef is shared with the <pthread.h> wrapper (which also
 * declares pthread_set_qos_class_self_np, exactly as real macOS lays it out);
 * both guard the typedef with __MPLS_QOS_CLASS_T_DEFINED so whichever header is
 * included first defines it and the other skips it — no duplicate-typedef error
 * when a TU pulls in both.  Installed into the LegacySupport include tree so
 * -isystem picks it up; only ever used on 10.9 (a 10.10+ SDK ships the real one).
 *
 * Remove once upstream MLS ships <sys/qos.h> itself.
 */
#ifndef _MPLS_SYS_QOS_H_
#define _MPLS_SYS_QOS_H_

#ifndef __MPLS_QOS_CLASS_T_DEFINED
#define __MPLS_QOS_CLASS_T_DEFINED
typedef enum {
    QOS_CLASS_USER_INTERACTIVE = 0x21,
    QOS_CLASS_USER_INITIATED   = 0x19,
    QOS_CLASS_DEFAULT          = 0x15,
    QOS_CLASS_UTILITY          = 0x11,
    QOS_CLASS_BACKGROUND       = 0x09,
    QOS_CLASS_UNSPECIFIED      = 0x00
} qos_class_t;
#endif /* __MPLS_QOS_CLASS_T_DEFINED */

#endif /* _MPLS_SYS_QOS_H_ */
