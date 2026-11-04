/*
 * MacPorts backport-toolkit extension for MacportsLegacySupport.
 *
 * mkostemp() — like mkstemp(3) but takes extra open(2) flags.  A GNU/BSD
 * extension that Apple first shipped in the macOS 10.12 SDK; absent on 10.9.
 * Modern sources assume it on Darwin (e.g. libffi's closures.c ships a
 * fficonfig.h with HAVE_MKOSTEMP=1 generated on a newer macOS), so a 10.9
 * build fails with an undeclared 'mkostemp'.
 *
 * Implemented on top of mkstemp() (POSIX, present since 10.4) plus fcntl()
 * to layer on the descriptor/status flags mkostemp accepts.  This is not as
 * atomic as a native O_CLOEXEC open, but matches the observable semantics and
 * is sufficient for the callers that use it (temp-file creation).
 *
 * Guarded by the MLS per-target feature idiom (10.12 = best-effort ceiling).
 */

#include "MacportsLegacySupport.h"

#define __MPLS_LIB_SUPPORT_MKOSTEMP__   (__MPLS_TARGET_OSVER < 101200)

#if __MPLS_LIB_SUPPORT_MKOSTEMP__

#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

int mkostemp(char *tmpl, int oflags);

int mkostemp(char *tmpl, int oflags) {
    int fd = mkstemp(tmpl);
    if (fd < 0)
        return -1;

    /* mkstemp already created the file O_RDWR|O_CREAT|O_EXCL.  Layer on the
     * additional flags mkostemp accepts: the close-on-exec descriptor flag
     * and the file status flags. */
    if (oflags & O_CLOEXEC) {
        int fdflags = fcntl(fd, F_GETFD);
        if (fdflags != -1)
            (void) fcntl(fd, F_SETFD, fdflags | FD_CLOEXEC);
    }

    {
        int stflags = oflags & (O_APPEND | O_NONBLOCK
#ifdef O_SYNC
                                | O_SYNC
#endif
#ifdef O_DSYNC
                                | O_DSYNC
#endif
                                );
        if (stflags) {
            int cur = fcntl(fd, F_GETFL);
            if (cur != -1)
                (void) fcntl(fd, F_SETFL, cur | stflags);
        }
    }

    return fd;
}

#endif /* __MPLS_LIB_SUPPORT_MKOSTEMP__ */
