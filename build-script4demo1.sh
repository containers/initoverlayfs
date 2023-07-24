#!/bin/bash

set -ex

cp build-script4demo2.sh /boot/initoverlayfs/
cd /boot/initoverlayfs
journalctl --output=short-monotonic > journalctl-pre.txt
journalctl --output=short-monotonic | grep -i "Reached target" > reached-target-pre.txt

cd /home/ecurtin/git/initoverlayfs
./build.sh
reboot

