#!/data/data/com.termux/files/usr/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/config"

if [ -d "termux-core-package-$TERMUX_CORE_V" ] ; then exit 0 ; fi
wget -O - https://github.com/termux/termux-core-package/archive/v${TERMUX_CORE_V}.tar.gz | tar -xzv

cd "termux-core-package-$TERMUX_CORE_V"
git clone https://github.com/termux/termux-packages.git
export TERMUX_PKGS__BUILD__REPO_ROOT_DIR="$(realpath "./termux-packages")"
make
make install

if [ -d "termux-exec-package-$TERMUX_EXEC_V" ] ; then exit 0 ; fi
wget -O - https://github.com/termux/termux-exec-package/archive/v${TERMUX_EXEC_V}.tar.gz | tar -xzv

cd "termux-exec-package-$TERMUX_EXEC_V"

export TERMUX_APP__PACKAGE_NAME=$PKGNAME TERMUX__ROOTFS=/data/data/$PKGNAME/files

make
make packaging-debian-build

ls
ls build
ls build/output/tmp
ls build/output/usr

cp build/output/packaging/* "/workspace/out"