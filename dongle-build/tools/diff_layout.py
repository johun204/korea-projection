#!/usr/bin/env python3
"""Member-level diff of struct layouts: diff_layout.py <ref.json> <mine.json> [struct...]"""
import sys, json
r = json.load(open(sys.argv[1])); m = json.load(open(sys.argv[2]))
names = sys.argv[3:] or sorted(n for n in r if n in m and not n.startswith('!') and r[n] != m[n])
for n in names:
    a, b = r[n], m[n]
    print('==', n, 'car', a['size'], 'mine', b['size'])
    am = [(x[0], x[1]) for x in a['members']]; bm = [(x[0], x[1]) for x in b['members']]
    an = [x[0] for x in am]; bn = [x[0] for x in bm]
    for x in am:
        if x not in bm: print('   car :', x, '' if x[0] in bn else '(only in car)')
    for x in bm:
        if x not in am and x[0] not in an: print('   mine:', x, '(only in mine)')
