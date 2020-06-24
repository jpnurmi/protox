#!/bin/bash

SODIUM_VERSION=1.0.18
TOXCORE_VERSION=v0.2.12

### Script
COL='\033[1;32m'
COL2='\e[34m'
NC='\033[0m' # No Color

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

INSTALL_DIR=$(pwd)/libs

cd $(dirname "$0")

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
    if [ ! -d "libsodium-android-x86" ] 
    then
        ln -s libsodium-android-i686 libsodium-android-x86
    fi
    if [ ! -d "libsodium-android-x86_64" ] 
    then
        ln -s libsodium-android-westmere libsodium-android-x86_64
    fi    
    cp -v libsodium-android-${TARGET_ARCH}/lib/libsodium.so ${LIBS_INSTALL_DIR}
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
    wget -O scripts.tar.bz2 "https://gitlab.com/Monsterovich/protox/-/raw/master/toxcore-dist-build.tar.bz2" || error
    tar xfv scripts.tar.bz2
    rm scripts.tar.bz2
    SODIUM_HOME=${DEFAULT_DIR}/libsodium ./dist-build/android-${TARGET_ARCH}.sh
    cd ${DEFAULT_DIR}
}

function install_toxcore()
{
    cd libtoxcore
    printf "${COL}Installing libtoxcore${NC}\n"
    if [ ! -d "libtoxcore-android-x86" ] 
    then
        ln -s libtoxcore-android-i686 libtoxcore-android-x86
    fi
    if [ ! -d "libtoxcore-android-x86_64" ] 
    then
        ln -s libtoxcore-android-westmere libtoxcore-android-x86_64
    fi  
    cp -v libtoxcore-android-${TARGET_ARCH}/lib/libtoxcore.so ${LIBS_INSTALL_DIR}
    cp -v libtoxcore-android-${TARGET_ARCH}/lib/libtoxencryptsave.so ${LIBS_INSTALL_DIR}
    cd ${DEFAULT_DIR}
}

case "$1" in
    build_sodium)
        build_sodium
        ;;
    build_toxcore)
        build_sodium
        build_toxcore
        ;;
    install)
        echo "Installing libraries to "${LIBS_INSTALL_DIR}
        build_sodium
        install_sodium
        build_toxcore
        install_toxcore
        ;;
    *)
        echo $"Usage: $0 {build_sodium|build_toxcore|install}"
        exit 1
esac

printf "${COL}Done!${NC}\n"
