// add_strong_new_delete: lets the 10.9 dyld bind libc++ to the executable's operator new/delete.
//
// claude (Bun) exports its own operator new/delete (mimalloc). Since macOS 12, dyld routes every
// image's new/delete to such an override through libc++abi's __lcxx_override section; the 10.9
// dyld does not know that section and coalesces only symbols an image lists in its weak-bind info.
// The executable lists none, so libc++.1.dylib keeps libc++abi's new/delete (system malloc): an
// object the executable allocates and libc++ deletes - std::thread's __thread_struct, deleted at
// thread exit - is freed with the wrong allocator ("pointer being freed was not allocated",
// SIGABRT at every exit of the built-in ugrep, 2026-11-10).
//
// The fix is what ld64 emits for an executable that overrides operator new: a weak-bind entry
// "non-weak definition" per replaced function. Sorted by name (dyld merges the images' lists),
// appended at the end of __LINKEDIT, where the patched binary's bind info already ends.
//
// usage: add_strong_new_delete <mach-o>   (in place; refuses a binary that has weak-bind info)
#include <mach-o/loader.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint8_t *buf;
static size_t len;
static char **names;
static size_t nnames;

static void die(const char *m) { fprintf(stderr, "add_strong_new_delete: %s\n", m); exit(1); }

static uint64_t uleb(const uint8_t **p, const uint8_t *end) {
    uint64_t r = 0; int s = 0;
    while (*p < end) { uint8_t b = *(*p)++; r |= (uint64_t)(b & 0x7f) << s; s += 7; if (!(b & 0x80)) return r; }
    die("truncated export trie");
    return 0;
}

// the C++ replaceable allocation functions: operator new/new[]/delete/delete[] and their variants
static int replaceable(const char *n) {
    return !strncmp(n, "__Znw", 5) || !strncmp(n, "__Zna", 5) || !strncmp(n, "__Zdl", 5) || !strncmp(n, "__Zda", 5);
}

static void walk(const uint8_t *trie, size_t size, size_t node, char *prefix, size_t plen, int depth) {
    if (node >= size || depth > 512) die("bad export trie");
    const uint8_t *p = trie + node, *end = trie + size;
    uint64_t info = uleb(&p, end);
    if (info && replaceable(prefix)) {
        names = realloc(names, (nnames + 1) * sizeof *names);
        names[nnames++] = strdup(prefix);
    }
    p += info;
    if (p >= end) die("bad export trie");
    uint8_t children = *p++;
    for (int i = 0; i < children; i++) {
        size_t l = strnlen((const char *)p, end - p);
        if (p + l >= end || plen + l >= 4096) die("bad export trie");
        memcpy(prefix + plen, p, l + 1);
        p += l + 1;
        walk(trie, size, uleb(&p, end), prefix, plen + l, depth + 1);
    }
}

static int cmp(const void *a, const void *b) { return strcmp(*(char *const *)a, *(char *const *)b); }

int main(int argc, char **argv) {
    if (argc != 2) die("usage: add_strong_new_delete <mach-o>");
    FILE *f = fopen(argv[1], "rb");
    if (!f) die("cannot open");
    fseek(f, 0, SEEK_END); len = ftell(f); fseek(f, 0, SEEK_SET);
    buf = malloc(len + 65536);
    if (fread(buf, 1, len, f) != len) die("cannot read");
    fclose(f);

    struct mach_header_64 *h = (struct mach_header_64 *)buf;
    if (h->magic != MH_MAGIC_64) die("not a 64-bit Mach-O");
    if (!(h->flags & MH_WEAK_DEFINES) || !(h->flags & MH_BINDS_TO_WEAK)) die("image does not take part in coalescing");
    struct dyld_info_command *di = NULL;
    struct segment_command_64 *le = NULL;
    uint8_t *lc = buf + sizeof *h;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        struct load_command *c = (struct load_command *)lc;
        if (c->cmd == LC_DYLD_INFO || c->cmd == LC_DYLD_INFO_ONLY) di = (struct dyld_info_command *)c;
        if (c->cmd == LC_SEGMENT_64 && !strcmp(((struct segment_command_64 *)c)->segname, "__LINKEDIT")) le = (struct segment_command_64 *)c;
        lc += c->cmdsize;
    }
    if (!di || !le) die("no dyld info or __LINKEDIT");
    if (di->weak_bind_size) die("weak-bind info present already (applied twice?)");
    if (le->fileoff + le->filesize != len) die("__LINKEDIT does not end the file");

    char prefix[4096] = "";
    walk(buf + di->export_off, di->export_size, 0, prefix, 0, 0);
    if (!nnames) die("no operator new/delete exported");
    qsort(names, nnames, sizeof *names, cmp);

    size_t off = (len + 7) & ~(size_t)7, p = off;
    memset(buf + len, 0, off - len);
    for (size_t i = 0; i < nnames; i++) {
        size_t l = strlen(names[i]) + 1;
        if (p + 1 + l + 8 > len + 65536) die("too many names");
        buf[p++] = BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM | BIND_SYMBOL_FLAGS_NON_WEAK_DEFINITION;
        memcpy(buf + p, names[i], l); p += l;
        printf("strong definition: %s\n", names[i]);
    }
    buf[p++] = BIND_OPCODE_DONE;
    while (p & 7) buf[p++] = 0;

    di->weak_bind_off = (uint32_t)off;
    di->weak_bind_size = (uint32_t)(p - off);
    le->filesize = p - le->fileoff;
    if (le->vmsize < le->filesize) le->vmsize = (le->filesize + 0xfff) & ~(uint64_t)0xfff;   // the last segment: room to grow

    f = fopen(argv[1], "wb");
    if (!f || fwrite(buf, 1, p, f) != p || fclose(f)) die("cannot write");
    return 0;
}
