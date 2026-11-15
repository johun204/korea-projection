USB Wi-Fi 동글(포크 추가)
- 88x2bu.ko: Realtek RTL8812BU 드라이버(morrownr/88x2bu-20210702, GPL-2.0). K8 GL3 커널 3.18.24-tcc용
  (빌드·검증: dongle-build/). kernel.txt와 /proc/version이 글자까지 같을 때만 서비스가 올린다.
- kp-dongle-aa-guard.zip: 순정 안드로이드 오토가 동글을 폰으로 보고 연결 요청을 보내지 않게 하는 HMG-API 모드
  (hmgapi-mod/dongle-aa-guard). 이 모드가 설치·켜짐일 때만 서비스가 동글을 쓴다.
