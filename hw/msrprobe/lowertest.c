// MSRLowerTest - does the CPU apply MSR_TURBO_RATIO_LIMIT at runtime? (2026-11-07, see README)
// On load: lowers the 4-core bin by writing 0x1AD with byte 3 = 26 (the other bins unchanged),
// samples the real ratio of every core (APERF/MPERF) eight times 250 ms apart, then writes the
// previous value back - all inside start, so nothing is left changed whatever happens after.
// Only a LOWER value: less clock, less power. Runs only if 0x1AD holds the value seen before
// (0x20202425 SNBTurbo's, or the factory 0x1c202425) - anything else: no write.
#include <mach/mach_types.h>
#include <mach/kmod.h>
#include <libkern/libkern.h>
#include <sys/systm.h>

extern int rdmsr_carefully(uint32_t msr, uint32_t *lo, uint32_t *hi);
extern void mp_rendezvous_no_intrs(void (*action)(void *), void *arg);
extern int cpu_number(void);
extern void IOSleep(unsigned milliseconds);

enum { kMaxCPU = 16, kSamples = 8, kTestBin = 26 };
static uint64_t gA[kMaxCPU], gM[kMaxCPU], gPA[kMaxCPU], gPM[kMaxCPU];
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

static void sample(const char *phase) {
    for (int s = 0; s < kSamples; s++) {
        for (int c = 0; c < kMaxCPU; c++) gSeen[c] = 0;
        mp_rendezvous_no_intrs(readCore, NULL);
        for (int c = 0; c < kMaxCPU; c++) {
            if (!gSeen[c]) continue;
            uint64_t da = gA[c] - gPA[c], dm = gM[c] - gPM[c], r = s && dm ? 2700 * da / dm : 0;
            if (s) printf("lowertest: %s s%d cpu%d avg-ratio=%llu.%02llu\n", phase, s, c, r / 100, r % 100);
            gPA[c] = gA[c]; gPM[c] = gM[c];
        }
        IOSleep(250);
    }
}

kern_return_t lowertest_start(kmod_info_t *ki, void *d) {
    (void)ki; (void)d;
    uint64_t old = rd(0x1AD);
    if (old != 0x20202425ULL && old != 0x1c202425ULL) { printf("lowertest: 0x1AD = 0x%llx unexpected - no write\n", old); return KERN_SUCCESS; }
    uint64_t test = (old & ~0xff000000ULL) | ((uint64_t)kTestBin << 24);
    sample("before");
    wrmsr64(0x1AD, test);
    printf("lowertest: wrote 0x%llx (was 0x%llx), reads back 0x%llx\n", test, old, rd(0x1AD));
    IOSleep(100);
    sample("lowered");
    wrmsr64(0x1AD, old);
    printf("lowertest: restored 0x%llx, reads back 0x%llx\n", old, rd(0x1AD));
    return KERN_SUCCESS;
}
kern_return_t lowertest_stop(kmod_info_t *ki, void *d) { (void)ki; (void)d; return KERN_SUCCESS; }

KMOD_EXPLICIT_DECL(com.mac-backport.msrlowertest, "1.0.0", lowertest_start, lowertest_stop)
__private_extern__ kmod_start_func_t *_realmain = lowertest_start;
__private_extern__ kmod_stop_func_t *_antimain = lowertest_stop;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
