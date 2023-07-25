#!/bin/bash

set -ex

release=$(uname -r)

DIR_TO_DUMP_INITRAMFS="/run/initoverlayfs/"
UUID="1dd3a986-997c-0c48-1d1b-b0d0399f3153"


extract_initrd_into_initoverlayfs() {
  mkdir -p "$DIR_TO_DUMP_INITRAMFS"
  mount /dev/disk/by-partuuid/$UUID /run/initoverlayfs/
  cd "$DIR_TO_DUMP_INITRAMFS"
  /usr/lib/dracut/skipcpio /boot/initramfs-$release.img | zcat | cpio -ivd
  cd -
}

cd 
epoch=$(date +%s)
# systemd-analyze > systemd-analyze$epoch.txt
journalctl --output=short-monotonic > journalctl$epoch.txt
journalctl --output=short-monotonic | grep -i "Reached target" > reached_target$epoch.txt
#sed -i "s/UUID=2aadcf0d-81dc-4b21-99ef-74b96bb357ad/# UUID=2aadcf0d-81dc-4b21-99ef-74b96bb357ad/g" /etc/fstab
if false; then
cp mount-sysroot.service /usr/lib/systemd/system/
mkdir -p /usr/lib/dracut/modules.d/00early-boot-service
echo '#!/usr/bin/bash

install() {
    inst_multiple -o \
      "$systemdsystemunitdir"/mount-sysroot.service \
      "$systemdsystemunitdir"/sysinit.target.wants/mount-sysroot.service
}' > /usr/lib/dracut/modules.d/00early-boot-service/module-setup.sh
sed -i "s/initrd-udevadm-cleanup-db.service/initrd-udevadm-cleanup-db.service mount-sysroot.service/g" /usr/lib/systemd/system/initrd-switch-root.target
chcon system_u:object_r:systemd_unit_file_t:s0 /usr/lib/systemd/system/mount-sysroot.service
cd /usr/lib/systemd/system/sysinit.target.wants/
ln -s ../mount-sysroot.service
cd -
systemctl daemon-reload
dracut -f --compress=pigz
fi

UNLOCK_OVERLAYDIR="$DIR_TO_DUMP_INITRAMFS"
extract_initrd_into_initoverlayfs
mkdir -p "$UNLOCK_OVERLAYDIR/upper" "$UNLOCK_OVERLAYDIR/work"
gcc -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra initoverlayfs2init.c -o $DIR_TO_DUMP_INITRAMFS/usr/sbin/initoverlayfs2init
ln -s init /usr/sbin/initoverlayfs2init
dracut -l -f --aggressive-strip --strip initramfs.img
# sed -i '/^initrd /d' /boot/loader/entries/9c03d22e1ec14ddaac4f0dabb884e434-$release.conf

# should be ro rhgb quiet, cannot remount ro, but can fix
sed -i 's#options #options initoverlayfs=UUID=$UUID #g' /boot/loader/entries/9c03d22e1ec14ddaac4f0dabb884e434-$release.conf

