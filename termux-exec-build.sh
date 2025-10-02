#!/data/data/com.termux/files/usr/bin/bash

set -e

. ./config

if [ -d "termux-exec-package-$TERMUX_EXEC_V" ] ; then exit 0 ; fi
wget -O - https://github.com/termux/termux-exec-package/archive/v${TERMUX_EXEC_V}.tar.gz | tar -xzv

cd "termux-exec-package-$TERMUX_EXEC_V"

export TERMUX_APP__PACKAGE_NAME=$PKGNAME TERMUX__ROOTFS=/data/data/$PKGNAME/files

make
make packaging-debian-build

ls
ls build
ls build/output

cp build/output/* "/workspace/out"