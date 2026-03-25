cmake_minimum_required(VERSION 3.13)
project(opaque)

set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_CXX_STANDARD 17)

# JSI is provided via the ReactAndroid prefab package in RN 0.73+.
# No need to compile jsi.cpp manually or set NODE_MODULES_DIR include paths.
find_package(ReactAndroid REQUIRED CONFIG)

add_library(opaque
  SHARED
  ../cpp/react-native-opaque.cpp
  ../cpp/react-native-opaque.h
  ../cpp/opaque-rust.h
  ../cpp/opaque-rust.cpp
  cpp-adapter.cpp
)

# Set the rust base target dir
set(RUST_BUILD_DIR ${CMAKE_CURRENT_LIST_DIR}/../rust/target)

# Select the rust target dir based on the Android ABI
if(${ANDROID_ABI} STREQUAL arm64-v8a)
  set(RUST_TARGET_DIR ${RUST_BUILD_DIR}/aarch64-linux-android)
elseif(${ANDROID_ABI} STREQUAL armeabi-v7a)
  set(RUST_TARGET_DIR ${RUST_BUILD_DIR}/arm-linux-androideabi)
elseif(${ANDROID_ABI} STREQUAL x86)
  set(RUST_TARGET_DIR ${RUST_BUILD_DIR}/i686-linux-android)
else()
  set(RUST_TARGET_DIR ${RUST_BUILD_DIR}/x86_64-linux-android)
endif()

target_include_directories(opaque PRIVATE ../cpp)

target_link_libraries(opaque
  ${RUST_TARGET_DIR}/release/libopaque_rust.a
  ReactAndroid::jsi
  android
  log
)
