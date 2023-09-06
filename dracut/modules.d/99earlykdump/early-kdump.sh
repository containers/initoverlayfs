#!/usr/bin/bash

KEXEC=/sbin/kexec
standard_kexec_args="-p"

EARLY_KDUMP_INITRD=""
EARLY_KDUMP_KERNEL=""
EARLY_KDUMP_CMDLINE=""
EARLY_KEXEC_ARGS=""

. /etc/sysconfig/kdump
. /lib/dracut-lib.sh
. /lib/kdump-lib.sh
. /lib/kdump-logger.sh

# initiate the kdump logger
if ! dlog_init; then
        echo "failed to initiate the kdump logger."
        exit 1
fi

prepare_parameters()
{
    EARLY_KDUMP_CMDLINE=$(prepare_cmdline "${KDUMP_COMMANDLINE}" "${KDUMP_COMMANDLINE_REMOVE}" "${KDUMP_COMMANDLINE_APPEND}")
    EARLY_KDUMP_KERNEL="/boot/kernel-earlykdump"
    EARLY_KDUMP_INITRD="/boot/initramfs-earlykdump"
}

early_kdump_load()
{
    if ! check_kdump_feasibility; then
        return 1
    fi

    if is_fadump_capable; then
        dwarn "WARNING: early kdump doesn't support fadump."
        return 1
    fi

    if is_kernel_loaded "kdump"; then
        return 1
    fi

    prepare_parameters

    EARLY_KEXEC_ARGS=$(prepare_kexec_args "${KEXEC_ARGS}")

    if is_secure_boot_enforced; then
        dinfo "Secure Boot is enabled. Using kexec file based syscall."
        EARLY_KEXEC_ARGS="$EARLY_KEXEC_ARGS -s"
    fi

    # Here, only output the messages, but do not save these messages
    # to a file because the target disk may not be mounted yet, the
    # earlykdump is too early.
    ddebug "earlykdump: $KEXEC ${EARLY_KEXEC_ARGS} $standard_kexec_args \
	--command-line=$EARLY_KDUMP_CMDLINE --initrd=$EARLY_KDUMP_INITRD \
	$EARLY_KDUMP_KERNEL"

    # shellcheck disable=SC2086
    if $KEXEC $EARLY_KEXEC_ARGS $standard_kexec_args \
        --command-line="$EARLY_KDUMP_CMDLINE" \
        --initrd=$EARLY_KDUMP_INITRD $EARLY_KDUMP_KERNEL; then
        dinfo "kexec: loaded early-kdump kernel"
        return 0
    else
        derror "kexec: failed to load early-kdump kernel"
        return 1
    fi
}

set_early_kdump()
{
    if getargbool 0 rd.earlykdump; then
        dinfo "early-kdump is enabled."
        early_kdump_load
    else
        dinfo "early-kdump is disabled."
    fi

    return 0
}

set_early_kdump
