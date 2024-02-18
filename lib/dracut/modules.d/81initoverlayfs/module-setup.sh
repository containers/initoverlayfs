#!/usr/bin/bash

installkernel() {
    hostonly="" instmods erofs overlay loop
}

# called by dracut
depends() {
    echo "systemd"
}

install() {
    inst_multiple -o /etc/initoverlayfs.conf /usr/sbin/initoverlayfs \
      "$systemdsystemunitdir/pre-initoverlayfs.target" \
      "$systemdsystemunitdir/pre-initoverlayfs.service" \
      "$systemdsystemunitdir/pre-initoverlayfs-switch-root.service"


    inst_dir /boot /initrofs /overlay /overlay/upper /overlay/work \
      /initoverlayfs

    $SYSTEMCTL -q --root "$initdir" set-default pre-initoverlayfs.target
    $SYSTEMCTL -q --root "$initdir" add-wants sysinit.target pre-initoverlayfs.service
    $SYSTEMCTL -q --root "$initdir" add-wants sysinit.target pre-initoverlayfs-switch-root.service

    > "${initdir}/usr/bin/bash"
}

