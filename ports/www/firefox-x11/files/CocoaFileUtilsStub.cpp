/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

/* MacPorts GTK-on-Darwin backport: CocoaFileUtils.mm depends on the cocoa-only
 * widget header nsCocoaUtils.h, which is not built for the GTK toolkit. The GTK
 * build only references the download-metadata helpers below; provide no-op
 * stubs (macOS quarantine/origin xattrs are a Finder/LaunchServices nicety that
 * the GTK build does not apply). */

#include "CocoaFileUtils.h"

namespace CocoaFileUtils {

void AddOriginMetadataToFile(const CFStringRef, const CFURLRef, const CFURLRef) {}

void AddQuarantineMetadataToFile(const CFStringRef, const CFURLRef,
                                 const CFURLRef, const bool, const bool) {}

}  // namespace CocoaFileUtils
