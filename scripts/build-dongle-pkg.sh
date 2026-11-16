#!/bin/sh
# 포크 패키지 만들기: 공식 릴리스 zip(busybox·상태 화면 앱이 든 것)에 이 저장소의 바뀐 파일과 dongle/을 얹는다.
#   sh scripts/build-dongle-pkg.sh <공식 korea.projection-1.7.3.zip> <출력 폴더>
set -e
B=$(cd "$(dirname "$0")/.." && pwd)
BASE=${1:?공식 korea.projection zip}; OUT=${2:?출력 폴더}
P=$B/nemesis-pkg/korea.projection
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/p" "$OUT"; OUT=$(cd "$OUT" && pwd)
(cd "$W/p" && unzip -q "$BASE")
# 공식 zip의 스크립트가 이 저장소의 v1.7.3과 같은지(다른 판 위에 얹지 않게)
for f in svc/hotspot.sh bin/status.sh bin/carreport.sh scripts/post.sh scripts/preun.sh; do
  git -C "$B" show v1.7.3:nemesis-pkg/korea.projection/$f | cmp -s - "$W/p/$f" || { echo "공식 zip이 v1.7.3과 다름: $f" >&2; exit 1; }
done
for f in NEMESIS.data svc/hotspot.sh scripts/post.sh scripts/preun.sh bin/dongle-ctl.sh; do cp "$P/$f" "$W/p/$f"; done
mkdir -p "$W/p/dongle" && cp "$P"/dongle/* "$W/p/dongle/"
VER=$(grep '^package-version=' "$P/NEMESIS.data" | sed 's/^package-version=//')
Z=$OUT/korea.projection-$VER.zip
rm -f "$Z"
(cd "$W/p" && find . -type f | sort | zip -q -X "$Z" -@)
echo "$Z"
