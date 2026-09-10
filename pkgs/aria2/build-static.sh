#!/usr/bin/env bash
set -euo pipefail

: "${ARIA2_SOURCE_DIR:?ARIA2_SOURCE_DIR is required}"
: "${ARIA2_PATCH_DIR:?ARIA2_PATCH_DIR is required}"
: "${ARIA2_OUTPUT:?ARIA2_OUTPUT is required}"
: "${ARIA2_VERSION:?ARIA2_VERSION is required}"

build_root="${RUNNER_TEMP:-/tmp}/aria2-build"
prefix="${RUNNER_TEMP:-/tmp}/aria2-static"
mkdir -p "$build_root" "$prefix" "$(dirname "$ARIA2_OUTPUT")"

latest_tag() {
  local repo="$1"
  local pattern="$2"
  gh api --paginate "repos/${repo}/tags?per_page=100" --jq '.[].name' \
    | grep -E "$pattern" \
    | sort -V \
    | tail -n 1
}

clone_tag() {
  local repo="$1"
  local tag="$2"
  local dest="$3"
  git clone --depth=1 --branch "$tag" "https://github.com/${repo}.git" "$dest"
}

zlib_tag="$(latest_tag madler/zlib '^v[0-9]+\.[0-9]+\.[0-9]+$')"
expat_tag="$(latest_tag libexpat/libexpat '^R_[0-9]+_[0-9]+_[0-9]+$')"
cares_tag="$(latest_tag c-ares/c-ares '^v[0-9]+\.[0-9]+\.[0-9]+$')"
openssl_tag="$(latest_tag openssl/openssl '^openssl-[0-9]+\.[0-9]+\.[0-9]+$')"
sqlite_tag="$(latest_tag sqlite/sqlite '^version-[0-9]+\.[0-9]+\.[0-9]+$')"
libssh2_tag="$(latest_tag libssh2/libssh2 '^libssh2-[0-9]+\.[0-9]+\.[0-9]+$')"
mimalloc_tag="$(latest_tag microsoft/mimalloc '^v[0-9]+\.[0-9]+\.[0-9]+$')"

printf '%s\n' \
  "zlib=$zlib_tag" \
  "expat=$expat_tag" \
  "c-ares=$cares_tag" \
  "openssl=$openssl_tag" \
  "sqlite=$sqlite_tag" \
  "libssh2=$libssh2_tag" \
  "mimalloc=$mimalloc_tag"

export CPPFLAGS="-I$prefix/include"
export LDFLAGS="-L$prefix/lib -L$prefix/lib64 -static"
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig:$prefix/lib64/pkgconfig"
export LD_LIBRARY_PATH="$prefix/lib:$prefix/lib64"
export CC=gcc
export CXX=g++
export STRIP=strip
export RANLIB=ranlib
export AR=ar
export LD=ld

case "$(uname -m)" in
  x86_64)
    export CFLAGS="${CFLAGS:-} -march=x86-64-v3 -flto -O3"
    export CXXFLAGS="${CXXFLAGS:-} -march=x86-64-v3 -flto -O3"
    openssl_target=linux-x86_64
    ;;
  aarch64)
    export CFLAGS="${CFLAGS:-} -flto -O3"
    export CXXFLAGS="${CXXFLAGS:-} -flto -O3"
    openssl_target=linux-aarch64
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

clone_tag openssl/openssl "$openssl_tag" "$build_root/openssl"
cd "$build_root/openssl"
./Configure "$openssl_target" --prefix="$prefix" no-tests no-shared no-module
make -j"$(nproc)"
make install_sw

if [[ -d "$prefix/lib64" && ! -e "$prefix/lib" ]]; then
  ln -s "$prefix/lib64" "$prefix/lib"
fi

clone_tag madler/zlib "$zlib_tag" "$build_root/zlib"
cd "$build_root/zlib"
./configure --prefix="$prefix" --static
make -j"$(nproc)"
make install

clone_tag libexpat/libexpat "$expat_tag" "$build_root/expat"
cmake -S "$build_root/expat/expat" -B "$build_root/expat-build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DEXPAT_SHARED_LIBS=OFF \
  -DEXPAT_BUILD_DOCS=OFF \
  -DEXPAT_BUILD_EXAMPLES=OFF \
  -DEXPAT_BUILD_TESTS=OFF
cmake --build "$build_root/expat-build" --parallel "$(nproc)"
cmake --install "$build_root/expat-build"

clone_tag c-ares/c-ares "$cares_tag" "$build_root/c-ares"
cmake -S "$build_root/c-ares" -B "$build_root/c-ares-build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DCARES_SHARED=OFF \
  -DCARES_STATIC=ON \
  -DCARES_BUILD_TESTS=OFF \
  -DCARES_BUILD_TOOLS=OFF
cmake --build "$build_root/c-ares-build" --parallel "$(nproc)"
cmake --install "$build_root/c-ares-build"

clone_tag sqlite/sqlite "$sqlite_tag" "$build_root/sqlite"
cd "$build_root/sqlite"
./configure --prefix="$prefix" --enable-static --disable-shared --disable-load-extension
make -j"$(nproc)"
make install

clone_tag libssh2/libssh2 "$libssh2_tag" "$build_root/libssh2"
cmake -S "$build_root/libssh2" -B "$build_root/libssh2-build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_TESTING=OFF \
  -DCRYPTO_BACKEND=OpenSSL \
  -DOPENSSL_ROOT_DIR="$prefix"
cmake --build "$build_root/libssh2-build" --parallel "$(nproc)"
cmake --install "$build_root/libssh2-build"

clone_tag microsoft/mimalloc "$mimalloc_tag" "$build_root/mimalloc"
cmake -S "$build_root/mimalloc" -B "$build_root/mimalloc-build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DMI_INSTALL_TOPLEVEL=ON \
  -DMI_USE_CXX=ON \
  -DMI_BUILD_SHARED=OFF \
  -DMI_BUILD_TESTS=OFF
cmake --build "$build_root/mimalloc-build" --parallel "$(nproc)"
cmake --install "$build_root/mimalloc-build"

cd "$ARIA2_SOURCE_DIR"
git apply --check "$ARIA2_PATCH_DIR"/*.patch
git apply "$ARIA2_PATCH_DIR"/*.patch
sed -E -i 's/AM_GNU_GETTEXT_VERSION\(([^)]*)\)/AM_GNU_GETTEXT_REQUIRE_VERSION(\1)/g' configure.ac
autoreconf -fi
./configure \
  --prefix=/usr/local \
  --with-libz \
  --with-libcares \
  --with-libexpat \
  --without-libxml2 \
  --without-libgcrypt \
  --with-openssl \
  --without-libnettle \
  --without-gnutls \
  --without-libgmp \
  --with-libssh2 \
  --with-sqlite3 \
  --with-mimalloc \
  --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
  ARIA2_STATIC=yes \
  --disable-shared
make -j"$(nproc)"

src/aria2c --version | grep -F "aria2 version ${ARIA2_VERSION}"
file src/aria2c | grep -F 'statically linked'
if readelf -l src/aria2c | grep -q INTERP; then
  echo "aria2c is dynamically linked" >&2
  exit 1
fi

install -Dm755 src/aria2c "$ARIA2_OUTPUT"
