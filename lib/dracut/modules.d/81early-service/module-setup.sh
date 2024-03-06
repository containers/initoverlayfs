#!/usr/bin/bash

# called by dracut
install() {
    inst /usr/bin/binary-reader /usr/bin/binary
    $SYSTEMCTL -q --root "$initdir" enable binary-reader.service
}

