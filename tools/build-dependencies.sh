#!/bin/bash

SODIUM_VERSION=1.0.18
TOXCORE_VERSION=v0.2.11
OPUS_VERSION=v1.1.2

COL='\033[1;32m'
COL2='\e[34m'
NC='\033[0m' # No Color

TOOLS_DIR=$(pwd)/tools
INSTALL_DIR=$(pwd)/libs

cd $(dirname "$0")

case "$1" in
    clean)
        printf "${COL}Cleaning up.${NC}\n"
        rm -rf .build-deps
        printf "${COL}Done!${NC}\n"
        exit 0
        ;;
esac

if test -z "$TARGET_ARCH"
then
    echo "You should set TARGET_ARCH to required architecture (armv7-a, armv8-a, x86, x86_64)."
    exit 1
fi

if test -z "$ANDROID_NDK_HOME"
then
    echo "You should set ANDROID_NDK_HOME to the directory containing the Android NDK."
    exit 1
fi

mkdir -p .build-deps
cd .build-deps

DEFAULT_DIR=$(pwd)

LIBS_INSTALL_DIR="${INSTALL_DIR}/${TARGET_ARCH}"
mkdir -p ${LIBS_INSTALL_DIR}
echo "Target architecture: "${TARGET_ARCH}

function error()
{
    echo "Operation failed."
    exit 1
}

### libsodium

function build_sodium()
{
    printf "${COL2}Using sodium version:${NC} "${SODIUM_VERSION}"\n"
    printf "${COL}Building libsodium${NC}\n"
    if [ ! -d "libsodium" ] 
    then
        git clone https://github.com/jedisct1/libsodium libsodium || error
    fi
    cd libsodium
    git checkout ${SODIUM_VERSION} || error
    sh autogen.sh
    LIBSODIUM_FULL_BUILD=1 ./dist-build/android-${TARGET_ARCH}.sh
    cd ${DEFAULT_DIR}
}

function install_sodium()
{
    cd libsodium
    printf "${COL}Installing libsodium${NC}\n"
    ln -sf libsodium-android-i686 libsodium-android-x86
    ln -sf libsodium-android-westmere libsodium-android-x86_64
    cp -v libsodium-android-${TARGET_ARCH}/lib/libsodium.so ${LIBS_INSTALL_DIR}
    cd ${DEFAULT_DIR}
}

### libvpx

function build_vpx()
{
    #printf "${COL2}Using libvpx version:${NC} "${TOXCORE_VERSION}"\n"
    printf "${COL}Building libvpx${NC}\n"
    if [ ! -d "libvpx" ] 
    then
        git clone https://github.com/cmeng-git/vpx-android libvpx || error
    fi
    cd libvpx
    if [ "$TARGET_ARCH" = "armv7-a" ]; then
        export VPX_ARCH="armeabi-v7a"
    else
        export VPX_ARCH=${TARGET_ARCH}
    fi
    if [ ! -d "_settings.sh.bak" ] 
    then
        cp _settings.sh _settings.sh.bak
    else
        cp _settings.sh.bak _settings.sh
    fi
    sed -i -e 's/ABIS=("armeabi-v7a" "arm64-v8a" "x86" "x86_64")/ABIS=("${VPX_ARCH}")/g' _settings.sh
    bash init_libvpx.sh
    ANDROID_NDK=${ANDROID_NDK_HOME} bash build-libvpx4android.sh
    cd ${DEFAULT_DIR}
}

### libopus

function build_opus()
{
    printf "${COL2}Using opus version:${NC} "${OPUS_VERSION}"\n"
    printf "${COL}Building libopus${NC}\n"
    if [ ! -d "libopus" ] 
    then
        git clone https://github.com/xiph/opus libopus || error
    fi
    cd libopus
    git checkout ${OPUS_VERSION} || error
    sh autogen.sh
    tar xfv ${TOOLS_DIR}/dist-build-libopus.tar.bz2 -C .
    ./dist-build/android-${TARGET_ARCH}.sh
    cd ${DEFAULT_DIR}
}

function install_opus()
{
    cd libopus
    printf "${COL}Installing libopus${NC}\n"
    ln -sf libopus-android-i686 libopus-android-x86
    ln -sf libopus-android-westmere libopus-android-x86_64
    cp -v libopus-android-${TARGET_ARCH}/lib/libopus.so ${LIBS_INSTALL_DIR}
    cd ${DEFAULT_DIR}
}

### toxcore

function build_toxcore()
{
    printf "${COL2}Using toxcore version:${NC} "${TOXCORE_VERSION}"\n"
    printf "${COL}Building libtoxcore${NC}\n"
    if [ ! -d "libtoxcore" ] 
    then
        git clone https://github.com/TokTok/c-toxcore libtoxcore || error
    fi
    cd libtoxcore
    git checkout ${TOXCORE_VERSION} || error
    sh autogen.sh
    tar xfv ${TOOLS_DIR}/dist-build-libtoxcore.tar.bz2 -C .
    OPUS_HOME=${DEFAULT_DIR}/libopus VPX_HOME=${DEFAULT_DIR}/libvpx/output/android SODIUM_HOME=${DEFAULT_DIR}/libsodium ./dist-build/android-${TARGET_ARCH}.sh
    cd ${DEFAULT_DIR}
}

function install_toxcore()
{
    cd libtoxcore
    printf "${COL}Installing libtoxcore${NC}\n"
    ln -sf libtoxcore-android-i686 libtoxcore-android-x86
    ln -sf libtoxcore-android-westmere libtoxcore-android-x86_64
    cp -v libtoxcore-android-${TARGET_ARCH}/lib/libtoxcore.so ${LIBS_INSTALL_DIR}
    cp -v libtoxcore-android-${TARGET_ARCH}/lib/libtoxencryptsave.so ${LIBS_INSTALL_DIR}
    cp -v libtoxcore-android-${TARGET_ARCH}/lib/libtoxav.so ${LIBS_INSTALL_DIR}
    cd ${DEFAULT_DIR}
}

case "$1" in
    install_sodium)
        build_sodium
        install_sodium
        ;;
    install_vpx)
        build_vpx
        ;;
    install_opus)
        build_opus
        install_opus
        ;;
    install_toxcore)
        build_toxcore
        install_toxcore
        ;;
    install)
        echo "Installing libraries to "${LIBS_INSTALL_DIR}
        build_sodium
        install_sodium
        build_opus
        install_opus
        build_vpx
        build_toxcore
        install_toxcore
        ;;
    *)
        echo $"Usage: $0 {install_sodium|install_vpx|install_opus|install_toxcore|install|clean}"
        exit 1
esac

printf "${COL}Done!${NC}\n"
