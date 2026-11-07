# EFI 1.1 / Tiano decompressor (port of EDK2 BaseUefiDecompressLib). pbit 4 = EFI, 5 = Tiano.
import struct

class BitReader:
    def __init__(self, data):
        self.d = data; self.pos = 0  # bit position
    def peek(self, n):
        v = 0
        p = self.pos
        for _ in range(n):
            byte = p >> 3
            b = (self.d[byte] >> (7 - (p & 7))) & 1 if byte < len(self.d) else 0
            v = (v << 1) | b; p += 1
        return v
    def get(self, n):
        v = self.peek(n); self.pos += n; return v

def make_table(nchar, bitlen, tablebits):
    # canonical Huffman decode via dict of (len, code) -> symbol; returns decoder function
    count = [0] * 17
    for l in bitlen: count[l] += 1
    count[0] = 0
    start = [0] * 18
    for i in range(1, 17):
        start[i + 1] = (start[i] + (count[i] << (16 - i))) & 0x1FFFF if i < 17 else 0
    # simpler: build code assignment canonically
    code = 0; codes = {}
    nextcode = [0] * 17
    for l in range(1, 17):
        code = (code + count[l - 1]) << 1 if l > 1 else 0
        nextcode[l] = code
    for sym in range(nchar):
        l = bitlen[sym]
        if l:
            codes[(l, nextcode[l])] = sym; nextcode[l] += 1
    return codes

def decode(br, codes, maxlen=16):
    c = 0
    for l in range(1, maxlen + 1):
        c = (c << 1) | br.get(1)
        s = codes.get((l, c))
        if s is not None: return s
    raise ValueError('bad huffman code')

NC = 510; NT = 19; TBIT = 5; CBIT = 9; MAXMATCH = 256; THRESHOLD = 3

def decompress(src, pbit):
    comp, orig = struct.unpack_from('<II', src, 0)
    br = BitReader(src[8:8 + comp])
    np_ = 31   # MAXNP array size; the real count is read from the stream
    out = bytearray()
    blocksize = 0
    cdecode = pdecode = None
    def read_pt_len(nn, nbit, special):
        n = br.get(nbit)
        lens = [0] * nn
        if n == 0:
            c = br.get(nbit)
            return ('const', c)
        i = 0
        while i < n:
            c = br.peek(3)
            if c == 7:
                br.get(3)
                while br.get(1): c += 1
            else:
                br.get(3)
            lens[i] = c; i += 1
            if i == special:
                k = br.get(2)
                for _ in range(k): lens[i] = 0; i += 1
        return ('tab', make_table(nn, lens, 8))
    def read_c_len(tdec):
        n = br.get(CBIT)
        lens = [0] * NC
        if n == 0:
            return ('const', br.get(CBIT))
        i = 0
        while i < n:
            c = tdec_get(tdec)
            if c <= 2:
                if c == 0: k = 1
                elif c == 1: k = br.get(4) + 3
                else: k = br.get(CBIT) + 20
                for _ in range(k): lens[i] = 0; i += 1
            else:
                lens[i] = c - 2; i += 1
        return ('tab', make_table(NC, lens, 12))
    def tdec_get(t):
        return t[1] if t[0] == 'const' else decode(br, t[1])
    while len(out) < orig:
        if blocksize == 0:
            blocksize = br.get(16)
            tdec = read_pt_len(NT, TBIT, 3)
            cdecode = read_c_len(tdec)
            pdecode = read_pt_len(np_, pbit, -1)
        blocksize -= 1
        c = tdec_get(cdecode)
        if c < 256:
            out.append(c)
        else:
            length = c - (256 - THRESHOLD)
            p = tdec_get(pdecode)
            if p > 1:
                p = (1 << (p - 1)) + br.get(p - 1)
            pos = len(out) - p - 1
            for k in range(length):
                out.append(out[pos + k])
    return bytes(out[:orig])
