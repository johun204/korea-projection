#!/system/bin/sh
# USB Wi-Fi 동글 드라이버 1회 시험. NEMESIS type=execute로 root로 돈다.
# 내비에 아무것도 설치하지 않는다: 드라이버를 한 번 올려 보고(insmod) 시험이 끝나면 내린다(rmmod).
# 재부팅하면 흔적 없이 순정 그대로다(작업 폴더 /data/nemesis/kp-dongle-test 만 남고, 이 USB를 다시 꽂으면 지운다).
#   sh NEMESIS.sh        ① 지난 시험 결과를 USB로 옮기고 ② 새 시험을 뒤에 띄운다(USB를 빼고 동글을 꽂으면 시작)
#                        (시험 2부터) 동글 보호 모드(kp-dongle-aa-guard)가 없으면 먼저 그것만 넣고 끝낸다(재부팅 뒤 다시 꽂음).
#                        USB 맨 위에 kp-guard-remove 파일이 있으면 그 모드를 지운다(순정 안드로이드 오토로 되돌리기).
#   sh test.sh run       시험 본체(/data 사본이 돈다)
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

ST=/data/nemesis/kp-dongle-test
KP=/data/nemesis/apps/korea.projection
BB=$KP/bin/busybox
WAIT_DONGLE=600
IDS="0bda:b812"
TCONF=/data/misc/wifi/hostapd-kptest.conf
GUARD=kp-dongle-aa-guard
GUARD_ZIP=kp-dongle/kp-dongle-aa-guard-1.0.0.zip

stage() { echo "$(cat /proc/uptime) $*" >> $ST/stage.txt; $BB sync; }
dongle_dev() {
  for d in /sys/bus/usb/devices/*; do
    [ -f $d/idVendor ] || continue
    read v < $d/idVendor; read p < $d/idProduct
    case " $IDS " in *" $v:$p "*) echo $d; return 0 ;; esac
  done
  return 1
}
loaded() { $BB grep -q '^88x2bu ' /proc/modules; }
# 커널 기록에서 문제 줄만
kbad() { dmesg | $BB grep -c -i -E 'Unable to handle kernel|Internal error|Oops|BUG:|kernel BUG|unknown relocation|Unknown symbol|disagrees about version|Kernel panic'; }

# hostapd를 $1 설정으로 $2초 돌려 AP가 켜지는지 본다. 결과: ap-<이름>.txt, 성공이면 0
ap_try() {
  _n=$1; _secs=$2; shift 2
  {
    echo "interface=wlan0"; echo "driver=nl80211"; echo "ctrl_interface=/data/misc/wifi/hostapd"
    echo "ssid=KP-DONGLE-TEST"; echo "max_num_sta=5"; echo "ignore_broadcast_ssid=0"
    echo "wpa=2"; echo "wpa_key_mgmt=WPA-PSK"; echo "rsn_pairwise=CCMP"; echo "wpa_passphrase=kpdongle1234"
    for _l in "$@"; do echo "$_l"; done
  } > $TCONF
  $BB chown 1000:1010 $TCONF; $BB chmod 660 $TCONF
  $BB ifconfig wlan0 192.168.43.1 netmask 255.255.255.0 up 2>> $ST/ap-$_n.txt
  hostapd -dd $TCONF >> $ST/ap-$_n.txt 2>&1 &
  _hp=$!
  _i=0; _ok=1
  while [ $_i -lt $_secs ]; do
    sleep 2; _i=$((_i+2))
    kill -0 $_hp 2>/dev/null || break
    $BB grep -q 'AP-ENABLED' $ST/ap-$_n.txt && _ok=0
  done
  $BB grep -q 'AP-ENABLED' $ST/ap-$_n.txt && _ok=0
  kill -0 $_hp 2>/dev/null && echo "hostapd alive after ${_i}s" >> $ST/ap-$_n.txt || { echo "hostapd exited after ${_i}s" >> $ST/ap-$_n.txt; _ok=1; }
  $BB ifconfig wlan0 >> $ST/ap-$_n.txt 2>&1
  kill $_hp 2>/dev/null; sleep 2; kill -9 $_hp 2>/dev/null
  rm -f $TCONF
  echo "ap $_n: $([ $_ok = 0 ] && echo OK || echo FAIL)" >> $ST/result.txt
  return $_ok
}

if [ "$1" = run ]; then
  cd /
  echo $$ > $ST/test.pid
  stage "기다림: 동글"
  AOA0=$(dmesg | $BB grep -c 'proc_do_submiturb.*Request (51)')
  # 동글이 꽂힌 뒤 Android가 무엇을 하는지 보려고 logcat을 처음부터 받아 둔다
  logcat -v time MicomD:S "*:V" > $ST/logcat-live.txt 2>&1 &
  LP=$!
  n=0
  while ! dongle_dev > /dev/null; do
    sleep 2; n=$((n+2))
    [ $n -ge $WAIT_DONGLE ] && { stage "동글이 꽂히지 않음: 끝"; echo "result: NODONGLE" >> $ST/result.txt; kill $LP; rm -f $ST/test.pid; exit 0; }
  done
  stage "동글 꽂힘 $(dongle_dev)"
  sleep 8
  # 이 드라이버는 이 커널 빌드로만 확인했다: 다르면 올리지 않는다
  if [ "$(cat /proc/version)" != "$(cat $ST/kernel.txt)" ]; then
    stage "커널이 다름: 올리지 않음"; echo "result: KERNEL-MISMATCH" >> $ST/result.txt; kill $LP; rm -f $ST/test.pid; exit 0
  fi
  if [ -d /sys/class/net/wlan0 ] || loaded; then
    stage "wlan0 또는 드라이버가 이미 있음: 올리지 않음"; echo "result: ALREADY" >> $ST/result.txt; kill $LP; rm -f $ST/test.pid; exit 0
  fi
  dmesg > $ST/dmesg-before.txt 2>&1
  K0=$(kbad)
  # 동글을 꽂은 뒤 순정 안드로이드 오토가 동글에 연결 요청(AOA)을 보냈는가(보냈으면 칩이 멈춰 있다)
  AOA1=$($BB grep -c 'proc_do_submiturb.*Request (51)' $ST/dmesg-before.txt)
  echo "aoa probes after plug: $((AOA1 - AOA0))" >> $ST/result.txt
  [ -f /data/hmgapi/mods/$GUARD/mod.json ] && echo "guard mod: installed" >> $ST/result.txt || echo "guard mod: none" >> $ST/result.txt
  stage "insmod 시작"
  insmod $ST/88x2bu.ko rtw_country_code=KR > $ST/insmod.txt 2>&1
  echo "rc=$?" >> $ST/insmod.txt
  stage "insmod 끝 $(cat $ST/insmod.txt | $BB tr '\n' ' ')"
  n=0
  while [ ! -d /sys/class/net/wlan0 ] && [ $n -lt 20 ]; do sleep 1; n=$((n+1)); done
  if loaded; then echo "module: loaded" >> $ST/result.txt; else echo "module: NOT loaded" >> $ST/result.txt; fi
  if [ -d /sys/class/net/wlan0 ]; then
    stage "wlan0 생김 (${n}초)"; echo "wlan0: yes (${n}s)" >> $ST/result.txt
    {
      echo "## net"; ls /sys/class/net; echo "## ieee80211"; ls -l /sys/class/ieee80211 2>&1
      echo "## ifconfig"; $BB ifconfig wlan0 2>&1
      echo "## driver link"; ls -l /sys/class/net/wlan0/device/driver 2>&1
      echo "## proc"; ls -R /proc/net/rtl88x2bu 2>&1
      for f in /proc/net/rtl88x2bu/ver_info /proc/net/rtl88x2bu/chplan_id_list /proc/net/rtl88x2bu/wlan0/chan_plan /proc/net/rtl88x2bu/wlan0/country_code; do echo "## $f"; cat $f 2>&1; done
    } > $ST/wlan0.txt 2>&1
    # Android Wi-Fi 서비스가 이 wlan0에 반응하는지 20초 본다
    sleep 20
    { echo "wifi_on=$(settings get global wifi_on 2>&1) wifi_ap_on=$(settings get global wifi_ap_on 2>&1)"
      echo "wlan.driver.status=$(getprop wlan.driver.status) init.svc.wpa_supplicant=$(getprop init.svc.wpa_supplicant)"
      $BB ps | $BB grep -E 'wpa_supplicant|hostapd|dnsmasq' | $BB grep -v grep; } > $ST/android-wifi.txt 2>&1
    if $BB ps | $BB grep -v grep | $BB grep -q wpa_supplicant; then
      echo "wpa_supplicant: started by Android (stopped for the test)" >> $ST/result.txt
      $BB killall wpa_supplicant 2>/dev/null; sleep 3
    else
      echo "wpa_supplicant: not running" >> $ST/result.txt
    fi
    stage "AP 시험 시작"
    # Korea Projection과 같은 설정(5GHz 149번, 40MHz)부터. 안 되면 무엇이 되는지 알아 둔다.
    if ap_try ch149-ht40 120 "hw_mode=a" "channel=149" "ieee80211n=1" "ht_capab=[HT40+][SHORT-GI-20][SHORT-GI-40]"; then :
    elif ap_try ch149-ht20 20 "hw_mode=a" "channel=149" "ieee80211n=1"; then :
    elif ap_try ch36-ht20 20 "hw_mode=a" "channel=36" "ieee80211n=1"; then :
    else ap_try ch6-2g 20 "hw_mode=g" "channel=6" "ieee80211n=1"; fi
    stage "AP 시험 끝"
  else
    stage "wlan0 안 생김"; echo "wlan0: no" >> $ST/result.txt
  fi
  dmesg > $ST/dmesg-loaded.txt 2>&1
  # 정리: 드라이버를 내린다
  $BB ifconfig wlan0 down 2>/dev/null
  stage "rmmod 시작"
  rmmod 88x2bu > $ST/rmmod.txt 2>&1; echo "rc=$?" >> $ST/rmmod.txt
  sleep 2
  if loaded; then echo "rmmod: STILL LOADED" >> $ST/result.txt; else echo "rmmod: ok" >> $ST/result.txt; fi
  stage "rmmod 끝"
  dmesg > $ST/dmesg-after.txt 2>&1
  K1=$(kbad)
  echo "kernel problems: before=$K0 after=$K1" >> $ST/result.txt
  sleep 5
  kill $LP 2>/dev/null
  {
    echo "## /data/misc/wifi"; ls -l /data/misc/wifi 2>&1
    echo "## permissions (wifi·projection)"; ls /system/etc/permissions | $BB grep -i -E 'wifi|hotspot|carplay|androidauto|projection'
    echo "## korea.projection backup"; ls -l /data/nemesis/backup/korea.projection 2>&1
    echo "## hmgapi"; ls -l /data/hmgapi /data/hmgapi/public /data/hmgapi/mods 2>&1
    echo "## props"; getprop | $BB grep -i -E 'wifi|wlan|ium|projection|hmgapi|korea'
  } > $ST/state.txt 2>&1
  cat /data/local/tmp/korea.projection/ap.log > $ST/kp-ap.log 2>/dev/null
  echo "result: DONE" >> $ST/result.txt
  stage "끝"
  rm -f $ST/test.pid
  exit 0
fi

USB=$(pwd)
[ -x $BB ] || { echo "busybox 없음: Korea Projection이 설치되어 있어야 합니다"; exit 1; }
# 지난 시험 결과를 USB로 옮긴다(시험이 아직 돌고 있으면 멈추고 드라이버를 내린다)
RC=0
if [ -d $ST ]; then
  if [ -f $ST/test.pid ]; then
    kill $(cat $ST/test.pid) 2>/dev/null
    $BB killall hostapd 2>/dev/null
    loaded && { $BB ifconfig wlan0 down 2>/dev/null; rmmod 88x2bu 2>/dev/null; }
    echo "result: INTERRUPTED (시험이 끝나기 전에 USB를 다시 꽂음)" >> $ST/result.txt
  fi
  N=1; while [ -e $USB/KP-dongle-test/run-$N ]; do N=$((N+1)); done
  O=$USB/KP-dongle-test/run-$N
  mkdir -p $O
  for f in $ST/*.txt $ST/*.log; do [ -f $f ] && cat $f > $O/${f##*/}; done
  dmesg > $O/dmesg-now.txt 2>&1
  cat /proc/modules > $O/modules-now.txt
  rm -f $TCONF
  # 통과 기준: 드라이버가 올라와 wlan0이 생기고, AP가 한 번이라도 켜지고, 깨끗이 내려가고, 커널 문제 줄이 늘지 않음
  if $BB grep -q '^result: DONE' $ST/result.txt 2>/dev/null && $BB grep -q '^wlan0: yes' $ST/result.txt \
     && $BB grep -q '^ap .*: OK' $ST/result.txt && $BB grep -q '^rmmod: ok' $ST/result.txt; then
    echo PASS > $O/VERDICT.txt
  else
    echo FAIL > $O/VERDICT.txt; RC=1
  fi
  rm -rf $ST
  $BB sync
  # 결과를 옮긴 실행은 여기서 끝낸다(성공 창 = 통과, 실패 창 = 통과 못 함). 새 시험은 USB를 다시 꽂아 시작한다.
  exit $RC
fi

# 동글 보호 모드: 지우기 요청이 있으면 지운다
if [ -f $USB/kp-guard-remove ]; then
  N=1; while [ -e $USB/KP-dongle-test/guard-remove-$N.txt ]; do N=$((N+1)); done
  G=$USB/KP-dongle-test/guard-remove-$N.txt; mkdir -p $USB/KP-dongle-test
  { echo "## remove"; hmgapid engine remove $GUARD; echo "rc=$?"; echo "## apply"; hmgapid engine apply; echo "rc=$?"; } > $G 2>&1
  $BB sync
  [ -f /data/hmgapi/mods/$GUARD/mod.json ] && exit 1
  exit 0
fi
# 동글 보호 모드가 없으면 그것만 넣는다. 파일·설정을 바꾸는 계획이면 적용하지 않는다(훅만 있는 모드라 바뀌는 파일이 없어야 한다)
if [ ! -f /data/hmgapi/mods/$GUARD/mod.json ] && [ -f $USB/$GUARD_ZIP ]; then
  mkdir -p $USB/KP-dongle-test
  N=1; while [ -e $USB/KP-dongle-test/guard-$N.txt ]; do N=$((N+1)); done
  G=$USB/KP-dongle-test/guard-$N.txt
  mkdir -p $ST; cat $USB/$GUARD_ZIP > $ST/guard.zip
  { echo "## install"; hmgapid engine install $ST/guard.zip; echo "rc=$?"; echo "## plan"; } > $G 2>&1
  hmgapid engine plan > $ST/plan.txt 2>&1; echo "rc=$?" >> $ST/plan.txt
  cat $ST/plan.txt >> $G
  if [ ! -f /data/hmgapi/mods/$GUARD/mod.json ]; then
    echo "RESULT: install failed" >> $G; rm -rf $ST; $BB sync; exit 1
  fi
  if $BB grep -q -E '^(change|update|restore|setting|bind|unbind|rebase|problem) |^hooks +'$GUARD' won|^hooks are off' $ST/plan.txt; then
    # 계획에 파일·설정 변경이 있거나 우리 훅이 안 올라감: 적용하지 않고 모드를 다시 뺀다
    { echo "## refused: plan changes files/settings or the guard won't load; removing it again"; hmgapid engine remove $GUARD; echo "rc=$?"; } >> $G 2>&1
    echo "RESULT: refused" >> $G; rm -rf $ST; $BB sync; exit 1
  fi
  if ! $BB grep -q '^nothing to do' $ST/plan.txt; then
    { echo "## apply"; hmgapid engine apply; echo "rc=$?"; } >> $G 2>&1
  fi
  echo "RESULT: installed (재부팅하면 켜짐)" >> $G
  rm -rf $ST; $BB sync
  exit 0
fi

# 새 시험 준비: 드라이버를 /data로 복사하고 뒤에서 동글을 기다린다
mkdir -p $ST || exit 1
cat $USB/kp-dongle/88x2bu.ko > $ST/88x2bu.ko
cat $USB/kp-dongle/kernel.txt > $ST/kernel.txt
cat $USB/NEMESIS.sh > $ST/test.sh
set -- $($BB md5sum < $ST/88x2bu.ko)
if [ "$1" != "$(cat $USB/kp-dongle/88x2bu.ko.md5)" ]; then
  echo "드라이버 파일이 깨짐(복사 오류)"; rm -rf $ST; exit 1
fi
: > $ST/result.txt
/system/bin/sh $ST/test.sh run < /dev/null > /dev/null 2>&1 &
$BB sync
exit 0
