#!/system/bin/sh
# USB Wi-Fi 동글 기능 조작 USB(NEMESIS type=execute, root). USB 맨 위에 아래 파일 중 하나만 둔다:
#   kp-dongle-on      켜기(보호 모드가 없으면 넣음, 재부팅 안내)
#   kp-dongle-off     끄기(드라이버를 내리고 보호 모드를 끔)
#   kp-dongle-remove  지우기(동글 때문에 생긴 것을 모두 되돌림, Korea Projection·HMG-API는 그대로)
#   kp-dongle-status  상태만 보기
# 결과는 USB의 KP-dongle-ctl/<동작>-N.txt. 완료 창 = 성공, 실패 창 = 결과 파일을 보세요.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
USB=$(pwd)
CTL=/data/nemesis/apps/korea.projection/bin/dongle-ctl.sh
M=; n=0
for m in on off remove status; do [ -f $USB/kp-dongle-$m ] && { M=$m; n=$((n+1)); }; done
mkdir -p $USB/KP-dongle-ctl
N=1; while [ -e $USB/KP-dongle-ctl/${M:-none}-$N.txt ]; do N=$((N+1)); done
O=$USB/KP-dongle-ctl/${M:-none}-$N.txt
if [ $n != 1 ]; then echo "USB 맨 위에 kp-dongle-on/off/remove/status 중 하나만 두세요(지금 $n개)" > $O; exit 1; fi
if [ ! -f $CTL ]; then echo "이 내비의 Korea Projection에 동글 기능이 없습니다(동글 지원 판을 설치해 주세요)" > $O; exit 1; fi
{ echo "# $(date) dongle-ctl $M"; /system/bin/sh $CTL $M; echo "rc=$?"; } > $O 2>&1
sync
grep -q '^rc=0$' $O
