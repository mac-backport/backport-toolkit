// nsworkspace_openurls_shim.m
// Ruestet neuere NSWorkspace-Methoden auf 10.9 nach:
// - openURLs:withApplicationAtURL:options:configuration:error: (ab macOS 10.15)
//   wird auf das alte openURL: (10.0) umgeleitet.
// - accessibilityDisplayShouldReduceMotion liefert NO, weil Mavericks diese
//   Bedienungshilfe noch nicht als NSWorkspace-Methode anbietet.
// - isVoiceOverEnabled liefert NO; Codex fragt dies nach dem TUI-Start in einem
//   Screenreader-Thread ab, Mavericks kennt den Selector aber noch nicht.
// Per DYLD_INSERT_LIBRARIES einschleusen.
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// Ersatz-Implementierung: erste URL im Default-Browser oeffnen (alte API).
static id shim_openURLs(id self, SEL _cmd,
                        id urls, id appURL,
                        unsigned long options, id configuration, id *error) {
    (void)_cmd; (void)appURL; (void)options; (void)configuration;
    if (error) { *error = nil; }
    if (urls) {
        id first = ((id (*)(id, SEL))objc_msgSend)(urls, sel_registerName("firstObject"));
        if (first) {
            NSWorkspace *ws = [NSWorkspace sharedWorkspace];
            ((BOOL (*)(id, SEL, id))objc_msgSend)(ws, sel_registerName("openURL:"), first);
        }
    }
    return nil;  // Rueckgabe (NSRunningApplication*) wird vom Aufrufer ignoriert
}

// Neuere Codex-Versionen fragen diesen Wert schon beim TUI-Start ab. Ohne die
// Methode wirft AppKit auf 10.9 eine Objective-C-Exception, die Rust abbricht.
static BOOL shim_accessibilityDisplayShouldReduceMotion(id self, SEL _cmd) {
    (void)self; (void)_cmd;
    return NO;
}

static BOOL shim_isVoiceOverEnabled(id self, SEL _cmd) {
    (void)self; (void)_cmd;
    return NO;
}

__attribute__((constructor))
static void install_nsworkspace_shim(void) {
    Class cls = objc_getClass("NSWorkspace");
    if (!cls) return;
    SEL sel = sel_registerName("openURLs:withApplicationAtURL:options:configuration:error:");
    // nur hinzufuegen, wenn die Methode fehlt (auf 10.9 der Fall)
    if (!class_getInstanceMethod(cls, sel)) {
        // Typkodierung: ret=@ self=@ _cmd=: urls=@ appURL=@ options=Q configuration=@ error=^@
        class_addMethod(cls, sel, (IMP)shim_openURLs, "@@:@@Q@^@");
        if (getenv("SHIM_DEBUG")) fprintf(stderr, "[nsws-shim] openURLs:... nachgeruestet\n");
    }

    SEL reduce_motion = sel_registerName("accessibilityDisplayShouldReduceMotion");
    if (!class_getInstanceMethod(cls, reduce_motion)) {
        // Mavericks/x86_64 definiert BOOL als signed char: ret=c self=@ _cmd=:
        class_addMethod(cls, reduce_motion,
                        (IMP)shim_accessibilityDisplayShouldReduceMotion,
                        "c@:");
        if (getenv("SHIM_DEBUG")) {
            fprintf(stderr, "[nsws-shim] accessibilityDisplayShouldReduceMotion nachgeruestet\n");
        }
    }

    SEL voice_over = sel_registerName("isVoiceOverEnabled");
    if (!class_getInstanceMethod(cls, voice_over)) {
        class_addMethod(cls, voice_over, (IMP)shim_isVoiceOverEnabled, "c@:");
        if (getenv("SHIM_DEBUG")) {
            fprintf(stderr, "[nsws-shim] isVoiceOverEnabled nachgeruestet\n");
        }
    }
}
