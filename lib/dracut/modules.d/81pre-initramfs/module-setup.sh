#!/usr/bin/bash

installkernel() {
    hostonly='' instmods erofs overlay
}

install() {
    inst_multiple -o /usr/sbin/pre-initoverlayfs "$systemdutildir"/systemd-udevd udevadm
    inst_dir /boot /initrofs /overlay /overlay/upper /overlay/work /initoverlayfs
}

