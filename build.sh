#!/bin/bash

set -e

failure() {
  local lineno=$1
  local msg=$2
  echo "Failed at $lineno: $msg"
}

trap 'failure ${LINENO} "$BASH_COMMAND"' ERR


release=$(uname -r)

DIR_TO_DUMP_INITRAMFS="/run/initoverlayfs"
#UUID="1dd3a986-997c-0c48-1d1b-b0d0399f3153"

fs="erofs"

extract_initrd_into_initoverlayfs() {
  sudo mkdir -p "$DIR_TO_DUMP_INITRAMFS"

  file_type=$(file /boot/initramfs-$release.img)
  decompressor="lz4cat"
  decompressor_dracut="--lz4"
  if [[ "$file_type" == *"ASCII cpio archive (SVR4 with no CRC)"* ]]; then
    decompressor_dracut=""
    decompressor="zcat"
  elif [[ "$file_type" == *"regular file, no read permission"* ]]; then
    decompressor_dracut=""
    decompressor="zcat"
  fi

  if command -v mkfs.erofs; then
    cd /run/initoverlayfs/
    sudo /usr/lib/dracut/skipcpio /boot/initramfs-$release.img | $decompressor | sudo cpio -ivd
    cd -
  else
    fs="ext4"
    dd if=/dev/zero of=/boot/initoverlayfs-$release.img bs=64M count=1
    dev=$(sudo losetup -fP --show /boot/initoverlayfs-$release.img)
    sudo mkfs.$fs $dev
    sudo mount $dev "$DIR_TO_DUMP_INITRAMFS"
    cd "$DIR_TO_DUMP_INITRAMFS"
    sudo /usr/lib/dracut/skipcpio /boot/initramfs-$release.img | zstd -d --stdout | sudo cpio -ivd
    sudo sync
    cd -
    while ! sudo umount "$DIR_TO_DUMP_INITRAMFS"; do
      sleep 1
    done

    sudo losetup -d $dev
  fi
}

cd 
#epoch=$(date +%s)
# systemd-analyze > systemd-analyze$epoch.txt
#journalctl --output=short-monotonic > journalctl$epoch.txt
#journalctl --output=short-monotonic | grep -i "Reached target" > reached_target$epoch.txt
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
du -sh /boot/initramfs*
dracut -f --lz4
fi

set -ex

cd ~/git/initoverlayfs
if [ "$2" = "initramfs" ]; then
  sudo clang -O3 -pedantic -Wall -Wextra -Werror -Wno-language-extension-token pre-init.c -o /usr/sbin/pre-init
  sudo gcc -O3 -pedantic -Wall -Wextra -Werror -Wno-language-extension-token -fanalyzer pre-init.c -o /usr/sbin/pre-init

  sudo cp -r lib/dracut/modules.d/81pre-initoverlayfs /usr/lib/dracut/modules.d/
  sudo cp -r lib/dracut/modules.d/81kamoso /usr/lib/dracut/modules.d/
  du -sh /boot/initramfs*
  sudo dd if=/dev/urandom of=/usr/bin/random-file count=1 bs="$1"
  sudo dracut --lz4 -v -f --strip -f -M
  exit 0
fi

# sudo lsinitrd | grep "init\|boot\|overlay\|erofs"

UNLOCK_OVERLAYDIR="$DIR_TO_DUMP_INITRAMFS"
extract_initrd_into_initoverlayfs
sudo mkdir -p "$UNLOCK_OVERLAYDIR/upper" "$UNLOCK_OVERLAYDIR/work"
# sudo valgrind /usr/sbin/pre-init
# sudo ln -sf pre-init $DIR_TO_DUMP_INITRAMFS/usr/sbin/init
# sudo ln -sf usr/bin/pre-init $DIR_TO_DUMP_INITRAMFS/init
if [ $fs == "erofs" ]; then
  sudo mkfs.$fs /boot/initoverlayfs-$release.img /run/initoverlayfs/
fi
#sudo losetup -fP /boot/initoverlayfs-$release.img
# ln -s init /usr/sbin/pre-init
initramfs=$(sudo ls /boot/initramfs-* | grep -v rescue | tail -n1)
sudo du -sh $initramfs
#sudo dracut -v -f --strip $initramfs -M
#sudo lsinitrd
sudo du -sh /boot/initramfs*
sudo cp -r lib/dracut/modules.d/81initoverlayfs /usr/lib/dracut/modules.d/
sudo rm -rf /usr/lib/dracut/modules.d/*pre-initramfs
sudo rm -rf /usr/lib/dracut/modules.d/*pre-initoverlayfs

set -x

sudo clang -O3 -pedantic -Wall -Wextra -Werror -Wno-language-extension-token pre-init.c -o /usr/sbin/pre-init
sudo gcc -O3 -pedantic -Wall -Wextra -Werror -Wno-language-extension-token -fanalyzer pre-init.c -o /usr/sbin/pre-init
#sudo dracut $decompressor_dracut -v -m "kernel-modules udev-rules pre-initramfs" -f --strip -M -o "nss-softokn bash i18n kernel-modules-extra rootfs-block dracut-systemd usrmount base fs-lib shutdown systemd systemd-initrd" # systemd-initrd (req by systemd)
sudo /bin/bash -c "echo \"fs=/initoverlayfs-$release.img fstype=erofs\" > /etc/initoverlayfs.conf"
sudo dracut $decompressor_dracut -v -f --strip -M
sudo du -sh /boot/initramfs*
sudo lsinitrd | grep "pre-init"
sudo du -sh $initramfs
# sed -i '/^initrd /d' /boot/loader/entries/9c03d22e1ec14ddaac4f0dabb884e434-$release.conf

boot_partition=$(mount | grep "on /boot type" | awk '{print $1}')
bls_file=$(sudo ls /boot/loader/entries/ | grep -v rescue | tail -n1)
# should be ro rhgb quiet, cannot remount ro, but can fix
#uuid=$(grep "boot.*ext4" /etc/fstab | awk '{print $1}' | sed s/UUID=//g)
#sudo sed -i '/boot.*ext4/d' /etc/fstab
sudo systemctl daemon-reload
#sudo sed -i "s#options #options initoverlayfs=UUID=$uuid initoverlayfstype=ext4 rdinit=/usr/sbin/pre-init #g" /boot/loader/entries/$bls_file
sudo sed -i "s#options #options initoverlayfs=$boot_partition initoverlayfstype=ext4 rdinit=/usr/sbin/pre-init #g" /boot/loader/entries/$bls_file
sudo sed -i "s/ quiet/ console=ttyS0/g" /boot/loader/entries/$bls_file
sudo cat /boot/loader/entries/$bls_file

