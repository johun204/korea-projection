FROM --platform=linux/amd64 ubuntu:20.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential bc make perl python2 python3 curl ca-certificates git kmod binutils file xz-utils lib32z1 libc6-i386 lib32stdc++6 && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /opt/gcc47 /opt/gcc49 \
 && curl -fsSL "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.7/+archive/refs/tags/android-4.4.4_r2.tar.gz" | tar -xz -C /opt/gcc47 \
 && curl -fsSL "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/tags/android-7.1.2_r36.tar.gz" | tar -xz -C /opt/gcc49
