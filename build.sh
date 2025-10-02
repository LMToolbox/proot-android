#!/bin/bash

set -e

./get-talloc.sh
./get-proot.sh
./make-talloc-static.sh
./make-proot.sh
./patch.sh
./pack.sh
