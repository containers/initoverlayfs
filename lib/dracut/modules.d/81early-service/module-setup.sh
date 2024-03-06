#!/usr/bin/bash

# called by dracut
install() {
    inst /usr/bin/binary-reader /usr/bin/binary /usr/lib/systemd/system/binary-reader.service
    $SYSTEMCTL -q --root "$initdir" add-wants sysinit.target binary-reader.service
}

