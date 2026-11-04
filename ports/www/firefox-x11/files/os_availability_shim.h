/* macOS 10.9 backport shim for <os/availability.h> (a 10.10+ SDK header).
 * Installed into a private include dir added via -isystem BEFORE the 10.9 SDK,
 * so code that does #include <os/availability.h> (e.g. gfx/angle) compiles on
 * 10.9. All availability annotations become no-ops; os/log.h itself is gated by
 * __has_include in the ANGLE source patch (part of the worktree delta). */
#ifndef _OS_AVAILABILITY_SHIM_H_
#define _OS_AVAILABILITY_SHIM_H_

#ifndef API_AVAILABLE
#define API_AVAILABLE(...)
#endif
#ifndef API_DEPRECATED
#define API_DEPRECATED(...)
#endif
#ifndef API_DEPRECATED_WITH_REPLACEMENT
#define API_DEPRECATED_WITH_REPLACEMENT(...)
#endif
#ifndef API_UNAVAILABLE
#define API_UNAVAILABLE(...)
#endif
#ifndef __API_AVAILABLE
#define __API_AVAILABLE(...)
#endif
#ifndef __API_DEPRECATED
#define __API_DEPRECATED(...)
#endif
#ifndef __API_DEPRECATED_WITH_REPLACEMENT
#define __API_DEPRECATED_WITH_REPLACEMENT(...)
#endif
#ifndef __API_UNAVAILABLE
#define __API_UNAVAILABLE(...)
#endif

#endif /* _OS_AVAILABILITY_SHIM_H_ */
