#!/usr/bin/bash

. /etc/sysconfig/kdump

KDUMP_KERNEL=""
KDUMP_INITRD=""

check() {
    if [[ ! -f /etc/sysconfig/kdump ]] || [[ ! -f /lib/kdump/kdump-lib.sh ]] \
        || [[ -n ${IN_KDUMP} ]]; then
        return 1
    fi
    return 255
}

depends() {
    echo "base shutdown"
    return 0
}

prepare_kernel_initrd() {
    . /lib/kdump/kdump-lib.sh

    prepare_kdump_bootinfo

    # $kernel is a variable from dracut
    if [[ $KDUMP_KERNELVER != "$kernel" ]]; then
        dwarn "Using kernel version '$KDUMP_KERNELVER' for early kdump," \
            "but the initramfs is generated for kernel version '$kernel'"
    fi
}

install() {
    prepare_kernel_initrd
    if [[ ! -f $KDUMP_KERNEL ]]; then
        derror "Could not find required kernel for earlykdump," \
            "earlykdump will not work!"
        return 1
    fi
    if [[ ! -f $KDUMP_INITRD ]]; then
        derror "Could not find required kdump initramfs for earlykdump," \
            "please ensure kdump initramfs is generated first," \
            "earlykdump will not work!"
        return 1
    fi

    inst_multiple tail find cut dirname hexdump
    inst_simple "/etc/sysconfig/kdump"
    inst_binary "/usr/sbin/kexec"
    inst_binary "/usr/bin/gawk" "/usr/bin/awk"
    inst_binary "/usr/bin/logger" "/usr/bin/logger"
    inst_binary "/usr/bin/printf" "/usr/bin/printf"
    inst_binary "/usr/bin/xargs" "/usr/bin/xargs"
    inst_script "/lib/kdump/kdump-lib.sh" "/lib/kdump-lib.sh"
    inst_script "/lib/kdump/kdump-lib-initramfs.sh" "/lib/kdump/kdump-lib-initramfs.sh"
    inst_script "/lib/kdump/kdump-logger.sh" "/lib/kdump-logger.sh"
    inst_hook cmdline 00 "$moddir/early-kdump.sh"
    inst_binary "$KDUMP_KERNEL"
    inst_binary "$KDUMP_INITRD"

    ln_r "$KDUMP_KERNEL" "/boot/kernel-earlykdump"
    ln_r "$KDUMP_INITRD" "/boot/initramfs-earlykdump"

    chmod -x "${initdir}/$KDUMP_KERNEL"
}
