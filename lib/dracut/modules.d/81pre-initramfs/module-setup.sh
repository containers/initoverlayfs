#!/usr/bin/bash

installkernel() {
    hostonly='' instmods erofs
}

install() {
    inst /usr/sbin/pre-initoverlayfs
#    inst_dir /boot /initerofs /overlay /overlay/upper /overlay/work /initoverlayfs
}

