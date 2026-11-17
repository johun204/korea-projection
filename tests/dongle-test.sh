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

# --- 다시 꽂기 ---
fresh; echo 3 > $T/usb/1-1/devnum; : > $T/insmod_fails
run 'dongle_up; dongle_up; echo 4 > $USBDEV/1-1/devnum; rm -f '$T'/insmod_fails; dongle_up; exit $?'; rc=$?
check "insmod 실패 뒤 같은 동글은 다시 안 올리고, 뺐다 꽂으면(장치 번호 바뀜) 다시 올림" '[ $rc = 0 ] && [ $(calls insmod) = 2 ] && [ -d $T/net/wlan0 ]'
fresh; : > $T/no_wlan
run 'dongle_up; mkdir -p $WLAN; dongle_up; exit $?'; rc=$?
check "드라이버는 올라왔는데 wlan0이 없던 동글을 다시 꽂아 wlan0이 생기면 칩 기록을 만듦" '[ $rc = 0 ] && [ $(calls insmod) = 1 ] && [ -f $T/hmg/public/wifi-chip ] && [ -f $T/bk/wifi-chip.ours ]'

# --- 부팅 완료 전 핫스팟(dongle_early) ---
early() {  # early '<준비>' : 무선 모드 적용·softap 읽힘을 흉내 내고 dongle_early를 부른다
  printf '#!/bin/sh\ncase "$1" in persist.sys.iap2.wifi) cat %s/iap2 2>/dev/null ;; *) echo ;; esac\n' $T > $T/bin/getprop; chmod +x $T/bin/getprop
  run "$1; parse_conf() { NS=4; S2=KP; S4=password1; }; write_conf() { echo WRITE; }; up() { echo UP; : > $T/hostapd_on; }
       aa_sig() { echo AASIG; }; running() { [ -f $T/hostapd_on ]; }; dongle_early DEPEHEV.KOR.0000.V039.001.260902; r=\$?; echo early=\$DONGLE_EARLY; exit \$r"
}
ready() { echo t > $T/iap2; mkdir -p $T/hmg/mods/wireless-carplay-aa; echo '{}' > $T/hmg/mods/wireless-carplay-aa/mod.json; rm -f $T/hostapd_on; }
fresh; ready; early ':'; rc=$?
check "설정이 끝난 동글 차: 부팅 완료 전에 드라이버·핫스팟·AA 신호를 켬" '[ $rc = 0 ] && [ $(calls insmod) = 1 ] && grep -q "^UP" $T/out && grep -q AASIG $T/out && grep -q "early=1" $T/out'
fresh; ready; rm -f $T/iap2; early ':'; rc=$?
check "무선 모드가 적용되지 않았으면(iap2.wifi≠t) 아무것도 안 함" '[ $rc = 1 ] && [ $(calls insmod) = 0 ] && ! grep -q "^UP" $T/out'
fresh; ready; rm -rf $T/usb/1-1; early ':'; rc=$?
check "동글이 없으면 아무것도 안 함" '[ $rc = 1 ] && [ $(calls insmod) = 0 ]'
fresh; ready; run "printf '#!/bin/sh\necho t\n' > $T/bin/getprop; chmod +x $T/bin/getprop; parse_conf() { NS=2; }; up() { echo UP; }; dongle_early DEPEHEV.KOR.0000.V039.001.260902"; rc=$?
check "softap.conf를 못 읽으면 드라이버를 올리지 않음" '[ $rc = 1 ] && [ $(calls insmod) = 0 ] && ! grep -q "^UP" $T/out'
fresh; ready; early ':' ; run "printf '#!/bin/sh\necho t\n' > $T/bin/getprop; chmod +x $T/bin/getprop; dongle_early CVEV.USA.0000.V015.012.260507"; rc=$?
check "한국 차가 아니면 아무것도 안 함" '[ $rc = 1 ]'
rm -f $T/bin/getprop

# --- 켜기·끄기 조건(서비스) ---
fresh; : > $T/bk/dongle.off
run 'dongle_up'; check "끔 표시가 있으면 올리지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ] && grep -q "꺼 둠" $T/out'
fresh; rm -rf $T/hmg/mods/kp-dongle-aa-guard
run 'dongle_up'; check "보호 모드가 없으면 올리지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ] && grep -q "보호 모드" $T/out'
fresh; : > $T/hmg/mods/kp-dongle-aa-guard/.disabled
run 'dongle_up'; check "보호 모드가 꺼져 있으면(HMG-API 앱) 올리지 않음" '[ $? = 1 ] && [ $(calls insmod) = 0 ]'
fresh
run 'dongle_up; stop_ap() { echo STOPAP; }; dongle_off_tick; echo T1; : > $BK/dongle.off; dongle_off_tick'
check "켜져 있으면 점검이 아무것도 안 함, 끄면 핫스팟을 멈추고 드라이버를 내림" '[ "$(sed -n "/T1/,\$p" $T/out | grep -c STOPAP)" = 1 ] && ! sed -n "1,/T1/p" $T/out | grep -q STOPAP && [ $(calls rmmod) = 1 ] && [ ! -s $T/modules ]'
fresh
run 'dongle_up; stop_ap() { :; }; : > $HMGDATA/mods/kp-dongle-aa-guard/.disabled; dongle_off_tick'
check "HMG-API 앱에서 보호 모드를 끄면 드라이버를 내림" '[ $(calls rmmod) = 1 ]'

# --- bin/dongle-ctl.sh ---
cat > $T/bin/hmgapid <<E
#!/bin/sh
echo "hmgapid \$*" >> $T/calls
G=$T/hmg/mods/kp-dongle-aa-guard
case "\$1 \$2" in
  "ping "*) exit 0 ;;
  "enable "*) rm -f $T/hmg/mods/\$2/.disabled; echo enabled ;;
  "disable "*) : > $T/hmg/mods/\$2/.disabled; echo disabled ;;
  "engine install") mkdir -p \$G; echo '{}' > \$G/mod.json; echo installed ;;
  "engine plan") cat $T/plan 2>/dev/null || echo "nothing to do" ;;
  "engine apply") echo applied ;;
  "engine remove") rm -rf $T/hmg/mods/\$3; echo removed ;;
esac
exit 0
E
chmod +x $T/bin/hmgapid
ctl() {
  PATH=$T/bin:$PATH HOTSPOT_LIB=1 APP=$T/app BB=$T/bin/bb BB_OK=1 BK=$T/bk W=$T/w WLAN=$T/net/wlan0 USBDEV=$T/usb \
    MODULES=$T/modules PROCVER=$T/procver BOOT_ID=$T/bootid HMGDATA=$T/hmg NOTICE=$T/notice UPTIME=$T/uptime \
    INSMOD=$T/bin/insmod RMMOD=$T/bin/rmmod CONF=$T/hostapd.conf KP_HOTSPOT=$T/hs.sh \
    sh $PKG/bin/dongle-ctl.sh "$@" > $T/out 2>&1
}
sed "s#^export PATH=.*#export PATH=$T/bin:/usr/bin:/bin:/sbin#" $PKG/svc/hotspot.sh > $T/hs.sh
# 가짜 hotspot 라이브러리 위에서 dongle-ctl이 쓰는 함수를 맞춘다(has_bb·stop_ours는 진짜를 쓰되 ps는 빈 결과)
fresh; rm -rf $T/hmg/mods/kp-dongle-aa-guard; echo zip > $T/app/dongle/kp-dongle-aa-guard.zip
ctl on; rc=$?
check "on: 보호 모드가 없으면 넣고 재부팅 안내" '[ $rc = 0 ] && [ -f $T/hmg/mods/kp-dongle-aa-guard/mod.json ] && grep -q "재부팅" $T/out && grep -q "engine install" $T/calls'
fresh; rm -rf $T/hmg/mods/kp-dongle-aa-guard; echo zip > $T/app/dongle/kp-dongle-aa-guard.zip; printf "change   /system/build.prop [x]\n" > $T/plan
ctl on; rc=$?
check "on: 계획에 파일 변경이 있으면 적용하지 않고 보호 모드를 다시 뺌" '[ $rc = 1 ] && [ ! -d $T/hmg/mods/kp-dongle-aa-guard ] && ! grep -q "engine apply" $T/calls'
rm -f $T/plan
fresh; : > $T/bk/dongle.off; : > $T/bk/dongle.blocked; echo 2 > $T/bk/dongle.crashes; : > $T/hmg/mods/kp-dongle-aa-guard/.disabled
ctl on; rc=$?
check "on: 끔 표시·막힘 기록을 지우고 꺼진 보호 모드를 켬" '[ $rc = 0 ] && [ ! -f $T/bk/dongle.off ] && [ ! -f $T/bk/dongle.blocked ] && [ ! -f $T/bk/dongle.crashes ] && [ ! -f $T/hmg/mods/kp-dongle-aa-guard/.disabled ]'
fresh; ctl off; rc=$?
check "off: 끔 표시를 남기고 보호 모드를 끔" '[ $rc = 0 ] && [ -f $T/bk/dongle.off ] && [ -f $T/hmg/mods/kp-dongle-aa-guard/.disabled ] && grep -q "동글 기능: 꺼짐" $T/out'
fresh; run 'dongle_up'; ctl off
check "off: 올라와 있던 드라이버를 내림" '[ $(calls rmmod) = 1 ] && [ ! -s $T/modules ]'
fresh; run 'dongle_up'; : > $T/bk/mod.ours; mkdir -p $T/hmg/mods/wireless-carplay-aa; echo '{"system":[{"region": "KOR"}]}' > $T/hmg/mods/wireless-carplay-aa/mod.json
printf "restore  /system/etc/permissions/x.xml (stock)\n" > $T/plan
ctl remove; rc=$?
check "remove: 드라이버·보호 모드·우리가 넣은 무선 모드·우리 칩 기록·동글 기록을 되돌림" '[ $rc = 0 ] && [ $(calls rmmod) = 1 ] && [ ! -d $T/hmg/mods/kp-dongle-aa-guard ] && [ ! -d $T/hmg/mods/wireless-carplay-aa ] && [ ! -f $T/bk/mod.ours ] && [ ! -f $T/hmg/public/wifi-chip ] && [ ! -f $T/bk/wifi-chip.ours ] && [ ! -f $T/bk/dongle.trying ] && [ ! -f $T/bk/dongle.off ]'
rm -f $T/plan
fresh; mkdir -p $T/hmg/mods/wireless-carplay-aa; echo '{"system":[{"region": "KOR"}]}' > $T/hmg/mods/wireless-carplay-aa/mod.json; : > $T/hmg/public/wifi-chip
ctl remove; rc=$?
check "remove: 우리가 넣지 않은 무선 모드·원래 있던 칩 기록은 그대로 둠" '[ $rc = 0 ] && [ -d $T/hmg/mods/wireless-carplay-aa ] && [ -f $T/hmg/public/wifi-chip ]'
fresh; : > $T/bk/mod.ours; mkdir -p $T/hmg/mods/wireless-carplay-aa; echo '{"system":[{"region": "KOR"}]}' > $T/hmg/mods/wireless-carplay-aa/mod.json
printf "change   /system/x [other]\n" > $T/plan
ctl remove; rc=$?
check "remove: 무선 모드 계획에 다른 변경이 있으면 적용하지 않고 실패로 알림, 동글 기능은 꺼 둠" '[ $rc = 1 ] && [ -f $T/bk/dongle.off ] && ! grep -q "engine apply" $T/calls && grep -q "적용해 주세요" $T/out'
rm -f $T/plan
fresh; ctl status; check "status: 상태 줄" 'grep -q "보호 모드(kp-dongle-aa-guard): 켜짐" $T/out && grep -q "동글 꽂힘: 예" $T/out'

cp $T/out /tmp/kp-last-out; echo; [ $fails = 0 ] && echo "모두 통과" || echo "실패 $fails개"
exit $fails
