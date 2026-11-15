#!/bin/sh
# hooks.jar 만들기: HMG-API 런타임(소스)에 맞춰 컴파일한다(런타임은 hooks.jar에 넣지 않음).
#   HMGAPI_SRC=<HMG-API 소스> ANDROID_HOME=<SDK> sh build.sh
set -e
cd "$(dirname "$0")"
HS=${HMGAPI_SRC:?HMG-API 소스 폴더}
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}
AJ=$(ls -d $SDK/platforms/android-*/android.jar | tail -1)
D8=$(ls -d $SDK/build-tools/*/d8 | tail -1)
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p $W/stubs $W/rt $W/c
javac --release 8 -Xlint:-options -nowarn -cp "$AJ" -d $W/stubs $(find "$HS/core/runtime/stubs" -name '*.java')
javac --release 8 -Xlint:-options -nowarn -cp "$AJ:$W/stubs" -d $W/rt $(find "$HS/core/runtime/java" -name '*.java')
javac --release 8 -Xlint:-options -Xlint:-deprecation -cp "$AJ:$W/rt" -d $W/c $(find src -name '*.java')
"$D8" --release --min-api 19 --lib "$AJ" --classpath $W/rt --classpath $W/stubs --output $W $(find $W/c -name '*.class')
mkdir -p build && rm -f build/hooks.jar
(cd $W && zip -q -X hooks.jar classes.dex) && cp $W/hooks.jar build/hooks.jar
cp mod.json build/
echo "만듦: build/hooks.jar"
