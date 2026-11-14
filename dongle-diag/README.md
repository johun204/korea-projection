# USB Wi-Fi 동글 진단 USB

내비에 Wi-Fi 부품이 없는 차(K8 GL3 등)에서 USB Wi-Fi 동글(ipTIME A3000MINI, RTL8812BU)을 쓰려면
그 내비의 커널에 맞춘 드라이버(`88x2bu.ko`)를 빌드해야 한다. 이 USB는 그 빌드에 필요한 정보를 내비에서 읽어 온다.
내비의 파일은 바꾸지 않는다(기록 폴더 `/data/nemesis/kp-dongle-diag`만 만든다).

## 쓰는 법

1. FAT32 USB 맨 위에 `NEMESIS.data`, `NEMESIS.sh`를 복사한다.
2. 내비가 다 켜진 뒤 USB를 꽂고, 실행할지 물으면 **예**. 완료 창이 뜰 때까지(1분쯤) 기다린다.
3. USB를 빼고 **동글을 꽂아 30초** 둔 뒤 동글을 뺀다(동글이 있을 때만. 15분 안에).
4. USB를 다시 꽂고 **예**. 완료 창이 뜨면 뺀다.

USB의 `KP-dongle-diag/run-1`, `run-2`에 결과가 남는다.

## 모으는 것

- 커널 버전·설정(`/proc/version`, `config.gz`), 심볼(`kallsyms`), 올라온 모듈, 부트 파티션(`boot.img`)
- 내비의 `.ko` 파일(vermagic·심볼 버전 확인용), 내장된 USB 드라이버 목록
- USB 장치 목록과 동글을 꽂았을 때의 커널 기록(`prev-usb-watch.txt`, `prev-dmesg-watch.txt`)
- `getprop`, `dmesg`, `logcat` (차대번호 등이 들어 있을 수 있으니 그대로 공개하지 말 것)
