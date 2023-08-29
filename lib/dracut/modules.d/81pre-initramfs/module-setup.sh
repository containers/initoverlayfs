#!/usr/bin/bash

# called by dracut
install() {
    inst /usr/sbin/pre-initoverlayfs
    inst_dir /initoverlayfs
}

