set -e
export ARCH=arm CROSS_COMPILE=/opt/gcc47/bin/arm-linux-androideabi-
rm -rf /k/drv && cp -r /w/kbuild/88x2bu-20210702 /k/drv && cd /k/drv
[ -f /w/kbuild/drv.patch ] && patch -p1 < /w/kbuild/drv.patch
sed -i "s/^ldflags-y += --strip-debug/#&/" Makefile   # keep DWARF for the layout check; stripped when packaged
# the old assembler crashes at random under Rosetta: retry until the build completes
ok=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  if make -j4 KSRC=${KDIR:-/k/linux} KVER=3.18.24-tcc USER_EXTRA_CFLAGS="-fno-pic $DRVCFLAGS" $DRVOPTS > /k/drv.log 2>&1; then ok=1; break; fi
  grep -q "Segmentation fault" /k/drv.log || break
done
echo "make passes: $i"
[ $ok = 1 ] || { grep -E "error|Error|undefined" /k/drv.log | head -40; exit 1; }
grep -c warning /k/drv.log || true
ls -la 88x2bu.ko && cp 88x2bu.ko /w/kbuild/${OUT:-88x2bu-debug.ko}
${CROSS_COMPILE}strip --strip-debug -o /w/kbuild/${OUT:-88x2bu-debug.ko}.stripped 88x2bu.ko
grep -E "WARNING|undefined" /k/drv.log | head -20
