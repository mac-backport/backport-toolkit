# FlashProbe + firmware analysis tools (iMac12,x, Boot ROM 87.0.0)

FlashProbe (flashprobe.c) - read-only kext: logs the PCH SPI controller state (HSFS/FLOCKDN,
FRAP, FREG0-4, PR0-4) and copies the memory-mapped BIOS region of the SPI flash into a kernel
buffer, exported as `sysctl debug.flashprobe.rom` (+ `.base` = flash offset). Plain uncached MMIO
reads (SPIBAR = RCBA 0xFED1C000 + 0x3800, RCBA from the DSDT `SRCB`); no SPI cycle, nothing written.

Build like ../msrprobe (clang -mkernel, link with ld -kext), then:

    sudo kextload FlashProbe.kext           # root:wheel copy
    syslog -k Sender kernel | grep flashprobe
    sysctl -b debug.flashprobe.rom > bios-region.bin
    sudo kextunload -b com.mac-backport.flashprobe

The dump contains the NVRAM store (serial, hardware UUID, boot variables) - never publish it.

tools/: `efidecomp.py` (EFI/Tiano decompressor, EDK2 port; pbit 5 = Tiano, which Apple uses),
`ffswalk.py <dump> <outdir>` (walks all FVs, decompresses sections, writes every PE32/TE image as
`<FILE-GUID>_<filetype>_<sectiontype>.efi`). Disassemble with `llvm-objdump -d`.

## Result 2026-11-07 (iMac12,2, i5-2500S, Boot ROM 87.0.0)

Flash protection (read after a normal boot):
- HSFS 0xe008: FLOCKDN = 1 (PR registers locked until reset), descriptor valid.
- FRAP 0x0000ffff: host may read and write every region (descriptor, ME, BIOS).
- PR0 0x181000-0x6d7fff WP, PR1 0x6fc000-end WP -> whole BIOS region write-protected except the
  hole 0x6d8000-0x6fbfff (NVRAM). Descriptor and ME are not covered (matches m0bil's notes).
- So the BIOS region cannot be flashed from the OS without the flash-protection-bypass patch
  (which itself needs one external SPI programming) or an S3 lock bug (open: re-check after wake).

Turbo overclocking path (m0bil, github.com/m0bil/imac-uefi-patches, turbo-overclocking):
- `A4F2909C-...` (DXE, PPM policy provider): both patch patterns occur exactly once in 87.0.0.
  Patch 1 replaces a SetMem(ratios, size, 0) with `mov dword [rcx], 0xRRRRRRRR` (per-core-count
  max ratios); patch 2 turns `and byte [flags+1], 0xFE` into `or byte [flags+2], 1` = turbo
  ratio programming enable.
- `F7731B4C-...` (DXE, power management) at 0x100027dc: if flags byte 2 bit 0 is set and
  PLATFORM_INFO bit 28 (ratio limit programmable) and FLEX_RATIO OC bins (19:17) != 0, it clamps
  the policy ratios to factory + OC bins, writes FLEX_RATIO[7:0] (OC extra voltage) and then
  MSR_TURBO_RATIO_LIMIT (0x1AD) per core count. Patch 3 makes its S3 save/restore list keep 0x1AD
  instead of ENERGY_PERF_BIAS.
- Same values our runtime kext (SNBTurbo) wrote, yet at runtime the PCU kept granting the factory
  bins - the difference is when it happens (DXE, before the firmware hands off) or the FLEX_RATIO
  write; see ../msrprobe/README.md for the runtime measurements.
- `1BA0062E-...` (PEIM, TE) also writes FLEX_RATIO (early CPU init).

FlexCommitTest (../msrprobe/flexcommit.c), 2026-11-07, 4-core load, 0x1AD = 0x20202425 (SNBTurbo),
PERF_CTL 32: FLEX_RATIO = 0x80000 (OC bins 4, not locked). Rewriting FLEX_RATIO on every core with
its own value -> real ratio stays 28.00; 0x1AD back to factory + FLEX rewrite -> 28.00. So the
FLEX_RATIO write is not what makes the firmware path work. Remaining explanation: the PCU takes the
turbo table only before the firmware's BIOS_RESET_CPL handshake (MCHBAR 0x5DA8 bit 0, set by the
SA init DXE DE23ACEE-...) - i.e. only firmware code (m0bil's patch / an NVRAM-driven module) can
raise it. Flashing needs the one-time external programming (flash-protection-bypass) first.
