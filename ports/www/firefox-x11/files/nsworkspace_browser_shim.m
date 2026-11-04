// nsworkspace_browser_shim.m
// ---------------------------------------------------------------------------
// System-browser integration for the GTK/X11 Firefox on macOS 10.9.
//
// PURPOSE
//   Make ANY Cocoa/console app that opens a URL via NSWorkspace behave as if
//   the X11 Firefox were the default browser, opening on the CURRENT ssh
//   session's X display (so the page appears on the remote client), instead of
//   LaunchServices launching a browser on the physical console (reserved for
//   Kodi). Not app-specific: injected process-wide via DYLD_INSERT_LIBRARIES
//   from the login environment (see /opt/local/etc/firefox-x11/browser.env).
//
// BEHAVIOUR
//   * Retrofits the 10.15+ method
//       -[NSWorkspace openURLs:withApplicationAtURL:options:configuration:error:]
//     onto 10.9 (as the old codex shim did) so callers of the new API don't
//     crash — but routes the open through Firefox.
//   * Swizzles the classic -[NSWorkspace openURL:] (10.0) so existing callers
//     are redirected too.
//   * Only http/https URLs are sent to Firefox. Every other scheme (file:,
//     mailto:, custom) falls through to the original LaunchServices behaviour.
//   * Redirect happens only when $DISPLAY is set (i.e. inside an X-forwarded
//     session). With no DISPLAY we do nothing special and let the original
//     path run, so local/console use is unaffected.
//
// FIREFOX BINARY
//   Resolved from $FIREFOX_BROWSER_BIN, else /opt/local/bin/firefox.
//   Spawned with posix_spawn inheriting the current environment, so DISPLAY,
//   the user's profile ($HOME), and prefs all apply — no launcher needed.
// ---------------------------------------------------------------------------
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <spawn.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

extern char **environ;

static const char *ff_binary(void) {
    const char *b = getenv("FIREFOX_BROWSER_BIN");
    if (b && *b) return b;
    return "/opt/local/bin/firefox";
}

// Spawn Firefox for an http/https URL, detached, inheriting our environment
// (DISPLAY, HOME, ...). Returns YES if we handled it.
static BOOL ff_open_urlstring(NSString *urlstr) {
    if (!urlstr) return NO;
    NSString *lower = [urlstr lowercaseString];
    if (![lower hasPrefix:@"http://"] && ![lower hasPrefix:@"https://"]) {
        return NO;                    // not a web URL -> let the original handle it
    }
    if (!getenv("DISPLAY")) {
        return NO;                    // no X session -> don't hijack; fall through
    }
    const char *bin = ff_binary();
    const char *url = [urlstr UTF8String];
    if (!url) return NO;
    // argv: firefox --new-tab <url>. --new-tab reuses a running instance for the
    // same profile (remote command) or starts one; no --no-remote here so a
    // second URL lands as a tab in the user's existing window.
    char *const argv[] = { (char *)bin, (char *)"--new-tab", (char *)url, NULL };
    pid_t pid;
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    int rc = posix_spawn(&pid, bin, &fa, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&fa);
    if (rc != 0) {
        if (getenv("SHIM_DEBUG"))
            fprintf(stderr, "[ff-browser-shim] posix_spawn(%s) failed: %s\n",
                    bin, strerror(rc));
        return NO;                    // spawn failed -> fall back to original
    }
    if (getenv("SHIM_DEBUG"))
        fprintf(stderr, "[ff-browser-shim] opened %s in %s (DISPLAY=%s)\n",
                url, bin, getenv("DISPLAY"));
    return YES;
}

static BOOL ff_open_nsurl(id nsurl) {
    if (!nsurl) return NO;
    NSString *s = ((NSString *(*)(id, SEL))objc_msgSend)(
        nsurl, sel_registerName("absoluteString"));
    return ff_open_urlstring(s);
}

// --- Replacement for the 10.15+ openURLs:...: open first URL via Firefox -----
static id shim_openURLs(id self, SEL _cmd,
                        id urls, id appURL,
                        unsigned long options, id configuration, id *error) {
    (void)self; (void)_cmd; (void)appURL; (void)options; (void)configuration;
    if (error) { *error = nil; }
    if (urls) {
        id first = ((id (*)(id, SEL))objc_msgSend)(urls, sel_registerName("firstObject"));
        if (ff_open_nsurl(first)) return nil;
        // Fall back to the old API if we didn't handle it (non-web / no DISPLAY).
        if (first) {
            NSWorkspace *ws = [NSWorkspace sharedWorkspace];
            ((BOOL (*)(id, SEL, id))objc_msgSend)(
                ws, sel_registerName("openURL:"), first);
        }
    }
    return nil;
}

// --- Swizzle for the classic openURL: --------------------------------------
static BOOL (*orig_openURL)(id, SEL, id) = NULL;
static BOOL swz_openURL(id self, SEL _cmd, id nsurl) {
    if (ff_open_nsurl(nsurl)) return YES;
    if (orig_openURL) return orig_openURL(self, _cmd, nsurl);
    return NO;
}

__attribute__((constructor))
static void install_browser_shim(void) {
    Class cls = objc_getClass("NSWorkspace");
    if (!cls) return;

    // (1) Retrofit openURLs:withApplicationAtURL:options:configuration:error:
    SEL sNew = sel_registerName("openURLs:withApplicationAtURL:options:configuration:error:");
    if (!class_getInstanceMethod(cls, sNew)) {
        class_addMethod(cls, sNew, (IMP)shim_openURLs, "@@:@@Q@^@");
        if (getenv("SHIM_DEBUG"))
            fprintf(stderr, "[ff-browser-shim] openURLs:... retrofitted\n");
    }

    // (2) Swizzle openURL: to redirect web URLs to Firefox on $DISPLAY.
    SEL sOld = sel_registerName("openURL:");
    Method m = class_getInstanceMethod(cls, sOld);
    if (m) {
        orig_openURL = (BOOL (*)(id, SEL, id))method_getImplementation(m);
        method_setImplementation(m, (IMP)swz_openURL);
        if (getenv("SHIM_DEBUG"))
            fprintf(stderr, "[ff-browser-shim] openURL: swizzled\n");
    }
}
