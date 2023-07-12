#!/bin/bash

set -ex

release=$(uname -r)

extract_initrd_into_initoverlayfs() {
  cd /boot/initoverlayfs/
  /usr/lib/dracut/skipcpio /boot/initramfs-$release.img | zcat | cpio $1 
  cd -
}

extract_initrd_into_initoverlayfs "-ivd"
gcc -O3 -pedantic -Wall -Wextra initoverlayfs2init.c -o /boot/initoverlayfs/usr/bin/initoverlayfs2init
sed -i '/^initrd /d' /boot/loader/entries/9c03d22e1ec14ddaac4f0dabb884e434-$release.conf
sed -i 's#options root=UUID=2f8957f6-9ecd-480f-b738-41d6da946bf4 ro rhgb quiet#root=/dev/vda3 ro rhgb quiet rootfstype=ext4 rootwait init=/usr/bin/initoverlayfs2init#g' /boot/loader/entries/9c03d22e1ec14ddaac4f0dabb884e434-$release.conf
sed -i "s/UUID=2aadcf0d-81dc-4b21-99ef-74b96bb357ad/# UUID=2aadcf0d-81dc-4b21-99ef-74b96bb357ad/g" /etc/fstab
systemctl daemon-reload
dracut -f
extract_initrd_into_initoverlayfs "-iv" # a second time to get the new fstab into initoverlayfs

