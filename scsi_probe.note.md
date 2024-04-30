# SCSI Probe note

This note aims to provide information to the addition of SCSI probe
functionality.
The focus here is on addressing a particular practice among certain silicon
vendors BSPs, where they partition storage devices into multiple LUNs and
partitions.
A notable scenario involves fragmenting a single UFS memory device into 8
LUNs and over 100 partitions.
In such cases, the boot sequence for these devices can experience
significant delays due to the enumeration of numerous partitions, often with
data that is only required later in the boot sequence or not needed at all.

By default, the kernel scans all channels, targets, and LUNs of SCSI devices,
as the UFS interface provides to the operating system.
Consequently, the OS spends time enumerating all found partitions.
To address this issue, the SCSI Probe feature requires that the kernel does
not automatically scan all SCSI targets (`scsi_mod.scan=manual` kernel boot
argument).
Instead, it allows specifying the LUN where the root filesystem is located.

The mechanism for specifying the LUN can be achieved either via the kernel
command line (`scsi.addr=<host>:<channel>:<target>:<lun>`) or by adding a
line to the `initoverlayfs.config` file 
(`scsi.addr <host>:<channel>:<target>:<lun>`).
If both methods are used, the configuration in the `initoverlayfs.config` file
takes precedence.

It's important to note that the presence of the `scsi_mod.scan=manual` kernel
argument is essential for any operation to occur.
If this argument is not included in the kernel command line, no action will
be taken.

Although the feature was specifically developed for the UFS use case, it is
intended to function with all SCSI `sd` devices.

# build initoverlayfs with SCSI Probe support

At the time of writing this document, there is no sophisticated build system
in place for initoverlayfs.
The functionality related to SCSI Probe relies on the `SCSI_PROBE` symbol,
which must be passed during the build process.
Presently, the build steps are specified in the `initoverlayfs.spec.in` file.
To compile initoverlayfs with SCSI Probe support, you need to modify
`initoverlayfs.spec.in` by adding `-D SCSI_PROBE` to the `RPM_OPT_FLAGS`
variable. Alternatively, you can compile it manually, as demonstrated below:
```
gcc -static -D SCSI_PROBE -Os initoverlayfs.c \
        /usr/lib/x86_64-linux-gnu/libblkid.a scsi_probe/scsi_probe.c \
        -o initoverlayfs
```

This modification alone may be sufficient, as the target for manual scanning
can be specified using kernel boot arguments.
However, if you prefer to specify it using `initoverlayfs.conf`, you may need
to modify the `scripts/build.sh` script to add a line to the configuration it
generates.

# Test with qemu

As mentioned, the feature is tailored specifically for embedded/mobile
devices utilizing UFS as storage. While it's designed to be compatible
with any SCSI setup, it's advisable for individuals to test it in a
nearly real-world scenario before deploying it in production.

Since September 2023 mapping Version `8.0`, qemu has offered UFS PCI
emulation.

With qemu supporting UFS, here's an example command to test UFS:

```
qemu-system-x86_64 -m 512M -nographic -smp 1 -kernel ./bzImage \
        -initrd \initramfs.img \
	-append "console=ttyS0 pippo raid=noautodetect init=/sbin/init scsi_mod.scan=manual" \
	-device ufs,id=bus0 -device ufs-lu,drive=ufs1,bus=bus0,lun=0 \
        -drive if=none,file=ufsimage.img,format=raw,id=ufs1
```
