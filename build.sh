#!/usr/bin/env bash

realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
BIN_PATH=$(realpath "$0")
ROOT_DIR=$(dirname $BIN_PATH)
INSTALL_DIR=$ROOT_DIR/install
PATCHELF_VERSION=0.14.5

source ${ROOT_DIR}/tools/style.sh

mkdir -p $INSTALL_DIR
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    info "start install e9path and hopper's e9 plugins ..."
    cd hopper-instrument/e9-mode
    PREFIX=$INSTALL_DIR ./build.sh
    cd ../../

    if [ ! -x $INSTALL_DIR/patchelf ]; then
        info "download patchelf ..."
        cd $INSTALL_DIR
        mkdir -p tmp
        cd tmp
        wget https://github.com/NixOS/patchelf/releases/download/${PATCHELF_VERSION}/patchelf-${PATCHELF_VERSION}-x86_64.tar.gz
        tar -xvf patchelf-${PATCHELF_VERSION}-x86_64.tar.gz
        cp bin/patchelf ../.
    fi
elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # E9Patch only rewrites Linux binaries, so FreeBSD uses LLVM mode only.
    if ! command -v patchelf > /dev/null; then
        warn "patchelf is required: pkg install patchelf"
    fi
    if [ -z "${LLVM_DIR:-}" ]; then
        # The base system clang cannot load pass plugins; use LLVM from ports.
        LLVM_DIR=$(ls -d /usr/local/llvm[0-9]*/lib/cmake/llvm 2>/dev/null | sort -V | tail -1)
        [ -z "$LLVM_DIR" ] && error "LLVM is required: pkg install llvm18" && exit 1
    fi
fi

info "start install hopper's llvm plugins ..."
cd $INSTALL_DIR
rm -rf llvm_build
mkdir llvm_build && cd llvm_build 
cmake ${LLVM_DIR:+-DLLVM_DIR=$LLVM_DIR} -DHOPPER_BIN_DIR=$INSTALL_DIR $ROOT_DIR/hopper-instrument/llvm-mode
cmake --build .
cmake --install .

# BUILD_TYPE=${BUILD_TYPE:-debug}
BUILD_TYPE=${BUILD_TYPE:-release}

info "start build and install hopper fuzzer ..."
cd $ROOT_DIR
if [[ "$BUILD_TYPE" == "debug" ]]; then
    cargo build
else
    cargo build --release
fi

ln -sf $ROOT_DIR/target/$BUILD_TYPE/hopper-compiler $INSTALL_DIR/

info "build and install hopper done!"
