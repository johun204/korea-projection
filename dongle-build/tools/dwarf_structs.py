#!/usr/bin/env python3
"""Dump struct/union layouts from a kernel module's DWARF as JSON: {name: {size, members: [[name, offset, bitinfo]]}}."""
import sys, json
from elftools.elf.elffile import ELFFile

def main(path, out):
    f = ELFFile(open(path, 'rb'))
    dw = f.get_dwarf_info(relocate_dwarf_sections=True)
    res = {}
    for cu in dw.iter_CUs():
        for die in cu.iter_DIEs():
            if die.tag not in ('DW_TAG_structure_type', 'DW_TAG_union_type'):
                continue
            a = die.attributes
            if 'DW_AT_name' not in a or 'DW_AT_declaration' in a or 'DW_AT_byte_size' not in a:
                continue
            name = ('union ' if die.tag.endswith('union_type') else '') + a['DW_AT_name'].value.decode()
            mem = []
            for c in die.iter_children():
                if c.tag != 'DW_TAG_member':
                    continue
                ca = c.attributes
                off = ca['DW_AT_data_member_location'].value if 'DW_AT_data_member_location' in ca else 0
                if isinstance(off, list):  # DWARF2 location expr: DW_OP_plus_uconst <uleb>
                    v = 0; sh = 0
                    for b in off[1:]:
                        v |= (b & 0x7f) << sh; sh += 7
                    off = v
                bits = [ca[k].value for k in ('DW_AT_bit_size', 'DW_AT_bit_offset') if k in ca]
                mem.append([ca['DW_AT_name'].value.decode() if 'DW_AT_name' in ca else '', off, bits])
            lay = {'size': a['DW_AT_byte_size'].value, 'members': mem}
            if name in res and res[name] != lay:
                res.setdefault('!conflicts', []).append(name)
            res[name] = lay
    json.dump(res, open(out, 'w'), indent=0, sort_keys=True)
    print(path, len(res), 'types', 'conflicts:', len(set(res.get('!conflicts', []))))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
