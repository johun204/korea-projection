set -e
export ARCH=arm CROSS_COMPILE=/opt/gcc47/bin/arm-linux-androideabi-
cd $KDIR
for i in $(seq 1 40); do
  if make -j4 KCFLAGS=-fno-pic $OBJDIRS > /k/objs.log 2>&1; then echo "passes $i"; break; fi
  grep -q "Segmentation fault" /k/objs.log || { grep -E "error|Error" /k/objs.log | head -20; exit 1; }
done
rm -rf /w/kbuild/objs && mkdir -p /w/kbuild/objs
for d in $OBJDIRS; do for o in $(find $d -name '*.o' ! -name 'built-in.o' ! -name '*.mod.o'); do cp $o /w/kbuild/objs/$(echo $o | tr / _); done; done
ls /w/kbuild/objs | wc -l
