# initoverlayfs

A scalable solution for initial filesystems focused on minimal resource usage, suitable for both critical and non-critical environments.

- [What is initoverlayfs?](#what-is-initoverlayfs)
- [Why use initoverlayfs?](#why-use-initoverlayfs)
- [Dependancies](#dependancies)
- [Installation](#installation)
	* [Step 1 - Deploy the software](#step-1---deploy-the-software)
	* [Step 2 - Run initoverlayfs-install](#step-2---run-initoverlayfs-install)
	* [Step 3 - Reboot to test](#step-3---reboot-to-test)
	* [Step 4 - Validating the boot](#step-4---validating-the-boot)

# What is initoverlayfs?

initoverlayfs is a solution that uses transient overlays for an initial filesystem rather than tmpfs. If compression is used, it relies on transparent decompression, rather than upfront decompression. This results in more scalable, maintainable initial filesystems.

Here we see a traditional boot sequence:

```
fw -> bootloader -> kernel -> initramfs -> rootfs

fw -> bootloader -> kernel -> init ------------->
```

Here is the boot sequence with initoverlayfs integrated, the mini-initramfs contains just enough to get storage drivers loaded and storage devices initialized. storage-init is a process that is not designed to replace init, it does just enough to initialize storage, switches to initoverlayfs as root and then executes init.

```
fw -> bootloader -> kernel -> mini-initramfs -> initoverlayfs -> rootfs

fw -> bootloader -> kernel -> storage-init   -> init ----------------->
```

# Why use initoverlayfs?

An initramfs (Initial RAM File System) image is a fundamental component in preparing Linux systems during the boot process, preceding the initiation of the init process.

Typically, generating an initramfs involves assembling all available kernel modules and necessary files to boot and support any hardware using the specific Linux kernel version XYZ. This may also include some initialization that's not hardware specific, such as disk encryption, disk verification, early graphics, early camera input, ostree prepare root, etc.

However, this conventional approach presents a significant challenge: loading such a voluminous image into memory during boot is time-consuming and can be problematic in critical scenarios where time to boot is critical. Edge devices commonly need to boot as quickly as possible such as healthcare, automotive and aviation.

Conversely, the initoverlayfs approach proposes a solution: dividing the initramfs image into two parts, relying on transparent decompression rather than upfront decompression.

This division entails segregating the initramfs image into two distinct components.

The first component (initramfs) contains kernel modules, udev-rules and a storage intialization tool, responsible for bringing up the storage device containing initoverlayfs quickly. Subsequently, it mounts and switches to the second component (initoverlayfs), containing all additional kernel modules and essential files required to support the Linux boot process.

This scalable approach serves to diminish the size of the initramfs image, thus enhancing the speed of the boot process.

For illustration, consider a comparison of the sizes using dracut versus initoverlayfs:

**Using dracut only**:
``` bash
# dracut -f
# du -sh /boot/initramfs-6.5.5-300.fc39.x86_64.img
36M	/boot/initramfs-6.5.5-300.fc39.x86_64.img
```

**Using dracut + initoverlayfs**:
``` bash
# /usr/bin/initoverlayfs-install
# du -sh /boot/initramfs-6.5.5-300.fc39.x86_64.img
13M	/boot/initramfs-6.5.5-300.fc39.x86_64.img
^^ <--- from 36M to 13M
```

The advantages of adopting the initoverlayfs approach are evident in the substantial reduction in the size of the initramfs image, thereby significantly expediting the boot process, making it especially appealing in resource-constrained and time-sensitive scenarios.

This is a graphic comparing the boot time effect of increasing initramfs size vs the effect of increasing initoverlayfs size, initoverlayfs is only effected by bytes you use:

![initramfs-vs-initoverlayfs-scale](https://github.com/containers/initoverlayfs/assets/1694275/6f339016-7bcf-4129-af0e-a3f0be7c9be0)

This is a graphic comparing the systemd start time using initramfs only vs using initramfs + initoverlayfs on Raspberry Pi 4 with SD card:

![initramfs-vs-initoverlayfs](https://github.com/containers/initoverlayfs/assets/1694275/7381a100-9d5a-42ed-b55f-8d303b832a3e)

# Dependancies

- EROFS - Initoverlayfs uses erofs as the underlying filesystem.
- dracut - As the initramfs and initoverlayfs composing tool.
- systemd - As the init system.

Note: none of the above dependancies are strictly needed, all the tools could be swapped out for other similar tools.

# Installation

### Step 1 - Deploy the software

Currently, RPM packages are available through the Copr Packages repository.

``` bash
dnf copr enable -y @centos-automotive-sig/next
dnf install -y initoverlayfs
Copr repo for next owned by @centos-automotive-sig  2.4 kB/s | 3.3 kB   00:01
Dependencies resolved.
=============================================================================
 Package            Arch        Version           Repository            Size
=============================================================================
Installing:
 initoverlayfs      x86_64      0.96-1.fc39       @commandline          22 k
Installing dependencies:
 libdeflate         x86_64      1.9-7.fc39        fedora                55 k
Installing weak dependencies:
 erofs-utils        x86_64      1.7.1-1.fc39      updates-testing      140 k

Transaction Summary
=============================================================================
Install  3 Packages

Total size: 217 k
Total download size: 195 k
Installed size: 487 k
Is this ok [y/N]: y

# rpm -qa | grep -i initoverlayfs
initoverlayfs-0.96-1.fc39.x86_64
```

**Note:**
centos-stream-9 requires package from epel-release

```
dnf install -y  epel-release
```

### Step 2 - Run initoverlayfs-install
Once the deployment is completed, the next step is to execute the /usr/bin/initoverlayfs-install tool. This tool is responsible for generating both the initramfs and initoverlayfs images, along with the essential initoverlayfs.conf configuration.

``` bash
# /usr/bin/initoverlayfs-install
<SNIP>
initoverlayfs
kernel-modules
udev-rules
dracut: Skipping udev rule: 40-redhat.rules
dracut: Skipping udev rule: 50-firmware.rules
dracut: Skipping udev rule: 50-udev.rules
dracut: Skipping udev rule: 91-permissions.rules
dracut: Skipping udev rule: 80-drivers-modprobe.rules
dracut: *** Including modules done ***
dracut: *** Installing kernel module dependencies ***
dracut: *** Installing kernel module dependencies done ***
dracut: *** Resolving executable dependencies ***
dracut: *** Resolving executable dependencies done ***
dracut: *** Hardlinking files ***
dracut: Mode:                     real
dracut: Method:                   sha256
dracut: Files:                    819
dracut: Linked:                   0 files
dracut: Compared:                 0 xattrs
dracut: Compared:                 77 files
dracut: Saved:                    0 B
dracut: Duration:                 0.007777 seconds
dracut: *** Hardlinking files done ***
dracut: *** Generating early-microcode cpio image ***
dracut: *** Constructing AuthenticAMD.bin ***
dracut: *** Constructing GenuineIntel.bin ***
dracut: *** Store current command line parameters ***
dracut: *** Stripping files ***
dracut: *** Stripping files done ***
dracut: *** Creating image file '/boot/initramfs-6.5.5-300.fc39.x86_64.img' ***
dracut: Using auto-determined compression method 'pigz'
dracut: *** Creating initramfs image file '/boot/initramfs-6.5.5-300.fc39.x86_64.img' done ***
```

Excellent! Now, let's proceed to compare the size of the newly generated initramfs image
with the existing ones in the filesystem.

``` bash
# uname -r
6.5.5-300.fc39.x86_64

# du -sh /boot/init*
81M	 /boot/initramfs-0-rescue-285b2edb8ad94c7381215fd5720afd54.img
34M	 /boot/initramfs-6.4.12-200.fc38.x86_64.img
34M	 /boot/initramfs-6.5.5-200.fc38.x86_64.img

13M  /boot/initramfs-6.5.5-300.fc39.x86_64.img     <- first image to load (storage drivers only)
149M /boot/initoverlayfs-6.5.5-300.fc39.x86_64.img <- second image (extra kernel mods and files)
```

### Step 3 - Reboot to test

To load the new generated **initramfs and initoverlayfs** images a reboot of the system is necessary.
``` bash
# reboot
```

### Step 4 - Validating the boot

To validate whether the new image has been successfully loaded after the reboot, you can execute the following journalctl command and search for the keyword storage-init:

``` bash
# journalctl -r |  grep -i storage-init
Oct 25 00:20:53 dell730.medogz.com storage-init: mount("/proc", "/initoverlayfs/proc", NULL, MS_MOVE, NULL)
Oct 25 00:20:53 dell730.medogz.com storage-init: (stat("/initoverlayfs/proc", 0x7ffe85ccaa10) == 0) && 16 != 18)
Oct 25 00:20:53 dell730.medogz.com storage-init: mount("/dev", "/initoverlayfs/dev", NULL, MS_MOVE, NULL)
Oct 25 00:20:53 dell730.medogz.com storage-init: (stat("/initoverlayfs/dev", 0x7ffe85ccaa10) == 0) && 5 != 18)
Oct 25 00:20:53 dell730.medogz.com storage-init: mount("/boot", "/initoverlayfs/boot", "ext4", MS_MOVE, NULL) 2 (No such file or directory)
Oct 25 00:20:53 dell730.medogz.com storage-init: forked 368 fork_execlp
Oct 25 00:20:53 dell730.medogz.com storage-init: fork_execlp("udevadm")
Oct 25 00:20:53 dell730.medogz.com storage-init: forked 357 fork_execvp_no_wait
Oct 25 00:20:53 dell730.medogz.com storage-init: fork_execvp_no_wait(0x16c4840)
Oct 25 00:20:53 dell730.medogz.com storage-init: bootfs: {"UUID=b7eaec82-7c35-4887-becf-60ee7889624f", "bootfs UUID=b7eaec82-7c35-4887-becf-60ee7889624f"}, bootfstype: {"ext4", "bootfstype ext4"}, fs: {"(null)", "(null)"}, fstype: {"(null)", "(null)"}, udev_trigger: {"udevadm trigger --type=devices --action=add --subsystem-match=module --subsystem-match=block --subsystem-match=virtio --subsystem-match=pci --subsystem-match=nvme", "udev_trigger udevadm trigger --type=devices --action=add --subsystem-match=module --subsystem-match=block --subsystem-match=virtio --subsystem-match=pci --subsystem-match=nvme"}
```

That's fantastic news! The system is up and running smoothly.
