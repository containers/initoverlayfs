#!/usr/bin/bash

installkernel() {
    hostonly='' instmods erofs overlay
}

install() {
    inst_multiple /usr/sbin/pre-init "$systemdutildir"/systemd-udevd \
      udevadm /usr/sbin/modprobe /etc/initoverlayfs.conf
    inst_dir /boot /initrofs /overlay /overlay/upper /overlay/work /initoverlayfs
}

