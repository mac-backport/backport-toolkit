// FlashProbe - read-only look at the iMac12,x SPI flash (PCH 6-series, Z68).
// On load it
//   1. reads the PCH SPI controller registers (SPIBAR = RCBA + 0x3800; RCBA 0xFED1C000 from the
//      DSDT "SRCB") and logs them: HSFS (FLOCKDN = flash config lock-down), FRAP / FREG0-4
//      (region layout + host access), PR0-4 (protected ranges = the write protection);
//   2. copies the memory-mapped BIOS region (flash end is mapped at 4 GiB - 1) into a kernel
//      buffer and exports it read-only as sysctl debug.flashprobe.rom (+ .base = flash offset).
// Nothing is written: plain uncached MMIO reads (IOMappedRead32), no SPI cycle is started
// (HSFC/SSFC untouched). Purpose (2026-11-07): ROM backup + reversing the PPM PEIM for turbo OC,
// and checking whether the flash lock is re-applied after S3 (load again after sleep/wake).
#include <mach/mach_types.h>
#include <mach/kmod.h>
#include <libkern/libkern.h>
#include <sys/systm.h>
#include <sys/errno.h>
#include <sys/sysctl.h>

extern uint32_t IOMappedRead32(uint64_t address);
extern uint16_t IOMappedRead16(uint64_t address);
extern void *IOMalloc(size_t size);
extern void IOFree(void *address, size_t size);

#define SPIBAR 0xFED1F800ULL   // RCBA 0xFED1C000 + 0x3800
#define FLASH_SIZE 0x800000U   // 8 MiB part on iMac12,x
#define FLASH_MAP (0x100000000ULL - FLASH_SIZE)

static uint8_t *gRom;
static uint32_t gRomLen, gRomBase;
static int gRegistered;

static int romHandler(struct sysctl_oid *oidp, void *arg1, int arg2, struct sysctl_req *req) {
    (void)oidp; (void)arg1; (void)arg2;
    if (req->newptr) return EPERM;
    if (!gRom) return ENOENT;
    return SYSCTL_OUT(req, gRom, gRomLen);
}

SYSCTL_NODE(_debug, OID_AUTO, flashprobe, CTLFLAG_RD, 0, "FlashProbe");
SYSCTL_PROC(_debug_flashprobe, OID_AUTO, rom, CTLTYPE_OPAQUE | CTLFLAG_RD | CTLFLAG_LOCKED,
            0, 0, romHandler, "S", "BIOS region of the SPI flash");
SYSCTL_UINT(_debug_flashprobe, OID_AUTO, base, CTLFLAG_RD | CTLFLAG_LOCKED, &gRomBase, 0,
            "flash offset of rom[0]");

static void logRegs(void) {
    uint16_t hsfs = IOMappedRead16(SPIBAR + 0x04);
    printf("flashprobe: HSFS=0x%04x FLOCKDN=%d FDV=%d FDOPSS=%d\n", hsfs, (hsfs >> 15) & 1,
           (hsfs >> 14) & 1, (hsfs >> 13) & 1);
    uint32_t frap = IOMappedRead32(SPIBAR + 0x50);
    printf("flashprobe: FRAP=0x%08x (BMWAG %02x BMRAG %02x BRWA %02x BRRA %02x)\n", frap,
           frap >> 24, (frap >> 16) & 0xff, (frap >> 8) & 0xff, frap & 0xff);
    for (int i = 0; i < 5; i++) {
        uint32_t r = IOMappedRead32(SPIBAR + 0x54 + 4 * i);
        printf("flashprobe: FREG%d=0x%08x base 0x%06x limit 0x%06x\n", i, r, (r & 0x1fff) << 12,
               ((r >> 16) & 0x1fff) << 12 | 0xfff);
    }
    for (int i = 0; i < 5; i++) {
        uint32_t r = IOMappedRead32(SPIBAR + 0x74 + 4 * i);
        printf("flashprobe: PR%d=0x%08x base 0x%06x limit 0x%06x WP=%d RP=%d\n", i, r,
               (r & 0x1fff) << 12, ((r >> 16) & 0x1fff) << 12 | 0xfff, (r >> 31) & 1,
               (r >> 15) & 1);
    }
}

kern_return_t flashprobe_start(kmod_info_t *ki, void *d) {
    (void)ki; (void)d;
    logRegs();
    uint32_t freg1 = IOMappedRead32(SPIBAR + 0x58);   // BIOS region
    uint32_t base = (freg1 & 0x1fff) << 12, limit = ((freg1 >> 16) & 0x1fff) << 12 | 0xfff;
    if (limit != FLASH_SIZE - 1 || base == 0 || base >= limit) {
        printf("flashprobe: unexpected BIOS region 0x%x-0x%x, no ROM copy\n", base, limit);
        return KERN_SUCCESS;
    }
    gRomBase = base;
    gRomLen = limit + 1 - base;
    gRom = IOMalloc(gRomLen);
    if (!gRom) return KERN_FAILURE;
    for (uint32_t o = 0; o < gRomLen; o += 4) {
        uint32_t v = IOMappedRead32(FLASH_MAP + base + o);
        memcpy(gRom + o, &v, 4);
    }
    sysctl_register_oid(&sysctl__debug_flashprobe);
    sysctl_register_oid(&sysctl__debug_flashprobe_rom);
    sysctl_register_oid(&sysctl__debug_flashprobe_base);
    gRegistered = 1;
    printf("flashprobe: copied BIOS region 0x%x-0x%x (%u bytes)\n", base, limit, gRomLen);
    return KERN_SUCCESS;
}

kern_return_t flashprobe_stop(kmod_info_t *ki, void *d) {
    (void)ki; (void)d;
    if (gRegistered) {
        sysctl_unregister_oid(&sysctl__debug_flashprobe_base);
        sysctl_unregister_oid(&sysctl__debug_flashprobe_rom);
        sysctl_unregister_oid(&sysctl__debug_flashprobe);
    }
    if (gRom) IOFree(gRom, gRomLen);
    gRom = 0;
    return KERN_SUCCESS;
}

KMOD_EXPLICIT_DECL(com.mac-backport.flashprobe, "1.0.0", flashprobe_start, flashprobe_stop)
__private_extern__ kmod_start_func_t *_realmain = flashprobe_start;
__private_extern__ kmod_stop_func_t *_antimain = flashprobe_stop;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
