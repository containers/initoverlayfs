#!/usr/bin/bash

installkernel() {
    instmods erofs
}

install() {
    inst /usr/sbin/pre-initoverlayfs
    inst_dir /initoverlayfs
    inst_dir /boot
}

