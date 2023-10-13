#!/usr/bin/bash

installkernel() {
    hostonly="" instmods erofs overlay
}

install() {
    inst_multiple -o /etc/initoverlayfs.conf
    inst_multiple /usr/sbin/pre-init "$systemdutildir"/systemd-udevd \
      udevadm modprobe /etc/initoverlayfs.conf
    inst_dir /boot /initrofs /overlay /overlay/upper /overlay/work /initoverlayfs

    if [ ! -e "/init" ]; then
        ln_r /usr/sbin/pre-init "/init"
    fi

    if [ ! -e "/sbin/init" ]; then
        ln_r /usr/sbin/pre-init "/sbin/init"
    fi
}

