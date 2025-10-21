#!/usr/bin/env bash
# This script is supposed to be in .github dir
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ------------------ Configurable variables ------------------
GOARCH=${GOARCH:-arm64}
API=${API:-21}
PREFIX="${SCRIPT_DIR}/android-${GOARCH}"
export PKG_CONFIG_ALLOW_CROSS=1
case "$GOARCH" in
    arm64) ABI="arm64-v8a" ;;
    arm)   ABI="armeabi-v7a" ;;
    386)   ABI="x86" ;;
    amd64) ABI="x86_64" ;;
    *) echo "Unsupported GOARCH: $GOARCH"; exit 1 ;;
esac

case "$GOARCH" in
    arm64) RUST_TARGET="aarch64-linux-android" ;;
    arm)   RUST_TARGET="armv7-linux-androideabi" ;;
    386)   RUST_TARGET="i686-linux-android" ;;
    amd64) RUST_TARGET="x86_64-linux-android" ;;
    *) echo "Unsupported GOARCH: $GOARCH"; exit 1 ;;
esac

OUTPUT="payload_dumper-${ABI}"
RUST_OUTPUT="payload_dumper-${ABI}"

XZ_VERSION=${XZ_VERSION:-5.8.1}
XZ_TAR="xz-${XZ_VERSION}.tar.gz"
XZ_URL="https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/${XZ_TAR}"
ZSTD_REPO=${ZSTD_REPO:-https://github.com/facebook/zstd.git}
ZSTD_DIR="${SCRIPT_DIR}/zstd"
ZSTD_BUILD_DIR="${ZSTD_DIR}/build/meson/builddir"

if [[ -z "$ANDROID_NDK_ROOT" ]]; then
    if [[ -n "$ANDROID_NDK_HOME" ]]; then
        export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME
    fi
fi
export PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH

# ------------------ Determine target triple for NDK ------------------
case "$GOARCH" in
  arm64) TARGET="aarch64-linux-android"; ARCH="aarch64" ;;
  arm)   TARGET="armv7a-linux-androideabi"; ARCH="arm" ;;
  386)   TARGET="i686-linux-android"; ARCH="x86" ;;
  amd64) TARGET="x86_64-linux-android"; ARCH="x86_64" ;;
  *) echo "Unsupported GOARCH: $GOARCH"; exit 1 ;;
esac

CC="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}${API}-clang"
CXX="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}${API}-clang++"
AR="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
NM="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-nm"
RANLIB="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ranlib"
STRIP="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"

CGO_ENABLED=1
GOOS=android
CGO_CFLAGS="-I${PREFIX}/include -I${ZSTD_DIR}/lib"
CGO_LDFLAGS="-L${PREFIX}/lib -llzma -L${ZSTD_BUILD_DIR}/lib -lzstd"

# ------------------ Build liblzma ------------------
build_liblzma() {
  if [ -f "${PREFIX}/lib/liblzma.a" ]; then
    echo "liblzma.a already exists, skipping build"
    return
  fi
  cd "$SCRIPT_DIR"
  [ -f "${XZ_TAR}" ] || curl -L -o "${XZ_TAR}" "${XZ_URL}"
  tar -xf "${XZ_TAR}"
  rm -rf "xz-${XZ_VERSION}/build-android"
  mkdir -p "xz-${XZ_VERSION}/build-android"
  pushd "xz-${XZ_VERSION}/build-android" > /dev/null
  ../configure --host="${TARGET}" --prefix="${PREFIX}" \
    --disable-shared --enable-static --disable-xz --disable-xzdec --disable-lzmadec \
    --disable-lzmainfo --disable-scripts CC="${CC}" CXX="${CXX}"
  make -j"$(nproc)"
  make install
  popd > /dev/null
}

# ------------------ Build Zstandard ------------------
build_zstd() {
  cd "$SCRIPT_DIR"
  [ -d "${ZSTD_DIR}" ] || git clone --depth 1 "${ZSTD_REPO}" "${ZSTD_DIR}"
  rm -rf "${ZSTD_BUILD_DIR}"
  mkdir -p "${ZSTD_BUILD_DIR}"

  # write meson cross file
  cat > "${ZSTD_BUILD_DIR}/cross.txt" <<EOF
[binaries]
c = '${CC}'
cpp = '${CXX}'
ar = '${AR}'
nm = '${NM}'
strip = '${STRIP}'
pkg-config = 'pkg-config'
ranlib = '${RANLIB}'

[built-in options]
c_args = []
cpp_args = []
c_link_args = []
cpp_link_args = []

[host_machine]
system = 'android'
cpu_family = '${ARCH}'
cpu = '${ARCH}'
endian = 'little'
EOF

  pushd "${ZSTD_BUILD_DIR}" > /dev/null
  meson setup .. --cross-file=cross.txt --prefix=$PREFIX --buildtype=release --default-library=static -Dzlib=disabled -Dbin_contrib=false -Dlz4=disabled -Dlzma=disabled 
  ninja -j"$(nproc)"
  ninja install
  popd > /dev/null
}

# ------------------ Build payload-dumper-go ------------------
build_payload_dumper_go() {
  cd "$SCRIPT_DIR"
  [ -f "payload-dumper-go/${OUTPUT}" ] && { echo "${OUTPUT} already exists, skipping build"; return; }
  [ -d "payload-dumper-go" ] || git clone --depth 1 https://github.com/ssut/payload-dumper-go.git
  pushd payload-dumper-go > /dev/null
  GOOS=${GOOS} GOARCH=${GOARCH} CGO_ENABLED=${CGO_ENABLED} \
  CC=${CC} CXX=${CXX} \
  CGO_CFLAGS="${CGO_CFLAGS}" CGO_LDFLAGS="${CGO_LDFLAGS}" \
  go build -v -o "${OUTPUT}"
  popd > /dev/null
}

# ------------------ Build payload-dumper-rust ------------------
build_payload_dumper_rust() {
  cd "$SCRIPT_DIR"
  [ -f "payload-dumper-rust/target/${RUST_TARGET}/release/payload_dumper" ] && {
      echo "${RUST_OUTPUT} already exists, skipping build"
      return
  }
  [ -d "payload-dumper-rust" ] || git clone --depth 1 https://github.com/rhythmcache/payload-dumper-rust.git
  pushd payload-dumper-rust > /dev/null
  rustup target add "$RUST_TARGET" || true
  mkdir -p .cargo
  rm -f .cargo/config.toml
  cat > .cargo/config.toml <<EOF
[target.${RUST_TARGET}]
ar = "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
linker = "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}21-clang"
EOF
  export RUSTFLAGS="-C target-feature=+crt-static -C link-arg=-static"
  RUST_TARGET_UNDERSCORE="${RUST_TARGET//-/_}"
  export CC_${RUST_TARGET_UNDERSCORE}="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}21-clang"
  export CXX_${RUST_TARGET_UNDERSCORE}="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}21-clang++"
  cargo build --release --target "$RUST_TARGET" --all-features
  cp "target/${RUST_TARGET}/release/payload_dumper" "../${RUST_OUTPUT}"
  popd > /dev/null
}

# ------------------ Copy binaries ------------------
copy_bins() {
  mkdir -p "$REPO_ROOT/bins/go"
  mkdir -p "$REPO_ROOT/bins/rust"
  if [ -f "payload-dumper-go/${OUTPUT}" ]; then
      cp "payload-dumper-go/${OUTPUT}" "$REPO_ROOT/bins/go/"
      $STRIP "payload-dumper-go/${OUTPUT}"
      echo "Copied Go binary to $REPO_ROOT/bins/go/${OUTPUT}"
  fi
  if [ -f "payload-dumper-rust/${RUST_OUTPUT}" ]; then
      $STRIP "payload-dumper-rust/${RUST_OUTPUT}"
      cp "payload-dumper-rust/${RUST_OUTPUT}" "$REPO_ROOT/bins/rust/"
      echo "Copied Rust binary to $REPO_ROOT/bins/rust/${RUST_OUTPUT}"
  fi
}

# ------------------ Clean ------------------
clean_all() {
  cd "$SCRIPT_DIR"
  rm -rf "xz-${XZ_VERSION}" "${XZ_TAR}" "${PREFIX}" "${ZSTD_DIR}" "payload-dumper-go" "payload-dumper-rust"
}

# ------------------ Main ------------------
case "${1:-all}" in
    liblzma) build_liblzma ;;
    zstd)    build_zstd ;;
    payload_dumper_go) build_payload_dumper_go ;;
    payload_dumper_rust) build_payload_dumper_rust ;;
    copy_bins) copy_bins ;;
    clean)   clean_all ;;
    all)
        build_liblzma
        build_zstd
        build_payload_dumper_go
        build_payload_dumper_rust
        copy_bins
        ;;
    *)
        echo "Usage: $0 {liblzma|zstd|payload_dumper_go|payload_dumper_rust|copy_bins|all|clean}"
        exit 1
        ;;
esac
