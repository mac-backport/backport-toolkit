// macos109_extras.c — nur die Symbole, die MacportsLegacySupport NICHT liefert.
// Alles andere (clock_gettime, *at, os_unfair_lock, getentropy, clonefile...) kommt aus
// libMacportsLegacySupport (dylib fuer DYLD-Insert / .a fuer statisches Output-Linking).
#include <stddef.h>
#include <errno.h>
#include <stdlib.h>
#include <dispatch/dispatch.h>

extern void arc4random_buf(void *, size_t);

// CommonCrypto CCRandomGenerateBytes (ab 10.10)
int CCRandomGenerateBytes(void *bytes, size_t count) { arc4random_buf(bytes, count); return 0; }

// C11 aligned allocation (macOS 10.15) ueber das auf 10.9 vorhandene POSIX-API.
void *aligned_alloc(size_t alignment, size_t size) {
    void *result = NULL;
    int error = posix_memalign(&result, alignment, size);
    if (error != 0) {
        errno = error;
        return NULL;
    }
    return result;
}

// QoS-Klassen kamen nach 10.9. Fuer V8 ist dies nur ein Scheduling-Hinweis.
int pthread_set_qos_class_self_np(int qos_class, int relative_priority) {
    (void)qos_class;
    (void)relative_priority;
    return 0;
}

// GCD-Neuzugaenge (10.10..10.14) -> Ersatz ueber vorhandene 10.9-GCD-APIs
void dispatch_set_qos_class_floor(void *o, int q, int p) { (void)o;(void)q;(void)p; }

dispatch_queue_t dispatch_queue_create_with_target(const char *l, dispatch_queue_attr_t a, dispatch_queue_t t)
    __asm__("_dispatch_queue_create_with_target$V2");
dispatch_queue_t dispatch_queue_create_with_target(const char *l, dispatch_queue_attr_t a, dispatch_queue_t t) {
    dispatch_queue_t q = dispatch_queue_create(l, a);
    if (q && t) dispatch_set_target_queue(q, t);
    return q;
}
dispatch_queue_t dispatch_workloop_create(const char *l) { return dispatch_queue_create(l, DISPATCH_QUEUE_SERIAL); }
dispatch_queue_t dispatch_workloop_create_inactive(const char *l) { return dispatch_queue_create(l, DISPATCH_QUEUE_SERIAL); }
