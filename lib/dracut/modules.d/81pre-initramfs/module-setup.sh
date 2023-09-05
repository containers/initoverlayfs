#!/usr/bin/bash

installkernel() {
    hostonly='' instmods erofs overlayfs
}

install() {
    inst /usr/sbin/pre-initoverlayfs
    inst_dir /boot /initerofs /overlay/upper /overlay/work /initoverlayfs
}

