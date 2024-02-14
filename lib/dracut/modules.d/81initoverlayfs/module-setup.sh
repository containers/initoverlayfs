#!/usr/bin/bash

installkernel() {
    hostonly="" instmods erofs overlay loop
}

# called by dracut
depends() {
    echo "systemd"
}

install() {
  INITOVERLAYFS_CONF="/etc/initoverlayfs.conf"
  INITOVERLAYFS_INIT=$(sed -ne "s/^initoverlayfs_init\s//pg" "$INITOVERLAYFS_CONF")
  USE_SYSTEMD="true"
  if [ "$INITOVERLAYFS_INIT" = "true" ]; then
    USE_SYSTEMD="false"
  fi

  inst_multiple -o $INITOVERLAYFS_CONF /usr/sbin/initoverlayfs

  if $USE_SYSTEMD; then
    inst_multiple -o "$systemdsystemunitdir/pre-initoverlayfs.target" \
      "$systemdsystemunitdir/pre-initoverlayfs.service" \
      "$systemdsystemunitdir/pre-initoverlayfs-switch-root.service"
  fi

  inst_dir /boot /initrofs /overlay /overlay/upper /overlay/work /initoverlayfs

  if $USE_SYSTEMD; then
    $SYSTEMCTL -q --root "$initdir" set-default pre-initoverlayfs.target
    $SYSTEMCTL -q --root "$initdir" add-wants sysinit.target pre-initoverlayfs.service
    $SYSTEMCTL -q --root "$initdir" add-wants sysinit.target pre-initoverlayfs-switch-root.service
  fi

  > "${initdir}/usr/bin/bash"
}

