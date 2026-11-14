#!/system/bin/sh
# USB Wi-Fi 동글 진단(읽기만 함). NEMESIS type=execute로 root로 돈다.
# 내비의 커널·모듈·USB 정보를 USB의 KP-dongle-diag/run-N 에 모은다. 내비의 파일은 바꾸지 않는다
# (자기 기록 폴더 /data/nemesis/kp-dongle-diag 만 만든다).
#   sh NEMESIS.sh        스냅샷을 USB에 쓰고, USB 장치 감시(15분)를 뒤에 띄운다
#   sh watch.sh watch    감시 본체($ST에 복사된 사본이 돈다. USB를 빼도 살아 있게)
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

ST=/data/nemesis/kp-dongle-diag
KP=/data/nemesis/apps/korea.projection
WATCH_SECS=900

BB=
for b in /system/bin/busybox /system/xbin/busybox $KP/bin/busybox; do
  [ -x $b ] && $b true 2>/dev/null && { BB=$b; break; }
done

# USB 장치 한 줄씩: 이름 VID:PID 속도 클래스 제조사 제품 + 인터페이스별 드라이버
usb_snap() {
  for d in /sys/bus/usb/devices/*; do
    [ -f $d/idVendor ] || continue
    v=; p=; s=; c=; m=; pr=
    read v < $d/idVendor; read p < $d/idProduct
    [ -f $d/speed ] && read s < $d/speed
    [ -f $d/bDeviceClass ] && read c < $d/bDeviceClass
    [ -f $d/manufacturer ] && read m < $d/manufacturer
    [ -f $d/product ] && read pr < $d/product
    echo "${d##*/} $v:$p speed=$s class=$c [$m] [$pr]"
    for i in $d/*:*; do
      [ -d $i ] || continue
      ic=; isc=; ip=
      [ -f $i/bInterfaceClass ] && read ic < $i/bInterfaceClass
      [ -f $i/bInterfaceSubClass ] && read isc < $i/bInterfaceSubClass
      [ -f $i/bInterfaceProtocol ] && read ip < $i/bInterfaceProtocol
      echo "  ${i##*/} if=$ic/$isc/$ip driver: $(ls -l $i/driver 2>/dev/null)"
    done
  done
}
usb_sig() {
  for d in /sys/bus/usb/devices/*; do
    [ -f $d/idVendor ] || continue
    read v < $d/idVendor; read p < $d/idProduct
    echo -n "${d##*/}=$v:$p "
  done
}

if [ "$1" = watch ]; then
  cd /
  echo $$ > $ST/watch.pid
  last=; n=0
  while [ $n -lt $WATCH_SECS ]; do
    sig=$(usb_sig)
    if [ "$sig" != "$last" ]; then
      last=$sig
      { echo "=== +${n}s uptime $(cat /proc/uptime)"; usb_snap; echo "--- net: $(ls /sys/class/net)"; } >> $ST/usb-watch.txt
      sleep 4
      dmesg > $ST/dmesg-watch.txt 2>&1
      n=$((n+4))
    fi
    sleep 2; n=$((n+2))
  done
  dmesg > $ST/dmesg-watch.txt 2>&1
  echo "=== 감시 끝 +${n}s" >> $ST/usb-watch.txt
  rm -f $ST/watch.pid
  exit 0
fi

USB=$(pwd)
mkdir -p $USB/KP-dongle-diag $ST
N=1
while [ -e $USB/KP-dongle-diag/run-$N ]; do N=$((N+1)); done
O=$USB/KP-dongle-diag/run-$N
mkdir -p $O || exit 1

# 앞선 감시를 멈추고 그 기록을 USB로 옮긴다
if [ -f $ST/watch.pid ]; then kill $(cat $ST/watch.pid) 2>/dev/null; rm -f $ST/watch.pid; fi
for f in usb-watch.txt dmesg-watch.txt; do
  [ -f $ST/$f ] && cat $ST/$f > $O/prev-$f && rm -f $ST/$f
done

# 명령 하나의 출력을 제목과 함께
sec() { echo; echo "##### $*"; "$@" 2>&1; }
catf() { for f in "$@"; do echo; echo "##### $f"; cat $f 2>&1; done; }

{
  echo "kp-dongle-diag 1  run-$N  busybox=${BB:-없음}"
  sec id
  sec date
  catf /proc/version /proc/cmdline /proc/sys/kernel/osrelease /proc/sys/kernel/tainted \
       /proc/sys/kernel/modules_disabled /proc/sys/kernel/kptr_restrict \
       /sys/module/module/parameters/sig_enforce /proc/cpuinfo /proc/meminfo /proc/uptime
  [ -n "$BB" ] && sec $BB uname -a
  sec getenforce
  sec lsmod
  catf /proc/modules
  sec ls /sys/module
  sec ls -l /sys/bus/usb/drivers /sys/bus/sdio/drivers
  sec ls -l /sys/class/net /sys/class/ieee80211 /sys/class/rfkill
  catf /proc/net/dev /proc/net/wireless
  sec netcfg
  echo; echo "##### usb devices"; usb_snap
  catf /sys/kernel/debug/usb/devices
  sec mount
  sec df
  catf /proc/partitions /proc/mtd
  sec ls -l /dev/block/platform /dev/block/platform/*/by-name /dev/block/platform/*/*/by-name /dev/block/by-name
  sec ls -l /system/wifi /system/etc/wifi /system/etc/firmware /system/vendor/firmware /vendor/firmware /system/lib/modules /system/vendor/lib/modules /lib/modules
  sec ls -l /system/bin/hostapd /system/bin/wpa_supplicant /system/bin/dnsmasq /system/bin/insmod /system/bin/rmmod /system/bin/iw /system/xbin/iw /system/bin/toolbox
  sec /system/bin/hostapd -v
  sec ls -l /system/bin /system/xbin
  sec ls -lR $KP
  catf /data/nemesis/backup/korea.projection/nochip-wifi.txt /data/local/tmp/korea.projection/nochip-wifi.txt
} > $O/info.txt 2>&1

getprop > $O/getprop.txt 2>&1
dmesg > $O/dmesg.txt 2>&1
logcat -d -v time > $O/logcat.txt 2>&1
cat /proc/kallsyms > $O/kallsyms.txt 2>&1
cat /system/build.prop > $O/build.prop 2>/dev/null
[ -f /proc/config.gz ] && cat /proc/config.gz > $O/config.gz
[ -f /proc/device-tree/model ] && cat /proc/device-tree/model > $O/dt-model.txt

# 커널 모듈(.ko)을 모두 복사: vermagic·심볼 버전을 읽어 같은 조건으로 드라이버를 빌드한다
mkdir -p $O/modules
if [ -n "$BB" ]; then
  $BB find /system /vendor /lib /sbin /data/nemesis -name '*.ko' 2>/dev/null > $O/modules/list.txt
else
  for d in /system/wifi /system/lib/modules /system/vendor/lib/modules /vendor/lib/modules /lib/modules /sbin; do
    for f in $d/*.ko $d/*/*.ko $d/*/*/*.ko; do [ -f $f ] && echo $f; done
  done > $O/modules/list.txt
fi
k=0
while read f; do
  k=$((k+1))
  cat $f > $O/modules/$k-${f##*/} 2>/dev/null
done < $O/modules/list.txt

# 부트 파티션(커널 이미지)을 읽어 온다: 커널 설정(ikconfig)·심볼 CRC를 꺼내는 데 쓴다. 읽기만 한다.
for bn in /dev/block/platform/*/by-name /dev/block/platform/*/*/by-name /dev/block/by-name; do
  for nm in boot BOOT kernel KERNEL; do
    if [ -e $bn/$nm ] && [ ! -f $O/boot.img ]; then
      echo "boot: $bn/$nm" >> $O/info.txt
      dd if=$bn/$nm of=$O/boot.img bs=1048576 count=96 2>> $O/info.txt
    fi
  done
done

# USB를 빼도 도는 감시: 이 뒤에 꽂는 장치(동글)의 VID:PID와 커널 기록을 $ST에 남긴다. 다음 실행이 USB로 옮긴다.
cat $USB/NEMESIS.sh > $ST/watch.sh
: > $ST/usb-watch.txt
/system/bin/sh $ST/watch.sh watch < /dev/null > /dev/null 2>&1 &

echo "done" > $O/DONE.txt
sync
exit 0
