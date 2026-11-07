// FlexCommitTest - does writing MSR_FLEX_RATIO make the PCU pick up MSR_TURBO_RATIO_LIMIT at
// runtime? (2026-11-07, see ../flashprobe/README.md) Apple's power management DXE (F7731B4C) with
// m0bil's policy patch writes FLEX_RATIO (OC extra voltage, 7:0) and then 0x1AD before handoff;
// at runtime 0x1AD alone is ignored (PERF_CTL 32, granted 28). Run under a 4-core load:
//   1. sample the real ratio of every core (APERF/MPERF), 0x1AD must already be SNBTurbo's 0x20202425
//   2. write FLEX_RATIO with the value just read (no bit changes) on every core, sample
//   3. write 0x1AD = factory 0x1c202425 + FLEX_RATIO again, sample (end state = factory)
// No new bits are ever set: FLEX_RATIO gets its own value back, 0x1AD ends at the factory value.
#include <mach/mach_types.h>
#include <mach/kmod.h>
#include <libkern/libkern.h>
#include <sys/systm.h>

extern int rdmsr_carefully(uint32_t msr, uint32_t *lo, uint32_t *hi);
extern void mp_rendezvous_no_intrs(void (*action)(void *), void *arg);
extern int cpu_number(void);
extern void IOSleep(unsigned milliseconds);

enum { kMaxCPU = 16, kSamples = 6 };
static const uint64_t kRaised = 0x20202425ULL, kFactory = 0x1c202425ULL;
static uint64_t gA[kMaxCPU], gM[kMaxCPU], gPA[kMaxCPU], gPM[kMaxCPU], gFlex;
static volatile int gSeen[kMaxCPU];

static inline void wrmsr64(uint32_t msr, uint64_t v) {
    __asm__ volatile("wrmsr" : : "c"(msr), "a"((uint32_t)v), "d"((uint32_t)(v >> 32)));
}
static uint64_t rd(uint32_t msr) { uint32_t lo = 0, hi = 0; return rdmsr_carefully(msr, &lo, &hi) ? ~0ULL : ((uint64_t)hi << 32) | lo; }

static void readCore(void *arg) {
    (void)arg;
    int c = cpu_number();
    if (c < 0 || c >= kMaxCPU) return;
    gA[c] = rd(0xE8); gM[c] = rd(0xE7); gSeen[c] = 1;
}
static void writeFlex(void *arg) { (void)arg; wrmsr64(0x194, gFlex); }

static void sample(const char *phase) {
    for (int s = 0; s < kSamples; s++) {
        for (int c = 0; c < kMaxCPU; c++) gSeen[c] = 0;
        mp_rendezvous_no_intrs(readCore, NULL);
        for (int c = 0; c < kMaxCPU; c++) {
            if (!gSeen[c]) continue;
            uint64_t da = gA[c] - gPA[c], dm = gM[c] - gPM[c], r = s && dm ? 2700 * da / dm : 0;
            if (s && (c & 1) == 0) printf("flexcommit: %s s%d cpu%d avg-ratio=%llu.%02llu\n", phase, s, c, r / 100, r % 100);
            gPA[c] = gA[c]; gPM[c] = gM[c];
        }
        IOSleep(250);
    }
}

kern_return_t flexcommit_start(kmod_info_t *ki, void *d) {
    (void)ki; (void)d;
    uint64_t trl = rd(0x1AD);
    gFlex = rd(0x194);
    printf("flexcommit: 0x1AD=0x%llx FLEX_RATIO=0x%llx\n", trl, gFlex);
    if (trl != kRaised || gFlex == ~0ULL || (gFlex >> 20) & 1) { printf("flexcommit: unexpected state - no write\n"); return KERN_SUCCESS; }
    sample("before");
    mp_rendezvous_no_intrs(writeFlex, NULL);
    printf("flexcommit: FLEX_RATIO rewritten, reads 0x%llx, 0x1AD 0x%llx\n", rd(0x194), rd(0x1AD));
    IOSleep(100);
    sample("flex-rewritten");
    wrmsr64(0x1AD, kFactory);
    mp_rendezvous_no_intrs(writeFlex, NULL);
    printf("flexcommit: 0x1AD factory + FLEX rewritten, reads 0x%llx\n", rd(0x1AD));
    IOSleep(100);
    sample("factory");
    return KERN_SUCCESS;
}
kern_return_t flexcommit_stop(kmod_info_t *ki, void *d) { (void)ki; (void)d; return KERN_SUCCESS; }

KMOD_EXPLICIT_DECL(com.mac-backport.flexcommittest, "1.0.0", flexcommit_start, flexcommit_stop)
__private_extern__ kmod_start_func_t *_realmain = flexcommit_start;
__private_extern__ kmod_stop_func_t *_antimain = flexcommit_stop;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
