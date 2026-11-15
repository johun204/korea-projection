#!/usr/bin/env python3
"""Check a built module against what the car reported: vermagic, exported symbols, struct layouts."""
import sys, json, glob
from elftools.elf.elffile import ELFFile
ko, diag = sys.argv[1], sys.argv[2]
bad = 0
f = ELFFile(open(ko, 'rb'))
mi = f.get_section_by_name('.modinfo').data().split(b'\0')
vm = [x for x in mi if x.startswith(b'vermagic=')][0].decode()
ref = 'vermagic=3.18.24-tcc SMP preempt mod_unload ARMv7 p2v8 '
print('vermagic', 'OK' if vm == ref else 'MISMATCH %r' % vm); bad += vm != ref
# exported symbols: with KALLSYMS_ALL the car's kallsyms lists __ksymtab_<name> for every export
ks = set(l.split()[2] for l in open(diag + '/kallsyms.txt') if len(l.split()) >= 3)
und = [s.name for s in f.get_section_by_name('.symtab').iter_symbols() if s['st_shndx'] == 'SHN_UNDEF' and s.name]
miss = [s for s in und if '__ksymtab_' + s not in ks]
print('undefined symbols', len(und), 'not exported by the car kernel:', miss); bad += len(miss)
# struct layouts vs the stock modules' DWARF
if len(sys.argv) > 3:
    mine = json.load(open(sys.argv[3]))
    seen = same = 0; diff = []
    for p in sorted(glob.glob(diag + '/../layout-*.json')):
        refl = json.load(open(p))
        for n, lay in refl.items():
            if n.startswith('!') or n not in mine: continue
            seen += 1
            if mine[n] == lay: same += 1
            else: diff.append((p.split('layout-')[1], n, lay['size'], mine[n]['size']))
    print('structs shared with stock modules', seen, 'identical', same)
    for d in diff: print('  DIFF', d)
    bad += len(diff)
sys.exit(1 if bad else 0)
