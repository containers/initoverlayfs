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

initoverlayfs-install

