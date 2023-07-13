#!/bin/bash

set -ex

release=$(uname -r)

DIR_TO_DUMP_INITRAMFS="/initoverlayfs/"

extract_initrd_into_initoverlayfs() {
  mkdir -p "$DIR_TO_DUMP_INITRAMFS"
  cd "$DIR_TO_DUMP_INITRAMFS"
  /usr/lib/dracut/skipcpio /boot/initramfs-$release.img | zcat | cpio -ivd
  cd -
}

epoch=$(date +%s)
# systemd-analyze > systemd-analyze$epoch.txt
journalctl --output=short-monotonic > journalctl$epoch.txt
journalctl --output=short-monotonic | grep -i "Reached target" > reached_target$epoch.txt
sed -i "s/UUID=2aadcf0d-81dc-4b21-99ef-74b96bb357ad/# UUID=2aadcf0d-81dc-4b21-99ef-74b96bb357ad/g" /etc/fstab
systemctl daemon-reload
dracut -f --compress=pigz

extract_initrd_into_initoverlayfs

UNLOCK_OVERLAYDIR="/var/tmp/initoverlay"
mkdir -p "$UNLOCK_OVERLAYDIR"
gcc -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra initoverlayfs2init.c -o /usr/sbin/initoverlayfs2init
sed -i '/^initrd /d' /boot/loader/entries/9c03d22e1ec14ddaac4f0dabb884e434-$release.conf

# should be ro rhgb quiet, cannot remount ro, but can fix
sed -i 's#options root=UUID=2f8957f6-9ecd-480f-b738-41d6da946bf4 ro#options root=/dev/vda4 ro rootfstype=ext4 rootwait init=/usr/sbin/initoverlayfs2init#g' /boot/loader/entries/9c03d22e1ec14ddaac4f0dabb884e434-$release.conf

