# initoverlayfs

**An innovative solution for generating initramfs images** focused in speed up Linux operating system boot time,  
suitable for both **critical and non-critical** environments.

- [Why use initoverlayfs to generate initramfs images?](#why-use-initoverlayfs-to-generate-initramfs-images-)
- [Installation](#installation)
    * [Step 1 - Deploy the software](#step-1---deploy-the-software)
    * [Step 2 - Run initoverlayfs-install](#step-2---run-initoverlayfs-install)
    * [Step 3 - Reboot to test](#step-3---reboot-to-test)
    * [Step 4 - Validating the boot](#step-4---validating-the-boot)

# Why use initoverlayfs to generate initramfs images?

An initramfs (Initial RAM File System) image is a fundamental component in preparing Linux systems during the boot process, preceding the initiation of the init process. 

Typically, generating an initramfs involves assembling all available kernel modules and necessary files to boot and support any hardware using the specific Linux kernel version XYZ.  

However, this conventional approach presents a significant challenge: loading such a voluminous image into memory during boot is time-consuming and can be problematic in critical scenarios where time to boot is critical. Edge devices commonly need to boot as quickly as possible such as healthcare, automotive and aviation.

Conversely, the initoverlayfs approach proposes a solution: "**dividing the initramfs image into two parts**." 

This division entails segregating the initramfs image into two distinct components.
The first component (initramfs) houses only the kernel modules and udev-rules necessary for storage, responsible for bringing up the storage device containing initoverlayfs quickly. Subsequently, it mounts and switches to the second component (initoverlayfs), containing all additional kernel modules and essential files required to support the Linux boot process.

This innovative approach serves to diminish the size of the initramfs image, thus enhancing the speed of the boot process.

For illustration, consider a comparison of the sizes using dracut versus initoverlayfs:

**Using Dracut**:
``` bash
# dracut -f
# du -sh /boot/initramfs-6.5.5-300.fc39.x86_64.img
36M	/boot/initramfs-6.5.5-300.fc39.x86_64.img
```

**Using initoverlayfs**:
``` bash
# /usr/bin/initoverlayfs-install
# du -sh /boot/initramfs-6.5.5-300.fc39.x86_64.img
13M	/boot/initramfs-6.5.5-300.fc39.x86_64.img 
^^ <--- from 36M to 13M
```

The advantages of adopting the initoverlayfs approach are evident in the substantial reduction in the size of the initramfs image, thereby significantly expediting the boot process, making it especially appealing in resource-constrained and time-sensitive scenarios.

# Installation

### Step 1 - Deploy the software

Currently, RPM packages are available through the Copr Packages repository.

- [CentOS Stream 9 - x86_64](https://download.copr.fedorainfracloud.org/results/%40centos-automotive-sig/next/centos-stream-9-x86_64/)
- [Fedora 39 - x86_64](https://download.copr.fedorainfracloud.org/results/%40centos-automotive-sig/next/fedora-39-x86_64/)

``` bash
# dnf install https://download.copr.fedorainfracloud.org/results/%40centos-automotive-sig/next/fedora-39-x86_64/06561181-initoverlayfs/initoverlayfs-0.96-1.fc39.x86_64.rpm
Last metadata expiration check: 2:29:27 ago on Tue 24 Oct 2023 08:54:21 AM EDT.
initoverlayfs-0.96-1.fc39.x86_64.rpm          92 kB/s |  22 kB     00:00
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
