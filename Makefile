.PHONY: build-ios build-android build-all \
        docker-build-android docker-shell

IOS_TARGETS    := aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
ANDROID_TARGETS := aarch64-linux-android arm-linux-androideabi i686-linux-android x86_64-linux-android

DOCKER_IMAGE   := react-native-opaque-android-builder
DOCKER_FILE    := docker/Dockerfile.android

# ---------------------------------------------------------------------------
# Native builds (require toolchain installed locally / in CI)
# ---------------------------------------------------------------------------

# Build all iOS static libraries and regenerate the C++ bridge header.
# Requires: macOS + Rust + iOS targets (see MAINTENANCE.md §2)
build-ios:
	cd rust && \
	rustup target add $(IOS_TARGETS) && \
	cargo build --target aarch64-apple-ios        --release && \
	cargo build --target aarch64-apple-ios-sim    --release && \
	cargo build --target x86_64-apple-ios         --release && \
	./gen-cxx.sh

# Build all Android static libraries (native, no Docker).
build-android:
	cd rust && \
	rustup target add $(ANDROID_TARGETS) && \
	./build-android.sh aarch64-linux-android  && \
	./build-android.sh arm-linux-androideabi  && \
	./build-android.sh i686-linux-android     && \
	./build-android.sh x86_64-linux-android

# Build everything — iOS first so gen-cxx runs once for both platforms.
build-all: build-ios build-android

# ---------------------------------------------------------------------------
# Docker-based Android builds (no local Rust/NDK required)
# ---------------------------------------------------------------------------

# Build (or rebuild) the Docker image.
docker-image:
	docker build -f $(DOCKER_FILE) -t $(DOCKER_IMAGE) .

# Build all Android .a files inside Docker, output lands in rust/target/.
docker-build-android: docker-image
	docker run --rm \
	  -v "$(CURDIR)/rust:/build/rust" \
	  -v "$(CURDIR)/cpp:/build/cpp" \
	  -v "$(CURDIR)/Makefile:/build/Makefile:ro" \
	  -w /build \
	  $(DOCKER_IMAGE) \
	  make build-android

# Drop into an interactive shell inside the builder image for debugging.
docker-shell: docker-image
	docker run --rm -it \
	  -v "$(CURDIR)/rust:/build/rust" \
	  -v "$(CURDIR)/cpp:/build/cpp" \
	  -v "$(CURDIR)/Makefile:/build/Makefile:ro" \
	  -w /build \
	  $(DOCKER_IMAGE) \
	  bash
