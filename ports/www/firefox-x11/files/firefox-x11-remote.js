// firefox-x11-remote.js — shipped DEFAULT prefs for the macOS-10.9 GTK/X11 build.
// Installed to <prefix>/lib/firefox/browser/defaults/preferences/ so every user
// and profile inherits them with no per-profile seeding. These are pref()
// defaults (user-overridable), not locks. Rationale: software WebRender viewed
// over `ssh -X` — cut how OFTEN and how MUCH Firefox repaints, and skip GL paths
// that can't exist over remote X. See DOCTRINE / firefox-x11 notes.

// --- Stability: no GPU process (its own X connection aborted with BadDrawable),
//     explicit software WebRender, no GL probe stall.
pref("layers.gpu-process.enabled", false);

// --- Do NOT self-register as default browser. Firefox' GTK shell integration
//     rewrites ~/.config/mimeapps.list on every start and drops a
//     `userapp-Nightly-*.desktop` whose Exec = the binary that happens to run.
//     If that binary was the throwaway build-tree copy (GPU process ON), every
//     GTK app opening a link then launched it -> BadDrawable abort on close.
//     The default handler is pinned once to firefox-x11.desktop instead.
pref("browser.shell.checkDefaultBrowser", false);
pref("gfx.webrender.software", true);
pref("gfx.webrender.compositor", false);
pref("gfx.canvas.accelerated", false);
pref("gfx.x11-egl.force-disabled", true);

// --- Repaint frequency (the real remote-X win) -----------------------------
pref("layout.frame_rate", 30);                 // cap compositor to 30 Hz
pref("general.smoothScroll", false);           // 1 jump, not ~20 blits/notch
pref("toolkit.cosmeticAnimations.enabled", false);
pref("ui.prefersReducedMotion", 1);
pref("image.animation_mode", "none");          // freeze looping GIF/APNG

// --- Processes / background work -------------------------------------------
pref("dom.ipc.processCount", 2);               // low per-user; box is shared
pref("fission.autostart", false);              // large RAM saver on a shared box
pref("extensions.pocket.enabled", false);
pref("browser.newtabpage.enabled", false);     // blank new tab paints nothing
pref("browser.startup.homepage", "about:blank");
pref("toolkit.telemetry.enabled", false);
pref("toolkit.telemetry.unified", false);
pref("datareporting.healthreport.uploadEnabled", false);
pref("browser.uidensity", 1);                  // compact chrome = smaller repaint

// --- Doomed-over-remote-X GPU features -------------------------------------
pref("webgl.disabled", true);                  // no GL: stop sites trying
pref("media.hardware-video-decoding.enabled", false);
pref("media.autoplay.default", 5);             // block autoplay audio+video
pref("media.autoplay.blocking_policy", 2);

// --- Image decode (16 GB box: avoid re-decode+re-paint on scrollback) ------
pref("image.mem.decode_bytes_at_a_time", 65536);
pref("image.mem.surfacecache.max_size_kb", 524288);
