#!/bin/bash

TARGET="$1"

if [ "$TARGET" = "" ]; then
    echo "missing argument TARGET"
    echo "Usage: $0 TARGET"
    exit 1
fi

NDK_TARGET=$TARGET

if [ "$TARGET" = "arm-linux-androideabi" ]; then
    NDK_TARGET="armv7a-linux-androideabi"
fi

API_VERSION="24"
NDK_VERSION="27.1.12297006"

# Detect host platform
if [ "$(uname)" = "Darwin" ]; then
    NDK_HOST="darwin-x86_64"
else
    NDK_HOST="linux-x86_64"
fi

# Allow overriding NDK path from CI
if [ -z "$NDK" ]; then
  NDK="$ANDROID_HOME/ndk/$NDK_VERSION"
fi

TOOLS="$NDK/toolchains/llvm/prebuilt/$NDK_HOST"

AR=$TOOLS/bin/llvm-ar \
CXX=$TOOLS/bin/${NDK_TARGET}${API_VERSION}-clang++ \
RANLIB=$TOOLS/bin/llvm-ranlib \
CXXFLAGS="--target=$NDK_TARGET" \
cargo build --target $TARGET --release $EXTRA_ARGS
