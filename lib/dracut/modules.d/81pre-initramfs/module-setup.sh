#!/usr/bin/bash

installkernel() {
    hostonly='' instmods erofs overlay
}

install() {
    inst /usr/sbin/pre-initoverlayfs
    inst_dir /boot /initrofs /overlay /overlay/upper /overlay/work /initoverlayfs
}

