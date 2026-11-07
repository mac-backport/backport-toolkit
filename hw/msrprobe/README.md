# MSRProbe, MSRLowerTest

MSRLowerTest (lowertest.c): lowers the 4-core turbo bin in MSR_TURBO_RATIO_LIMIT to 26, samples the
real ratio of every core (APERF/MPERF), writes the previous value back - all inside start, nothing
left changed. Writes only if 0x1AD holds a known value. Built like MSRProbe.

MSRProbe - read-only kext: on load it reads the MSRs that decide the CPU clock (per core: PERF_CTL, PERF_STATUS,
MISC_ENABLE, ENERGY_PERF_BIAS; package: PLATFORM_INFO, FLEX_RATIO, TURBO_RATIO_LIMIT, power and
current limits, energy counters) on every core, eight times 250 ms apart, logs them to the kernel
log (`msrprobe: ...`) and does nothing else (`rdmsr_carefully` only, no write).

Build (no Xcode; clang's config adds -rpath, which a kext link refuses - link with ld):

    K=/System/Library/Frameworks/Kernel.framework/Headers
    clang -arch x86_64 -mkernel -nostdlib -fno-builtin -fno-common -mmacosx-version-min=10.9 \
          -DKERNEL -DKERNEL_PRIVATE -I$K -Wall -c msrprobe.c -o msrprobe.o
    ld -arch x86_64 -kext -macosx_version_min 10.9 msrprobe.o -L/usr/lib -lkmod \
       -o MSRProbe.kext/Contents/MacOS/MSRProbe

Use: copy the kext to a root-owned place (`chown -R root:wheel`), start the load to examine,
`sudo kextload`, `sudo kextunload -b com.mac-backport.msrprobe`, then
`syslog -k Sender kernel | grep msrprobe`. Unsigned: a warning on 10.9 when loaded by hand.

## Result 2026-11-07 (iMac12,2, i5-2500S)

Question: SNBTurbo set the 4-core turbo bin 28 -> 32 at boot (before AppleIntelCPUPowerManagement),
yet all cores stayed at 2.8 GHz under 4-core load.

- PERF_CTL on all cores = ratio 32: macOS requests the raised bin.
- PERF_STATUS on all cores = ratio 28: the CPU grants the factory 4-core bin - in every sample.
- Not a power or current limit: PKG_POWER_LIMIT PL1 65 W / PL2 81 W, measured ~35 W (energy
  counter); VR_CURRENT_CONFIG 97.5 A, unlocked; PP0 limit 0. Turbo enabled (MISC_ENABLE bit 38 = 0).
- PLATFORM_INFO bit 28 = 1 (ratio limit programmable), FLEX_RATIO 4 OC bins, not locked;
  TURBO_RATIO_LIMIT reads back 0x20202425.

Second round (same evening, more MSRs):
- Chipset: LPC bridge 8086:1C44 = Z68 (supports CPU overclocking) - not the cause.
- Real ratio from APERF/MPERF (250 ms averages, so not skewed by the sampling IPI): 4 cores busy =
  exactly 28.00 on every core; 1-3 busy = 29.5-36 (turbo works; the background keeps a 4th core
  waking). Limit reasons in IA32_THERM_STATUS / PACKAGE_THERM_STATUS: none (no thermal, power,
  current or cross-domain limit); 59 C, 27 K below TjMax 86 C.
- MSRLowerTest under 4-core load: 0x1AD written 0x1a202425 (4-core bin 26), read back correctly, then
  restored - the clock stayed at exactly 28.00. The CPU does not apply 0x1AD at runtime at all, not
  even downwards: it uses the turbo table it latched at reset.

Conclusion: no software in the running OS can change the turbo bins on this machine - SNBTurbo's
boot-time write (after the reset) is as ineffective as a runtime write. Board firmware applies such
settings with a warm reset after writing them; that would take code in the firmware's pre-boot
stage (an EFI driver), which is out of the question on a machine reachable only remotely. SNBTurbo
has no effect and should be removed.

FlexCommitTest (flexcommit.c): under 4-core load rewrites MSR_FLEX_RATIO with its own value after
0x1AD was raised, samples, then sets 0x1AD back to factory. Result: no effect - see
../flashprobe/README.md.
