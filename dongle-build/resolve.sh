set -e
cd /k/merge
python3 - <<'P'
import re
pat=re.compile(r'<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n',re.S)
for f in open('/k/conflicts.txt').read().split():
    s=open(f).read(); s2=pat.sub(lambda m:m.group(2),s)   # .c files only (not built here): take 3.18.24's side
    assert f.endswith('.c') or 'arm64' in f, f
    assert '<<<<<<<' not in s2; open(f,'w').write(s2)
# Vendor (Telechips/Mobis) differences seen in the stock modules' DWARF, so shared structs match byte for byte
def sub(f, a, b, n=1):
    s=open(f).read(); assert s.count(a)==n, (f, a, s.count(a)); open(f,'w').write(s.replace(a,b))
sub('include/linux/mm_types.h', 'u32 vmacache_seqnum;', 'u64 vmacache_seqnum;')
sub('include/linux/sched.h', 'u32 vmacache_seqnum;', 'u64 vmacache_seqnum;')
sub('include/linux/fs.h', '\tint (*show_fdinfo)(struct seq_file *m, struct file *f);', '\tint (*iterate_avn) (struct file *, struct dir_context *);\n\tint (*show_fdinfo)(struct seq_file *m, struct file *f);')
sub('include/uapi/linux/snmp.h', '\t__LINUX_MIB_MAX\n', '\tLINUX_MIB_K8_VENDOR_PAD,\n\t__LINUX_MIB_MAX\n')
P
rm -rf /k/linux2 && mkdir /k/linux2 && tar -C /k/merge --exclude=.git -cf - . | tar -C /k/linux2 -xf -
