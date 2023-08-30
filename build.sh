#!/bin/bash

set -ex

release=$(uname -r)

DIR_TO_DUMP_INITRAMFS="/run/initoverlayfs"
UUID="1dd3a986-997c-0c48-1d1b-b0d0399f3153"

extract_initrd_into_initoverlayfs() {
  sudo mkdir -p "$DIR_TO_DUMP_INITRAMFS"

  if command -v mkfs.erofs; then
    cd /run/initoverlayfs/
    sudo /usr/lib/dracut/skipcpio /boot/initramfs-$release.img | zcat | sudo cpio -ivd
  else
    echo "ext4 support unsupported, to add later"
    exit 0

    mkfs.ext4 /dev/disk/by-partuuid/$UUID
    $mkfs /dev/disk/by-partuuid/$UUID
    mount /dev/disk/by-partuuid/$UUID /run/initoverlayfs/
    cd "$DIR_TO_DUMP_INITRAMFS"
    sudo /usr/lib/dracut/skipcpio /boot/initramfs-$release.img | zcat | sudo cpio -ivd
    cd -
  fi
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
sudo mkdir -p "$UNLOCK_OVERLAYDIR/upper" "$UNLOCK_OVERLAYDIR/work"
cd ~/git/initoverlayfs
sudo clang -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra -Werror pre-initoverlayfs.c -o /usr/sbin/pre-initoverlayfs
sudo gcc -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra -Werror -fanalyzer pre-initoverlayfs.c -o /usr/sbin/pre-initoverlayfs
# sudo valgrind /usr/sbin/pre-initoverlayfs
# sudo ln -sf pre-initoverlayfs $DIR_TO_DUMP_INITRAMFS/usr/sbin/init
# sudo ln -sf usr/bin/pre-initoverlayfs $DIR_TO_DUMP_INITRAMFS/init
sudo mkfs.erofs /boot/initoverlayfs-$release.img /run/initoverlayfs/
# ln -s init /usr/sbin/pre-initoverlayfs
initramfs=$(sudo ls /boot/initramfs-* | grep -v rescue | head -n1)
sudo cp -r lib/dracut/modules.d/81pre-initramfs /usr/lib/dracut/modules.d/
sudo dracut -l -f --strip $initramfs # sudo dracut -m kernel-modules -f --strip a.img -M -o nss-softokn --kernel-only
# sed -i '/^initrd /d' /boot/loader/entries/9c03d22e1ec14ddaac4f0dabb884e434-$release.conf

boot_partition=$(mount | grep "on /boot type" | awk '{print $1}')
bls_file=$(sudo ls /boot/loader/entries/ | grep -v rescue | head -n1)
# should be ro rhgb quiet, cannot remount ro, but can fix
sudo sed -i "s#options #options initoverlayfs=$boot_partition:initoverlayfs-$release.img rdinit=/usr/sbin/pre-initoverlayfs #g" /boot/loader/entries/$bls_file
sudo sed -i "s/ rhgb quiet//g" /boot/loader/entries/$bls_file
sudo cat /boot/loader/entries/$bls_file
sudo lsinitrd | grep "initoverlayfs\|boot\|blkid\|udev"

