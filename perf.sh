#!/bin/bash

set -e

cd 
cp f38.qcow2.bak f38.qcow2; ./runvm --nographics f38.qcow2 &
cd -
sleep 16
ssh -p2222 ecurtin@127.0.0.1 "sudo journalctl --output=short-monotonic -b | grep \"Reached target\"" > legacy.txt
git-push.sh -p2222 ecurtin@127.0.0.1 && ssh -p2222 ecurtin@127.0.0.1 "cd ~/git/initoverlayfs && ./build.sh && sudo reboot"
sleep 16
ssh -p2222 ecurtin@127.0.0.1 "sudo journalctl --output=short-monotonic -b | grep \"Reached target\"" > initoverlayfs.txt
pkill qemu




