#!/system/bin/sh
# 포크: USB Wi-Fi 동글 기능 켜기·끄기·지우기(root).
#   dongle-ctl.sh on       보호 모드(kp-dongle-aa-guard)를 넣거나 켜고 끔 표시를 지운다. 막힘 기록도 푼다.
#   dongle-ctl.sh off      끔 표시를 남기고 보호 모드를 끈다. 동글로 켠 핫스팟을 멈추고 드라이버를 내린다.
#   dongle-ctl.sh remove   동글 때문에 생긴 것을 모두 되돌린다(Korea Projection·HMG-API는 그대로 둔다):
#                          드라이버·핫스팟, 보호 모드, 동글로 칩이 생겨 우리가 넣은 무선 모드, 우리가 만든 칩 기록,
#                          Wi-Fi 잠금, 순정 AP 저장값, 동글 기록. 그 뒤 재부팅하면 동글 전 상태다.
#   dongle-ctl.sh status   지금 상태
# 보호 모드를 새로 넣거나 켜면 재부팅해야 훅이 올라온다(HMG-API가 부팅 때 모드를 올린다).
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
umask 077
BB=
BK=${BK:-/data/nemesis/backup/korea.projection}
HOTSPOT_LIB=1 . ${KP_HOTSPOT:-/data/nemesis/apps/korea.projection/svc/hotspot.sh}
has_bb || { echo "busybox를 쓸 수 없음: 아무것도 바꾸지 않음"; exit 1; }
GDIR=$HMGDATA/mods/$GUARD_ID
GZIP=${GZIP:-$DONGLE_D/$GUARD_ID.zip}

guard_state() {
  if [ ! -f $GDIR/mod.json ]; then echo 없음
  elif [ -f $GDIR/.disabled ]; then echo 꺼짐
  else echo 켜짐; fi
}
status() {
  echo "동글 기능: $([ -f $BK/dongle.off ] && echo 꺼짐 || echo "켜짐(끔 표시 없음)")"
  echo "보호 모드($GUARD_ID): $(guard_state)"
  echo "동글 꽂힘: $(dongle_plugged && echo 예 || echo 아니요), 드라이버: $(dongle_loaded && echo 올라옴 || echo 없음), wlan0: $([ -d $WLAN ] && echo 있음 || echo 없음)"
  echo "막힘 기록: $([ -f $BK/dongle.blocked ] && echo 있음 || echo 없음), 재시작 횟수: $(cat $BK/dongle.crashes 2>/dev/null || echo 0)"
  echo "무선 모드($MOD_ID): $([ -f $HMGDATA/mods/$MOD_ID/mod.json ] && echo 있음 || echo 없음)$([ -f $BK/mod.ours ] && echo '(Korea Projection이 넣음)')"
}
# 지금 동글로 켠 핫스팟을 멈추고 드라이버를 내린다(서비스도 30초 안에 같은 일을 한다)
unload() {
  dongle_loaded || return 0
  stop_ours
  dongle_down
}
# 보호 모드 넣기: 파일·설정을 바꾸는 계획이거나 훅이 꺼진 차면 적용하지 않고 다시 뺀다
guard_install() {
  [ -f $GZIP ] || { echo "보호 모드 파일이 패키지에 없음($GZIP)"; return 1; }
  hmgapid ping >/dev/null 2>&1 || { echo "HMG-API 데몬이 응답하지 않음: 보호 모드를 넣지 못함"; return 1; }
  hmgapid engine install $GZIP > $W/guard-install.txt 2>&1
  [ -f $GDIR/mod.json ] || { echo "보호 모드 설치 실패:"; cat $W/guard-install.txt; return 1; }
  hmgapid engine plan > $W/guard-plan.txt 2>&1
  if $BB grep -q -E '^(change|update|restore|setting|bind|unbind|rebase|problem) |^hooks +'$GUARD_ID' won|^hooks are off' $W/guard-plan.txt; then
    echo "보호 모드를 적용하지 않고 다시 뺌(계획에 다른 변경이 있거나 훅이 꺼진 차):"; cat $W/guard-plan.txt
    hmgapid engine remove $GUARD_ID > /dev/null 2>&1
    return 1
  fi
  $BB grep -q '^nothing to do' $W/guard-plan.txt || hmgapid engine apply > $W/guard-apply.txt 2>&1
  echo "보호 모드를 넣음"
  return 0
}
# Korea Projection이 넣은 무선 모드 지우기(preun과 같은 확인). 0: 지웠거나 지울 것 없음, 1: 남음
wmod_remove() {
  [ -f $BK/mod.ours ] && [ -f $HMGDATA/mods/$MOD_ID/mod.json ] && mod_kor || return 0
  hmgapid ping >/dev/null 2>&1 || { echo "HMG-API 데몬이 응답하지 않음: 무선 모드를 지우지 못함"; return 1; }
  hmgapid engine remove $MOD_ID > $W/wmod-remove.txt 2>&1 || { echo "무선 모드 지우기 실패"; return 1; }
  hmgapid engine plan > $W/wmod-plan.txt 2>&1
  _bad=0
  while IFS= read -r _l; do
    case "$_l" in
      "restore  "*|"setting  "*" back to stock"*|"unbind   "*|"same     "*) ;;
      "change   "*|"update   "*|"setting  "*|"bind     "*|"problem  "*|"rebase   "*|"nothing changed"*) _bad=1 ;;
    esac
  done < $W/wmod-plan.txt
  if [ $_bad = 0 ] && hmgapid engine apply > /dev/null 2>&1; then
    rm -f $BK/mod.ours $BK/mod.tried
    echo "Korea Projection이 넣었던 무선 모드를 지움"
    return 0
  fi
  echo "무선 모드를 지웠지만 적용하지 않음: HMG-API 앱에서 변경 사항을 적용해 주세요"
  cat $W/wmod-plan.txt
  return 1
}

$BB mkdir -p $BK $W
case "$1" in
  on)
    rm -f $BK/dongle.off $BK/dongle.blocked $BK/dongle.crashes $BK/dongle.trying
    _rb=0
    case "$(guard_state)" in
      없음) guard_install || exit 1; _rb=1 ;;
      꺼짐) hmgapid enable $GUARD_ID || { echo "보호 모드를 켜지 못함"; exit 1; }; _rb=1 ;;
    esac
    echo "동글 기능을 켬"
    [ $_rb = 1 ] && echo "내비를 재부팅한 뒤 동글을 꽂아 주세요(보호 모드는 재부팅 뒤에 올라옴)"
    ;;
  off)
    : > $BK/dongle.off
    [ "$(guard_state)" = 켜짐 ] && { hmgapid disable $GUARD_ID || echo "보호 모드를 끄지 못함(동글 기능은 꺼짐)"; }
    unload
    echo "동글 기능을 끔(다시 켜려면 on)"
    ;;
  remove)
    _rc=0
    : > $BK/dongle.off
    unload
    if [ -f $GDIR/mod.json ]; then
      hmgapid engine remove $GUARD_ID > $W/guard-remove.txt 2>&1 && echo "보호 모드를 지움" || { echo "보호 모드 지우기 실패"; _rc=1; }
    fi
    wmod_remove || _rc=1
    wifi_unlock && echo "Wi-Fi 잠금 되돌림"
    apon_restore >/dev/null 2>&1
    [ -f $BK/wifi-chip.ours ] && rm -f $WIFI_SEEN $BK/wifi-chip.ours && echo "동글로 만든 HMG-API 칩 기록을 지움"
    if [ $_rc = 0 ]; then
      rm -f $BK/dongle.off $BK/dongle.blocked $BK/dongle.crashes $BK/dongle.trying
      echo "동글 기능을 지움. 내비를 재부팅하면 동글을 쓰기 전 상태입니다(다시 쓰려면 on)."
    else
      echo "일부를 되돌리지 못함(동글 기능은 꺼 둠). 위 줄을 확인해 주세요."
    fi
    status
    exit $_rc
    ;;
  status) ;;
  *) echo "사용법: dongle-ctl.sh on|off|remove|status"; exit 2 ;;
esac
status
exit 0
