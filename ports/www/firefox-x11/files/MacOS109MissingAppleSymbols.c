/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * macOS 10.9 GTK-on-Darwin backport shim.
 *
 * Several Rust crates linked into libxul reference Apple framework symbols that
 * only exist on newer macOS releases. Because these are `-Wl,-U` (flat-namespace,
 * dynamically-looked-up) references, libxul *links* on 10.9 but dyld refuses to
 * *load* it: a flat-namespace undefined symbol that resolves nowhere aborts the
 * load ("Symbol not found: _kSecKeyAlgorithm...").
 *
 * This file defines those symbols inside libxul itself so the flat-namespace
 * lookup resolves. Every one is on a code path that cannot function on 10.9
 * anyway, so the stubs return "unavailable"/NULL and the feature degrades
 * cleanly:
 *   - Security SecKey* signing API (10.12+): used by security/manager/ssl/
 *     osclientcerts (OS client-cert PKCS#11 module). That module is opt-in
 *     (pref security.osclientcerts.autoload, off by default) and its Backend
 *     never runs unless enabled; the stubs just satisfy the linker/loader.
 *   - MTLCopyAllDevices (Metal, absent on 10.9): wgpu enumerates Metal adapters
 *     -> returns none -> WebGPU uses no Metal backend (we build GL only anyway).
 *   - MIDIInputPortCreateWithBlock (CoreMIDI 10.11+): WebMIDI input port
 *     creation -> returns an error -> no MIDI input.
 *   - sendmsg_x/recvmsg_x (10.10+ batch UDP): neqo's QUIC "Apple fast datapath"
 *     probe -> returns ENOSYS -> probe reports unavailable -> normal sendmsg/
 *     recvmsg path is used.
 *
 * The device is pinned to 10.9 permanently, so shadowing these Apple symbols is
 * safe (the real ones are not present to conflict with).
 */

#include <CoreFoundation/CoreFoundation.h>
#include <sys/types.h>
#include <errno.h>

/* ---- Security.framework: SecKey* signing constants (macOS 10.12+) ----
 * osclientcerts/bindings_macos.rs declares these as `static ...: CFStringRef`.
 * Values mirror Apple's public algorithm identifiers; only consulted on the
 * signing path, which cannot execute on 10.9. */
const CFStringRef kSecKeyAlgorithmRSASignatureRaw =
    CFSTR("algid:sign:RSA:raw");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15Raw =
    CFSTR("algid:sign:RSA:digest-PKCS1v15");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA1 =
    CFSTR("algid:sign:RSA:digest-PKCS1v15:SHA1");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256 =
    CFSTR("algid:sign:RSA:digest-PKCS1v15:SHA256");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA384 =
    CFSTR("algid:sign:RSA:digest-PKCS1v15:SHA384");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512 =
    CFSTR("algid:sign:RSA:digest-PKCS1v15:SHA512");
const CFStringRef kSecKeyAlgorithmECDSASignatureDigestX962SHA1 =
    CFSTR("algid:sign:ECDSA:digest-X962:SHA1");
const CFStringRef kSecKeyAlgorithmECDSASignatureDigestX962SHA256 =
    CFSTR("algid:sign:ECDSA:digest-X962:SHA256");
const CFStringRef kSecKeyAlgorithmECDSASignatureDigestX962SHA384 =
    CFSTR("algid:sign:ECDSA:digest-X962:SHA384");
const CFStringRef kSecKeyAlgorithmECDSASignatureDigestX962SHA512 =
    CFSTR("algid:sign:ECDSA:digest-X962:SHA512");
/* Elliptic-curve key type constant (10.12+ spelling); value matches Apple's. */
const CFStringRef kSecAttrKeyTypeECSECPrimeRandom = CFSTR("73");

/* ---- Security.framework: SecKey* signing functions (macOS 10.12+) ----
 * Opaque handles are taken as void* (pointer ABI matches SecKeyRef). Returning
 * NULL makes osclientcerts treat the key as unusable for signing. */
CFDataRef SecKeyCreateSignature(void* key, CFStringRef algorithm, CFDataRef data,
                                CFErrorRef* error) {
  (void)key;
  (void)algorithm;
  (void)data;
  if (error) {
    *error = NULL;
  }
  return NULL;
}

CFDictionaryRef SecKeyCopyAttributes(void* key) {
  (void)key;
  return NULL;
}

CFDataRef SecKeyCopyExternalRepresentation(void* key, CFErrorRef* error) {
  (void)key;
  if (error) {
    *error = NULL;
  }
  return NULL;
}

/* ---- Metal.framework (absent on 10.9) ----
 * Returns nil (no Metal devices) so wgpu finds no Metal adapter. */
void* MTLCopyAllDevices(void) { return NULL; }

/* ---- CoreMIDI MIDIInputPortCreateWithBlock (macOS 10.11+) ----
 * MIDIClientRef/MIDIPortRef are UInt32; the read block is a pointer. Returns
 * kMIDIUnknownError (-10840) so no input port is created. */
int MIDIInputPortCreateWithBlock(unsigned int client, const void* portName,
                                 unsigned int* outPort, const void* readBlock) {
  (void)client;
  (void)portName;
  (void)readBlock;
  if (outPort) {
    *outPort = 0;
  }
  return -10840;
}

/* ---- sendmsg_x / recvmsg_x (macOS 10.10+ batch UDP syscalls) ----
 * Return ENOSYS so neqo's Apple-fast-datapath probe reports unavailable and the
 * ordinary sendmsg/recvmsg path is used. */
ssize_t sendmsg_x(int s, const void* msgp, unsigned int cnt, int flags) {
  (void)s;
  (void)msgp;
  (void)cnt;
  (void)flags;
  errno = ENOSYS;
  return -1;
}

ssize_t recvmsg_x(int s, void* msgp, unsigned int cnt, int flags) {
  (void)s;
  (void)msgp;
  (void)cnt;
  (void)flags;
  errno = ENOSYS;
  return -1;
}
