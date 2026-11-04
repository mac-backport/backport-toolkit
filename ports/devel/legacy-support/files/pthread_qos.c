/*
 * MacPorts backport-toolkit extension for MacportsLegacySupport.
 *
 * QoS (Quality of Service) scheduling hints arrived in macOS 10.10.  On 10.9
 * there is no kernel QoS support, so these are advisory no-ops that preserve
 * the ABI.  Callers (e.g. modern LLVM / Rust std) only use them as scheduling
 * hints; dropping them changes nothing but priority tuning.
 *
 *   pthread_set_qos_class_self_np()  <pthread/qos.h>          (10.10)
 *   dispatch_set_qos_class_floor()   libdispatch QoS SPI      (10.10)
 *
 * Signatures use int / void* which are ABI-compatible with the real
 * qos_class_t (an int-sized enum) and dispatch_object_t (a pointer).
 */

#include "MacportsLegacySupport.h"

#define __MPLS_LIB_SUPPORT_PTHREAD_QOS__   (__MPLS_TARGET_OSVER < 101000)

#if __MPLS_LIB_SUPPORT_PTHREAD_QOS__

/*
 * pthread_override_t / start / end use void* (ABI-compatible with the real
 * pthread_t / pthread_override_t opaque pointers) and int (qos_class_t). start
 * returns NULL (no override installed); end tolerates NULL. Callers (e.g.
 * Firefox dom/ipc/ProcessHangMonitor.cpp) treat NULL as "no override".
 */
int   pthread_set_qos_class_self_np(int qos_class, int relative_priority);
void  dispatch_set_qos_class_floor(void *object, int qos_class,
                                   int relative_priority);
void *pthread_override_qos_class_start_np(void *thread, int qos_class,
                                          int relative_priority);
int   pthread_override_qos_class_end_np(void *override);

int pthread_set_qos_class_self_np(int qos_class, int relative_priority) {
    (void)qos_class;
    (void)relative_priority;
    return 0;
}

void *pthread_override_qos_class_start_np(void *thread, int qos_class,
                                          int relative_priority) {
    (void)thread;
    (void)qos_class;
    (void)relative_priority;
    return (void *)0;
}

int pthread_override_qos_class_end_np(void *override) {
    (void)override;
    return 0;
}

void dispatch_set_qos_class_floor(void *object, int qos_class,
                                  int relative_priority) {
    (void)object;
    (void)qos_class;
    (void)relative_priority;
}

#endif /* __MPLS_LIB_SUPPORT_PTHREAD_QOS__ */
