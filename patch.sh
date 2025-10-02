#!/bin/bash

# Patch binaries to make them execute from native library path

mv $INSTALL_ROOT/bin/proot-userland $INSTALL_ROOT/libproot-bin.so
mv $INSTALL_ROOT/libexec/proot/loader $INSTALL_ROOT/libproot-loader.so
mv $INSTALL_ROOT/libexec/proot/loader32 $INSTALL_ROOT/libproot-loader32.so || true

# Create wrapper script
cat > "$DIST_DIR/libproot.so" <<EOF
#!/system/bin/sh
dir="\$(cd "\$(dirname "\$0")"; pwd)"
unset LD_PRELOAD
export LD_LIBRARY_PATH="\$dir"
export PROOT_LOADER="\$dir/libproot-loader.so"
export PROOT_LOADER_32="\$dir/libproot-loader32.so"
exec "\$dir/libproot-bin.so" "\$@"
EOF

chmod 755 "$DIST_DIR/libproot.so"
dos2unix "$DIST_DIR/libproot.so"

rm -rf $INSTALL_ROOT/bin
rm -rf $INSTALL_ROOT/libexec