// MSRProbe - read-only diagnosis of the CPU's turbo state (iMac12,2, i5-2500S, Sandy Bridge).
// On load it reads, on every core at once (mp_rendezvous_no_intrs), the MSRs that decide the clock
// under load, eight times 250 ms apart, logs them to the kernel log ("msrprobe: ...") and does
// nothing else: rdmsr_carefully only (a missing MSR returns an error instead of a #GP), no write.
// Use: start a 4-core load, kextload, read the log, kextunload. Question it answers (2026-11-07):
// SNBTurbo sets the 4-core turbo bin 28 -> 32 before AppleIntelCPUPowerManagement, the MSR reads
// back 32, yet all cores stay at 2.8 GHz under 4-core load - what is requested, what is granted?
#include <mach/mach_types.h>
#include <mach/kmod.h>
#include <libkern/libkern.h>
#include <sys/systm.h>

extern int rdmsr_carefully(uint32_t msr, uint32_t *lo, uint32_t *hi);
extern void mp_rendezvous_no_intrs(void (*action)(void *), void *arg);
extern int cpu_number(void);
extern void IODelay(unsigned microseconds);
extern void IOSleep(unsigned milliseconds);

enum { kMaxCPU = 16, kSamples = 8 };

// per core: the request and the grant
static const uint32_t kPerCore[] = {
    0x199,   // IA32_PERF_CTL: ratio requested by the OS (bits 15:8), bit 32 = turbo disengage
    0x198,   // IA32_PERF_STATUS: current ratio (bits 15:8)
    0x1A0,   // IA32_MISC_ENABLE: bit 38 = turbo disabled
    0x1B0,   // IA32_ENERGY_PERF_BIAS
    0x19C,   // IA32_THERM_STATUS: limit reasons - bit 0 thermal, 10/11 power limitation status/log,
             // 12/13 current limit status/log, 14/15 cross-domain limit status/log; 22:16 degrees below TjMax
    0xE8,    // IA32_APERF: actual clocks (with MPERF: the real average frequency between samples)
    0xE7,    // IA32_MPERF: clocks at the max non-turbo ratio
};
// package-wide, read once
static const uint32_t kPackage[] = {
    0xCE,    // MSR_PLATFORM_INFO: max non-turbo ratio 15:8, bit 28 = turbo ratio limit programmable
    0x194,   // MSR_FLEX_RATIO: OC bins 19:17, lock bit 20
    0x1AD,   // MSR_TURBO_RATIO_LIMIT: 1/2/3/4-core bins
    0x610,   // MSR_PKG_POWER_LIMIT: PL1/PL2
    0x606,   // MSR_RAPL_POWER_UNIT
    0x1FC,   // MSR_POWER_CTL
    0xE2,    // MSR_PKG_CST_CONFIG_CONTROL
    0x64C,   // MSR_TURBO_ACTIVATION_RATIO (Ivy Bridge+; expected to fail on SNB)
    0x601,   // MSR_VR_CURRENT_CONFIG: core current limit (IccMax), 1/8 A in bits 12:0, lock bit 31
    0x603,   // MSR_VR_MISC_CONFIG
    0x638,   // MSR_PP0_POWER_LIMIT: cores-only power limit
    0x63A,   // MSR_PP0_POLICY
    0x611,   // MSR_PKG_ENERGY_STATUS: energy counter (units from 0x606)
    0x639,   // MSR_PP0_ENERGY_STATUS
    0x1B1,   // IA32_PACKAGE_THERM_STATUS: package limit reasons (same bit layout as 0x19C)
    0x1A2,   // MSR_TEMPERATURE_TARGET: TjMax 23:16
};
#define N(a) (sizeof(a) / sizeof((a)[0]))

static uint64_t gVal[kMaxCPU][N(kPerCore)], gPrev[kMaxCPU][N(kPerCore)];
static int gOK[kMaxCPU][N(kPerCore)];
static volatile int gSeen[kMaxCPU];

static void readCore(void *arg) {
    (void)arg;
    int c = cpu_number();
    if (c < 0 || c >= kMaxCPU) return;
    for (unsigned i = 0; i < N(kPerCore); i++) {
        uint32_t lo = 0, hi = 0;
        gOK[c][i] = rdmsr_carefully(kPerCore[i], &lo, &hi) == 0;
        gVal[c][i] = ((uint64_t)hi << 32) | lo;
    }
    gSeen[c] = 1;
}

kern_return_t msrprobe_start(kmod_info_t *ki, void *d) {
    (void)ki; (void)d;
    for (unsigned i = 0; i < N(kPackage); i++) {
        uint32_t lo = 0, hi = 0;
        if (rdmsr_carefully(kPackage[i], &lo, &hi) == 0) printf("msrprobe: pkg 0x%x = 0x%08x%08x\n", kPackage[i], hi, lo);
        else printf("msrprobe: pkg 0x%x = (not readable)\n", kPackage[i]);
    }
    for (int s = 0; s < kSamples; s++) {
        for (int c = 0; c < kMaxCPU; c++) gSeen[c] = 0;
        mp_rendezvous_no_intrs(readCore, NULL);
        for (int c = 0; c < kMaxCPU; c++) {
            if (!gSeen[c]) continue;
            uint64_t th = gVal[c][4];
            uint64_t da = gVal[c][5] - gPrev[c][5], dm = gVal[c][6] - gPrev[c][6];
            // real average ratio since the previous sample: 27 (max non-turbo) x APERF/MPERF, x100
            uint64_t ratio100 = s && dm ? 2700 * da / dm : 0;
            printf("msrprobe: s%d cpu%d avg-ratio=%llu.%02llu therm=0x%llx [%s%s%s%s] below-tjmax=%llu\n", s, c,
                   ratio100 / 100, ratio100 % 100, th,
                   th & 1 ? "THERMAL " : "", (th >> 10) & 1 ? "POWER-LIMIT " : "", (th >> 12) & 1 ? "CURRENT-LIMIT " : "",
                   (th >> 14) & 1 ? "CROSS-DOMAIN " : "", (th >> 16) & 0x7f);
            for (unsigned i = 0; i < N(kPerCore); i++) gPrev[c][i] = gVal[c][i];
            printf("msrprobe: s%d cpu%d ctl=0x%llx(ratio %llu%s) status=0x%llx(ratio %llu) misc=0x%llx(turbo %s) epb=%llu\n", s, c,
                   gVal[c][0], (gVal[c][0] >> 8) & 0xff, (gVal[c][0] >> 32) & 1 ? ", disengage" : "",
                   gVal[c][1], (gVal[c][1] >> 8) & 0xff,
                   gVal[c][2], (gVal[c][2] >> 38) & 1 ? "DISABLED" : "enabled", gVal[c][3] & 0xf);
        }
        IOSleep(250);
    }
    return KERN_SUCCESS;
}

kern_return_t msrprobe_stop(kmod_info_t *ki, void *d) { (void)ki; (void)d; return KERN_SUCCESS; }

KMOD_EXPLICIT_DECL(com.mac-backport.msrprobe, "1.0.0", msrprobe_start, msrprobe_stop)
__private_extern__ kmod_start_func_t *_realmain = msrprobe_start;
__private_extern__ kmod_stop_func_t *_antimain = msrprobe_stop;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
