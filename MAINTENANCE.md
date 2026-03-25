# Maintenance Guide

This document covers everything a maintainer needs to know about keeping
`react-native-opaque` up-to-date, re-compiling the Rust static libraries,
and cutting releases.

---

## 1. Protocol version tracking

`react-native-opaque` bundles pre-compiled Rust static libraries that
implement the [OPAQUE](https://www.ietf.org/archive/id/draft-irtf-cfrg-opaque-13.txt)
protocol via the [`opaque-ke`](https://github.com/novifinancial/opaque-ke) crate.
The server side uses the [`@serenity-kit/opaque`](https://github.com/serenity-kit/opaque)
npm package. **Both sides must use the same `opaque-ke` version** because the
wire format is not stable across major versions.

### How to find the required opaque-ke version

```bash
# Fetch the latest @serenity-kit/opaque package metadata from npm
curl -s https://registry.npmjs.org/@serenity-kit/opaque/latest | jq '.version'

# Then inspect the Cargo.toml in the serenity-kit/opaque GitHub repo
# to find which opaque-ke version it depends on:
# https://github.com/serenity-kit/opaque/blob/main/Cargo.toml
```

Once you have the target version, update `rust/Cargo.toml`:

```toml
opaque-ke = { version = "X.Y.Z", features = ["argon2"] }
```

### Version compatibility table

| react-native-opaque | @serenity-kit/opaque | opaque-ke |
|---------------------|----------------------|-----------|
| 0.3.x               | 0.8.x                | 3.0.0-pre.4 |
| 1.0.x               | 1.1.x                | 4.0.0     |


### Useful links

- opaque-ke releases: <https://github.com/novifinancial/opaque-ke/releases>
- opaque-ke crates.io: <https://crates.io/crates/opaque-ke>
- IETF OPAQUE draft: <https://www.ietf.org/archive/id/draft-irtf-cfrg-opaque-13.txt>

---

## 2. Recompiling the Rust static libraries

### Prerequisites

1. Install Rust via [rustup](https://rustup.rs/):

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. Install the `cxxbridge` code generator (needed to regenerate `cpp/opaque-rust.h` and
   `cpp/opaque-rust.cpp`):

   ```bash
   cargo install cxxbridge-cmd
   ```

3. For **iOS builds**: Xcode command-line tools must be installed (`xcode-select --install`).

4. For **Android builds**: Android NDK r26d must be installed.
   Set `ANDROID_HOME` to your SDK root, or set `NDK` to the NDK directory directly.

### Build commands

```bash
# iOS only (runs on macOS)
make build-ios

# Android only (runs on macOS or Linux)
make build-android

# Both platforms
make build-all
```

The `Makefile` calls the scripts in `rust/` and places compiled `.a` files at:

```
rust/target/<triple>/release/libopaque_rust.a
```

iOS targets:
- `aarch64-apple-ios` — physical device (ARM64)
- `aarch64-apple-ios-sim` — simulator on Apple Silicon
- `x86_64-apple-ios` — simulator on Intel

Android targets:
- `aarch64-linux-android` — arm64-v8a
- `arm-linux-androideabi` — armeabi-v7a
- `i686-linux-android` — x86
- `x86_64-linux-android` — x86_64

### Verifying the compiled libraries

**Size sanity check** — a freshly compiled `libopaque_rust.a` for iOS arm64
should be between 1 MB and 5 MB (release + LTO):

```bash
ls -lh rust/target/aarch64-apple-ios/release/libopaque_rust.a
```

**Symbol verification** — confirm that the key OPAQUE entry points are present:

```bash
# macOS / iOS libs
nm rust/target/aarch64-apple-ios/release/libopaque_rust.a | grep opaque_

# Android libs (use the NDK's nm)
$ANDROID_HOME/ndk/26.1.10909125/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-nm \
  rust/target/aarch64-linux-android/release/libopaque_rust.a | grep opaque_
```

You should see symbols including:
- `opaque_start_client_registration`
- `opaque_finish_client_registration`
- `opaque_start_client_login`
- `opaque_finish_client_login`
- `opaque_create_server_setup`
- `opaque_start_server_login`
- `opaque_finish_server_login`

---

## 3. Wire format compatibility

The OPAQUE protocol messages serialized by the Rust library (bundled `.a` files)
**must** be deserializable by the server's `@serenity-kit/opaque` version.
If the two sides use different `opaque-ke` major versions, authentication will
silently fail or throw deserialization errors.

### Why this matters

`opaque-ke` is not wire-stable across major versions. Registrations created
with v3 cannot be completed with v4 (and vice versa). When upgrading, all
existing users must re-register.

### Verifying wire format compatibility

Run the end-to-end web tests against a server that uses the target
`@serenity-kit/opaque` version:

```bash
# Start a server that uses @serenity-kit/opaque@<target>
# (see e2e-tests/web/full-flow.e2e.ts for the test setup)
yarn test:e2e
```

A passing end-to-end test is the definitive proof of wire compatibility.

---

## 4. React Native compatibility

When React Native releases a new major version, check the following:

### iOS (podspec)

- `s.platforms = { :ios => "X.Y" }` — update the minimum iOS version to match
  what the new RN release requires. RN 0.76+ requires iOS 15.1.
- If RN re-introduces or removes dependencies (Folly, boost, etc.), update the
  `if ENV['RCT_NEW_ARCH_ENABLED']` block accordingly.
- Check whether the TurboModules codegen API changed in `ios/Opaque.mm`.
- Reference: [React Native upgrade helper](https://react-native-community.github.io/upgrade-helper/)

### Android

- **AGP version** in `android/build.gradle` (`classpath "com.android.tools.build:gradle:X.Y.Z"`).
- **NDK version** (`ndkVersion` in `android/build.gradle` and
  `NDK_VERSION` in `rust/build-android.sh`). The required NDK version is
  documented in each RN release's Android setup guide.
- **CMakeLists.txt**: If RN changes how JSI is exposed (prefab package name,
  version, or cmake target name), update `find_package(ReactAndroid ...)` and
  `target_link_libraries(... ReactAndroid::jsi ...)`.
- **`minSdk`** may need bumping if RN raises its minimum Android API level.
- **Java version**: RN 0.73+ requires Java 11; future versions may require 17.
- Reference: [React Native upgrade helper](https://react-native-community.github.io/upgrade-helper/)

### Rust / cxx bridge

The generated `cpp/opaque-rust.h` and `cpp/opaque-rust.cpp` files must stay in
sync with `rust/src/lib.rs`. Whenever `lib.rs` changes, regenerate them:

```bash
cd rust && ./gen-cxx.sh
```

---

## 5. Release checklist

Follow these steps in order to cut a new release:

1. **Update `opaque-ke` version** in `rust/Cargo.toml` if needed (see §1).
   Update the version compatibility table in this file.

2. **Update the JS dependency** in `package.json`:
   ```json
   "@serenity-kit/opaque": "^X.Y.Z"
   ```

3. **Update the JS/TS types** in `src/index.ts` if the `@serenity-kit/opaque`
   API changed (compare exported types with the web version in `src/index.web.ts`).

4. **Recompile the Rust libraries**:
   ```bash
   make build-all
   ```

5. **Regenerate the C++ bridge** (already done by `make build-ios`):
   ```bash
   cd rust && ./gen-cxx.sh
   ```

6. **Run CI locally**:
   ```bash
   yarn lint && yarn typecheck && yarn test
   cd rust && cargo clippy --all-targets --all-features -- -D warnings
   ```

7. **Bump the version** in `package.json` (use semver):
   - Patch (`x.y.Z`): security fixes, Rust dependency bumps with no protocol
     changes, build file fixes.
   - Minor (`x.Y.z`): new API surface compatible with the previous version.
   - Major (`X.y.z`): any `opaque-ke` major version bump (wire-breaking).

8. **Commit all changes** (compiled `.a` files, updated `package.json`,
   `Cargo.toml`, `MAINTENANCE.md`, etc.).

9. **Tag the release**:
   ```bash
   git tag v<version>
   git push origin main --tags
   ```
   Pushing a `v*` tag triggers the `release.yml` workflow, which builds all
   targets, publishes to npm with provenance, and creates a GitHub Release.

10. **Verify** the GitHub Actions release workflow completed successfully
    and that the new version appears on npm.

---

## 6. Security response

If a vulnerability is discovered in `opaque-ke` or any other Rust dependency:

### Goal: patch release within 48 hours

1. **Update `rust/Cargo.toml`** with the patched version:
   ```toml
   opaque-ke = { version = "X.Y.Z-patched", features = ["argon2"] }
   ```

2. **Lock the exact version** in `Cargo.lock` to prevent the vulnerable version
   from resolving:
   ```bash
   cd rust && cargo update -p opaque-ke --precise X.Y.Z-patched
   ```

3. **Recompile all targets**:
   ```bash
   make build-all
   ```

4. **Bump the patch version** in `package.json` (e.g. `1.0.0` → `1.0.1`).

5. **Document the CVE** in `CHANGELOG.md` / GitHub release notes, referencing
   the CVE identifier and the affected versions.

6. **Tag and push** to trigger the release workflow:
   ```bash
   git add rust/Cargo.toml rust/Cargo.lock package.json CHANGELOG.md \
       rust/target/*/release/libopaque_rust.a
   git commit -m "fix: patch CVE-YYYY-XXXXX in opaque-ke"
   git tag v<patch-version>
   git push origin main --tags
   ```

7. **Monitor** the `release.yml` workflow run. If it fails, fix the issue and
   re-tag (delete the remote tag first with `git push origin :v<patch-version>`).

8. **Notify** downstream users via a GitHub Security Advisory:
   <https://github.com/serenity-kit/react-native-opaque/security/advisories/new>
