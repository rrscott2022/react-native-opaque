.PHONY: build-ios build-android build-all

IOS_TARGETS := aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
ANDROID_TARGETS := aarch64-linux-android arm-linux-androideabi i686-linux-android x86_64-linux-android

# Build all iOS static libraries and regenerate the C++ bridge header.
build-ios:
	cd rust && \
	rustup target add $(IOS_TARGETS) && \
	cargo build --target aarch64-apple-ios        --release && \
	cargo build --target aarch64-apple-ios-sim    --release && \
	cargo build --target x86_64-apple-ios         --release && \
	./gen-cxx.sh

# Build all Android static libraries.
build-android:
	cd rust && \
	rustup target add $(ANDROID_TARGETS) && \
	./build-android.sh aarch64-linux-android  && \
	./build-android.sh arm-linux-androideabi  && \
	./build-android.sh i686-linux-android     && \
	./build-android.sh x86_64-linux-android

# Build everything (iOS first so gen-cxx runs once for both platforms).
build-all: build-ios build-android
