#!/bin/bash -eux

mv -v ./build/* ./output/
rmdir ./build

cd ./output || exit 1

find . -name "packer-*" -exec sh -c 'mv -v "$1" "$(echo "$1" | sed s/packer-//g)"' _ {} \;
find . -name "*.mf" -exec sed -i.bak 's/packer-ubuntu-/ubuntu-/g' {} \;
find . -name "*.bak" -exec rm -rvf {} \;
find . -type f ! -name "*.sha256" -exec sha256sum {} \; > "${BUILD_NAME}.sha256"

cd .. || exit 1

exit 0
