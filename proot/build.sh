#!/bin/bash
set -e
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../config"

cd "$BUILD_DIR"

# Get talloc
if [ ! -d "talloc-$TALLOC_V" ]; then
  wget -O - "https://download.samba.org/pub/talloc/talloc-$TALLOC_V.tar.gz" | tar -xzv
fi

# Get proot
if [ ! -d "proot-$PROOT_V" ]; then
  wget -O - "https://github.com/termux/proot/archive/v$PROOT_V.tar.gz" | tar -xzv
fi

# Make talloc static
cd "$BUILD_DIR/talloc-$TALLOC_V"
DEF_CFLAGS="$CFLAGS"

for ARCH in $ARCHS; do
  set-arch $ARCH

  FILE_OFFSET_BITS='OK'
  export CFLAGS="$DEF_CFLAGS"
  make distclean || true

  cat > cross-answers.txt <<EOF
Checking uname sysname type: "Linux"
Checking uname machine type: "dontcare"
Checking uname release type: "dontcare"
Checking uname version type: "dontcare"
Checking simple C program: OK
rpath library support: OK
-Wl,--version-script support: FAIL
Checking getconf LFS_CFLAGS: OK
Checking for large file support without additional flags: OK
Checking for -D_FILE_OFFSET_BITS=64: $FILE_OFFSET_BITS
Checking for -D_LARGE_FILES: OK
Checking correct behavior of strtoll: OK
Checking for working strptime: OK
Checking for C99 vsnprintf: OK
Checking for HAVE_SHARED_MMAP: OK
Checking for HAVE_MREMAP: OK
Checking for HAVE_INCOHERENT_MMAP: OK
Checking for HAVE_SECURE_MKSTEMP: OK
Checking getconf large file support flags work: OK
Checking for HAVE_IFACE_IFCONF: FAIL
EOF

  # A workaround for badly broken talloc cross-compile option
  export PATH="$BASE_DIR/target-mock-bin:$PATH"

  ./configure build \
    "--prefix=$INSTALL_ROOT" \
    --disable-rpath \
    --disable-python \
    --cross-compile \
    --cross-answers=cross-answers.txt

  mkdir -p "$STATIC_ROOT/include" "$STATIC_ROOT/lib"

  "$AR" rcs "$STATIC_ROOT/lib/libtalloc.a" bin/default/talloc*.o
  cp -f talloc.h "$STATIC_ROOT/include"
done

# Make PRoot
cd "$BUILD_DIR/proot-$PROOT_V/src"

for ARCH in $ARCHS; do
  set-arch "$ARCH"

  export CFLAGS="-I$STATIC_ROOT/include -Werror=implicit-function-declaration"
  export LDFLAGS="-L$STATIC_ROOT/lib"
  export PROOT_UNBUNDLE_LOADER='../libexec/proot'

  make distclean || true
  make V=1 "PREFIX=$INSTALL_ROOT" install
  make distclean || true
  CFLAGS="$CFLAGS -DUSERLAND" make V=1 "PREFIX=$INSTALL_ROOT" proot
  cp -a ./proot "$INSTALL_ROOT/bin/proot-userland"

  (
    cd "$INSTALL_ROOT/bin"
    for FN in *; do
      "$STRIP" "$FN"
    done
  )

  (
    cd "$INSTALL_ROOT/bin/$PROOT_UNBUNDLE_LOADER"
    for FN in *; do
      "$STRIP" "$FN"
    done
  )
done

# Patch binaries to make them execute from native library path
for ARCH in $ARCHS; do
  set-arch "$ARCH"

  mv "$INSTALL_ROOT/bin/proot-userland" "$INSTALL_ROOT/libproot-bin.so"
  mv "$INSTALL_ROOT/libexec/proot/loader" "$INSTALL_ROOT/libproot-loader.so"
  mv "$INSTALL_ROOT/libexec/proot/loader32" "$INSTALL_ROOT/libproot-loader32.so" || true

  # Create wrapper script
  cat > "$INSTALL_ROOT/libproot.so" <<'EOF'
#!/system/bin/sh
dir="$(cd "$(dirname "$0")"; pwd)"
unset LD_PRELOAD
export LD_LIBRARY_PATH="$dir"
export PROOT_LOADER="$dir/libproot-loader.so"
export PROOT_LOADER_32="$dir/libproot-loader32.so"
exec "$dir/libproot-bin.so" "$@"
EOF

  chmod 755 "$INSTALL_ROOT/libproot.so"
  dos2unix "$INSTALL_ROOT/libproot.so"

  rm -rf "$INSTALL_ROOT/bin" "$INSTALL_ROOT/libexec"
done

# Pack
for ARCH in $ARCHS; do
  echo "For $ARCH:"
  set-arch "$ARCH"
  tar -cvf "$PKG_DIR/proot-android-$ARCH.tar" -C "$INSTALL_ROOT" .
done
