#!/usr/bin/env python3
"""Find functions compiled from the reconstructed kernel tree inside the car's kernel Image.
A function that appears byte for byte (relocation fields masked) proves the structs it touches
have the same layout in the car's kernel.  match_image.py <Image> <obj>... [-v]"""
import sys
from collections import defaultdict
from elftools.elf.elffile import ELFFile

MASK = {2: 0xffffffff, 3: 0xffffffff, 42: 0xffffffff, 28: 0x00ffffff, 29: 0x00ffffff, 1: 0x00ffffff,
        43: 0x000f0fff, 44: 0x000f0fff, 40: 0}   # ABS32 REL32 PREL31 CALL JUMP24 PC24 MOVW MOVT V4BX

def funcs(path):
    f = ELFFile(open(path, 'rb'))
    symtab = f.get_section_by_name('.symtab')
    for si, sec in enumerate(f.iter_sections()):
        if not sec.name.startswith('.text') or sec['sh_size'] == 0: continue
        data = sec.data()
        rel = f.get_section_by_name('.rel' + sec.name)
        masks = {}
        if rel:
            for r in rel.iter_relocations():
                t = r['r_info_type']
                if t not in MASK: masks[r['r_offset']] = None
                else: masks[r['r_offset']] = MASK[t]
        for s in symtab.iter_symbols():
            if s['st_info']['type'] != 'STT_FUNC' or s['st_shndx'] != si or s['st_size'] < 16: continue
            a = s['st_value'] & ~1; n = s['st_size']
            yield s.name, data[a:a+n], {o - a: m for o, m in masks.items() if a <= o < a + n}

def match(img, code, masks):
    n = len(code) // 4
    words = [int.from_bytes(code[i*4:i*4+4], 'little') for i in range(n)]
    keep = [0xffffffff ^ masks.get(i*4, 0) if masks.get(i*4, 0) is not None else 0 for i in range(n)]
    # anchor: longest run of fully fixed words
    best = (0, 0); i = 0
    while i < n:
        j = i
        while j < n and keep[j] == 0xffffffff: j += 1
        if j - i > best[1]: best = (i, j - i)
        i = j + 1
    if best[1] < 3: return None, 0
    anc = code[best[0]*4:(best[0]+best[1])*4]
    pos = -1; bestdiff = None
    while True:
        pos = img.find(anc, pos + 1)
        if pos < 0: break
        st = pos - best[0]*4
        if st < 0 or st % 4: continue
        d = 0
        for k in range(n):
            w = int.from_bytes(img[st+k*4:st+k*4+4], 'little')
            if (w ^ words[k]) & keep[k]: d += 1
        if d == 0: return True, 0
        if bestdiff is None or d < bestdiff: bestdiff = d
    return False, bestdiff

img = open(sys.argv[1], 'rb').read()
verbose = '-v' in sys.argv
tot = defaultdict(lambda: [0, 0, 0])
for p in [a for a in sys.argv[2:] if a != '-v']:
    name = p.split('/')[-1]
    for fn, code, masks in funcs(p):
        ok, d = match(img, code, masks)
        t = tot[name]
        if ok is None: t[2] += 1
        elif ok: t[0] += 1
        else:
            t[1] += 1
            if verbose: print('  MISS %s:%s size=%d closest_diff_words=%s' % (name, fn, len(code), d))
for k in sorted(tot):
    print('%-48s match %3d  miss %3d  skipped %3d' % (k, *tot[k]))
a = sum(v[0] for v in tot.values()); b = sum(v[1] for v in tot.values())
print('TOTAL match %d miss %d (%.1f%%)' % (a, b, 100.0*a/max(1, a+b)))
