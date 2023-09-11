#!/bin/bash

set -e

for i in {1..100} ; do
  cd
  cp f38.qcow2.bak f38.qcow2; ./runvm --nographics f38.qcow2 &
  cd -
  sleep 32
  ssh -p2222 ecurtin@127.0.0.1 "sudo journalctl --output=short-monotonic -b" > legacy$i.txt
  git-push.sh -p2222 ecurtin@127.0.0.1 && ssh -p2222 ecurtin@127.0.0.1 "cd ~/git/initoverlayfs && ./build.sh && sudo reboot"
  sleep 32
  ssh -p2222 ecurtin@127.0.0.1 "sudo journalctl --output=short-monotonic -b" > initoverlayfs$i.txt
  pkill qemu
done

