#!/bin/sh
# USB Wi-Fi 동글 부분(hotspot.sh의 dongle_*)을 가짜 환경에서 돌린다: sh tests/dongle-test.sh
B=$(cd "$(dirname "$0")/.." && pwd)
PKG=$B/nemesis-pkg/korea.projection
T=$(mktemp -d /tmp/kp-dongle.XXXXXX)
trap 'rm -rf $T' EXIT
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails+1)); fi; }

mkdir -p $T/bin
printf '#!/bin/sh\ncase "$1" in sync) exit 0 ;; ps) exit 0 ;; esac\nexec "$@"\n' > $T/bin/bb
# 가짜 insmod: 성공하면 모듈 목록에 넣고 wlan0을 만든다
cat > $T/bin/insmod <<E
#!/bin/sh
echo "insmod \$*" >> $T/calls
[ -f $T/insmod_fails ] && { echo "insmod: init_module failed"; exit 1; }
echo "88x2bu 2450000 0 - Live 0x00000000 (O)" >> $T/modules
[ -f $T/no_wlan ] || mkdir -p $T/net/wlan0
exit 0
E
printf '#!/bin/sh\necho "rmmod $*" >> %s/calls\n: > %s/modules\nrm -rf %s/net/wlan0\n' $T $T $T > $T/bin/rmmod
printf '#!/bin/sh\nexit 0\n' > $T/bin/sleep
chmod +x $T/bin/*

# 한 장면: 깨끗한 가짜 내비를 만들고 hotspot.sh를 라이브러리로 읽는다
fresh() {
  rm -rf $T/app $T/bk $T/w $T/usb $T/net $T/hmg $T/calls $T/modules $T/insmod_fails $T/no_wlan
  mkdir -p $T/app/dongle $T/bk $T/w $T/usb/1-1 $T/usb/usb1 $T/net $T/hmg/public
  : > $T/modules; : > $T/calls
  echo 1d6b > $T/usb/usb1/idVendor; echo 0002 > $T/usb/usb1/idProduct
  echo 0bda > $T/usb/1-1/idVendor; echo b812 > $T/usb/1-1/idProduct
  : > $T/app/dongle/88x2bu.ko
  mkdir -p $T/app/bin; cp $T/bin/bb $T/app/bin/busybox
  echo "Linux version 3.18.24-tcc test" > $T/app/dongle/kernel.txt
  echo "Linux version 3.18.24-tcc test" > $T/procver
  echo boot-A > $T/bootid
  # 동글 기능 켜짐: 보호 모드 설치·켜짐
  mkdir -p $T/hmg/mods/kp-dongle-aa-guard; echo '{"id": "kp-dongle-aa-guard"}' > $T/hmg/mods/kp-dongle-aa-guard/mod.json
}
run() {  # run '<셸 코드>' : 새 셸에서 hotspot.sh를 읽고 코드를 돌린다
  PATH=$T/bin:$PATH HOTSPOT_LIB=1 APP=$T/app BB=$T/bin/bb BK=$T/bk W=$T/w WLAN=$T/net/wlan0 USBDEV=$T/usb \
    MODULES=$T/modules PROCVER=$T/procver BOOT_ID=$T/bootid HMGDATA=$T/hmg NOTICE=$T/notice UPTIME=$T/uptime \
    INSMOD=$T/bin/insmod RMMOD=$T/bin/rmmod CONF=$T/hostapd.conf \
    sh -c ". $PKG/svc/hotspot.sh; export PATH=$T/bin:/usr/bin:/bin:/sbin; $1" > $T/out 2>&1
}
calls() { grep -c "^$1" $T/calls; }

fresh; rm -rf $T/usb/1-1
run 'dongle_up'; check "동글 없음: 올리지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ]'

fresh; run 'dongle_up'; rc=$?
check "동글 있음: 드라이버를 올리고 wlan0이 생김" '[ $rc = 0 ] && [ $(calls insmod) = 1 ] && [ -d $T/net/wlan0 ]'
check "올릴 때 국가 설정을 넘김" 'grep -q "88x2bu.ko rtw_country_code=KR" $T/calls'
check "위험 구간 기록(dongle.trying)에 이번 부팅 id" '[ "$(cat $T/bk/dongle.trying)" = boot-A ]'
check "HMG-API 칩 기록을 만들고 우리 것으로 표시" '[ -f $T/hmg/public/wifi-chip ] && [ -f $T/bk/wifi-chip.ours ]'
run 'dongle_up'; check "이미 올라와 있으면 다시 올리지 않음" '[ $? = 0 ] && [ $(calls insmod) = 1 ]'
run 'wifi_chip_seen'; check "동글의 wlan0이 있으면 칩이 있는 것으로 봄" '[ $? = 0 ]'

fresh; : > $T/hmg/public/wifi-chip
run 'dongle_up'; check "원래 있던 칩 기록은 우리 것으로 표시하지 않음" '[ ! -f $T/bk/wifi-chip.ours ]'

fresh; echo "Linux version 3.18.24-tcc other build" > $T/procver
run 'dongle_up'; check "커널이 다르면 올리지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ] && grep -q "커널이" $T/out'

fresh; rm -f $T/app/dongle/kernel.txt
run 'dongle_up'; check "커널 기록 파일이 없으면 올리지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ]'

fresh; mkdir -p $T/net/wlan0
run 'dongle_up'; check "내장 칩의 wlan0이 있으면 동글을 쓰지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ]'

fresh; : > $T/insmod_fails
run 'dongle_up; r=$?; dongle_up; exit $r'; rc=$?
check "insmod 실패: 실패로 끝나고 같은 실행에서 다시 올리지 않음" '[ $rc = 1 ] && [ $(calls insmod) = 1 ]'
check "insmod 실패는 재시작이 아님: 구간 기록을 지움" '[ ! -f $T/bk/dongle.trying ] && [ ! -f $T/bk/dongle.crashes ]'

fresh; : > $T/no_wlan
run 'dongle_up'; check "올라왔지만 wlan0이 안 생김: 실패, 구간 기록 지움" '[ $? = 1 ] && [ ! -f $T/bk/dongle.trying ]'

# 위험 구간에서 내비가 재시작된 경우
fresh; echo boot-OLD > $T/bk/dongle.trying
run 'dongle_up'; rc=$?
check "지난 부팅이 구간에서 끝남(1번째): 횟수를 세고 다시 올림" '[ $rc = 0 ] && [ "$(cat $T/bk/dongle.crashes)" = 1 ] && [ $(calls insmod) = 1 ]'
fresh; echo boot-OLD > $T/bk/dongle.trying; echo 1 > $T/bk/dongle.crashes
run 'dongle_up'; rc=$?
check "2번째: 막고 올리지 않음" '[ $rc = 1 ] && [ -f $T/bk/dongle.blocked ] && [ $(calls insmod) = 0 ]'
check "막을 때 알림을 남김" 'grep -q "동글 사용을 멈췄습니다" $T/notice'
echo boot-B > $T/bootid
run 'dongle_up'; check "막힌 뒤에는 다음 부팅에도 올리지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ]'

fresh; echo boot-A > $T/bk/dongle.trying
run 'dongle_up'; check "같은 부팅의 구간 기록(서비스만 다시 시작)은 재시작으로 세지 않음" '[ $? = 0 ] && [ ! -f $T/bk/dongle.crashes ]'

# hostapd 구간: 켜기 전에 열고, 오래 살아 있으면 닫고 횟수를 지움
fresh; echo 1 > $T/bk/dongle.crashes; echo "100.0 0" > $T/uptime
run 'dongle_up; rm -f $BK/dongle.trying; dongle_ap_begin; [ -f $BK/dongle.trying ] || exit 9
     running() { return 0; }; echo "150.0 0" > $UPTIME; dongle_settle; [ -f $BK/dongle.trying ] || exit 8
     echo "230.0 0" > $UPTIME; dongle_settle; [ ! -f $BK/dongle.trying ] && [ ! -f $BK/dongle.crashes ]'
check "hostapd 구간: 열림 → 120초 전에는 유지 → 지나면 닫고 재시작 횟수 지움" '[ $? = 0 ]'

fresh
run 'dongle_up; dongle_down'; check "dongle_down: 드라이버를 내림" '[ $? = 0 ] && [ $(calls rmmod) = 1 ] && [ ! -s $T/modules ]'
run 'dongle_down'; check "올라와 있지 않으면 rmmod를 부르지 않음" '[ $? = 0 ] && [ $(calls rmmod) = 1 ]'

# --- 보호 모드 조건 ---
fresh; rm -rf $T/hmg/mods/kp-dongle-aa-guard
run 'dongle_up'; check "보호 모드가 없으면 올리지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ] && grep -q "보호 모드" $T/out'
fresh; : > $T/hmg/mods/kp-dongle-aa-guard/.disabled
run 'dongle_up'; check "보호 모드가 꺼져 있으면 올리지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ]'

echo; [ $fails = 0 ] && echo "모두 통과" || echo "실패 $fails개"
exit $fails
