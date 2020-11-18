#!/bin/bash -eux

mv -v ./build/* ./output/
rmdir ./build

cd ./output || exit 1

find . -name "packer-*" -exec sh -c 'mv -v "$1" "$(echo "$1" | sed s/packer-//g)"' _ {} \;
find . -type f ! -name "*.sha256" -exec sha256sum {} \; > "${PACKER_BUILD_NAME}.sha256"

cd .. || exit 1

exit 0
