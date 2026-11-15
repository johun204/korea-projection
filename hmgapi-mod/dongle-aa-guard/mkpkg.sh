#!/bin/sh
# 서명된 HMG-API 모드 zip 만들기(HMG-API 1.0.2의 mkmodpkg.sh와 같은 방식). build.sh를 먼저 돌린다.
#   HMGAPI_ENGINE=<HMG-API v1.0.2의 out/engine-host> sh mkpkg.sh <작성자 키> <출력 폴더>
set -e
cd "$(dirname "$0")"
KEY=${1:?작성자 키}; OUT=${2:?출력 폴더}
CP=${HMGAPI_ENGINE:?HMG-API engine-host 클래스 폴더}
ID=$(sed -n 's/.*"id": *"\([^"]*\)".*/\1/p' mod.json | head -1)
VER=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' mod.json | head -1)
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/$ID" "$OUT"
cp build/mod.json build/hooks.jar "$W/$ID/"
java -cp "$CP" hmgapi.engine.Signing sign "$W/$ID" "$KEY"
Z=$(cd "$OUT" && pwd)/$ID-$VER.zip
rm -f "$Z"
(cd "$W/$ID" && find . -type f | sort | TZ=UTC xargs touch -d 2026-01-01T00:00:00 && find . -type f | sort | zip -q -X -D "$Z" -@)
java -cp "$CP" hmgapi.engine.Signing verify "$W/$ID"
echo "$Z"
