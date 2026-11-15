#!/usr/bin/env python3
"""For each kernel symbol the driver imports, check the compiled function body appears in the car's Image.
match_imports.py <Image> <imports.txt> <objs...>"""
import sys
src = open(__file__.replace('match_imports.py', 'match_image.py')).read().split("img = open(sys.argv[1]")[0]
exec(src)
img = open(sys.argv[1], 'rb').read()
want = set(open(sys.argv[2]).read().split())
res = {}
for p in sys.argv[3:]:
    for fn, code, masks in funcs(p):
        if fn not in want or res.get(fn) is True: continue
        ok, d = match(img, code, masks)
        if ok: res[fn] = True
        else: res.setdefault(fn, (ok, d, len(code), p.split('/')[-1]))
good = sorted(k for k, v in res.items() if v is True)
bad = sorted((k, v) for k, v in res.items() if v is not True)
print('imported functions checked:', len(res), 'identical in car kernel:', len(good))
for k, v in bad: print('  NOT IDENTICAL', k, 'closest_diff_words=%s size=%d obj=%s' % (v[1], v[2], v[3]))
print('not checked (inline/data/asm or <16 bytes):', ' '.join(sorted(want - set(res))))
