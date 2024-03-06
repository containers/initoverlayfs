#!/bin/bash

set -ex

REL="$(git tag | tail -1)"
mkdir -p "$HOME/rpmbuild/SOURCES/"
git archive -o "$HOME/rpmbuild/SOURCES/initoverlayfs-$REL.tar.gz" --prefix "initoverlayfs-$REL/" HEAD
./build-scripts/create-spec.sh
rpmbuild_output=$(rpmbuild -bb initoverlayfs.spec 2>&1)
rpm_to_install=$(echo "$rpmbuild_output" | grep "Wrote:" | awk '{print $2}')
if rpm -Uvh "$rpm_to_install"; then
  echo "$rpmbuild_output"
fi

if [ "$1" = "rootfs" ]; then
  head -c $2 /dev/urandom > /usr/bin/binary
  cp binary-reader.service /usr/lib/systemd/system/
  gcc -O3 read.c -o /usr/bin/binary-reader
  systemctl enable binary-reader.service
elif [ "$1" = "initrd" ]; then
  systemctl disable binary-reader.service
  dracut -f
elif [ "$1" = "initoverlayfs" ]; then
  initoverlayfs-install -f --initoverlayfs-init
fi

