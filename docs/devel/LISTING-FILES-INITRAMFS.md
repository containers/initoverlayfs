# Reading content of initramfs image

During the development of initoverlayfs might be useful to identify files included in the initramfs.  
For this example, let's use a real use case from CentOS Automotive Stream Distribution (qcow2 image).

Build the CentOS Automotive Stream Distribution image
```bash
git clone https://gitlab.com/CentOS/automotive/sample-images
cd sample-images/osbuild-manifests
make cs9-qemu-qm-minimal-ostree.x86_64.qcow2
```

Enable NBD on the Host
```bash
modprobe nbd max_part=8
```

Connect the QCOW2 as network block device
```bash
qemu-nbd --connect=/dev/nbd0 ./cs9-qemu-qm-minimal-ostree.x86_64.qcow2
```

Understanding the output from fdisk
```
# fdisk /dev/nbd0 -l
Disk /dev/nbd0: 8 GiB, 8589934592 bytes, 16777216 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: D209C89E-EA5E-4FBD-B161-B461CCE297E0

Device       Start      End  Sectors  Size Type
/dev/nbd0p1   2048   206847   204800  100M EFI System           <--- EFI boot partition
/dev/nbd0p2 206848   821247   614400  300M Linux filesystem     <--- initramfs partition
/dev/nbd0p3 821248 16775167 15953920  7.6G Linux filesystem     <--- rootfs partition (main fs partition)
```

Mount the initramfs partition
```bash
mount /dev/nbd0p2 /mnt
```

find the initramfs file
```bash
# find . -name initramfs*
./ostree/centos-082d9caaac6cb51dc22cd7d9881692d44c9d7cbc6b3d8edf8709286cb8bd12f9/initramfs-5.14.0-438.391.el9iv.x86_64.img
```

now use lsinitrd tool to list the content of the initramfs image
```
lsinitrd ./ostree/centos-082d9caaac6cb51dc22cd7d9881692d44c9d7cbc6b3d8edf8709286cb8bd12f9/initramfs-5.14.0-438.391.el9iv.x86_64.img
Image: ./ostree/centos-082d9caaac6cb51dc22cd7d9881692d44c9d7cbc6b3d8edf8709286cb8bd12f9/initramfs-5.14.0-438.391.el9iv.x86_64.img: 17M
========================================================================
dracut modules:
systemd
systemd-initrd
kernel-modules
kernel-modules-extra
rootfs-block
udev-rules
dracut-systemd
ostree
usrmount
base
fs-lib
microcode_ctl-fw_dir_override
shutdown
========================================================================
drwxr-xr-x   1 root     root            0 Jan  3 20:49 .
lrwxrwxrwx   1 root     root            7 Jan  3 20:49 bin -> usr/bin
drwxr-xr-x   1 root     root            0 Jan  3 20:49 dev
drwxr-xr-x   1 root     root            0 Jan  3 20:49 etc
drwxr-xr-x   1 root     root            0 Jan  3 20:49 etc/cmdline.d
drwxr-xr-x   1 root     root            0 Jan  3 20:49 etc/conf.d
-rw-r--r--   1 root     root          124 Jan  3 20:49 etc/conf.d/systemd.conf
-rw-r--r--   1 root     root            0 Jan  3 20:49 etc/fstab.empty
-rw-r--r--   1 root     root          203 Jan  3 20:49 etc/group
lrwxrwxrwx   1 root     root           25 Jan  3 20:49 etc/initrd-release -> ../usr/lib/initrd-release
-rw-r--r--   1 root     root         2431 Jan  3 20:49 etc/ld.so.cache
-rw-r--r--   1 root     root           28 Aug  2  2021 etc/ld.so.conf
-rw-r--r--   1 root     root            0 Jan  3 20:49 etc/machine-id
lrwxrwxrwx   1 root     root           17 Jan  3 20:49 etc/mtab -> /proc/self/mounts
lrwxrwxrwx   1 root     root           14 Jan  3 20:49 etc/os-release -> initrd-release
drwxr-xr-x   1 root     root            0 Jan  3 20:49 etc/ostree
-rw-r--r--   1 root     root           44 Jan  3 20:49 etc/ostree/initramfs-root-binding.key
-rw-r--r--   1 root     root          121 Jan  3 20:49 etc/passwd
drwxr-xr-x   1 root     root            0 Jan  3 20:49 etc/systemd

....
snip
....
```

unmount and disconnect as soon as you are done

```
umount /mnt
qemu-nbd -d /dev/nbd0
```
