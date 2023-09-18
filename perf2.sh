#!/bin/bash

set -e

failure() {
  local lineno=$1
  local msg=$2
  echo "Failed at $lineno: $msg"
}

trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

convert_file() {
  file="$1"

  touch $file.bak

  while read j; do
    first_word=$(echo "$j" | awk '{print $1}')
    difference=$(echo  "$first_word - $preboot_time" | bc) > /dev/null 2>&1
    echo "$difference $rest_of_line" >> $file.bak
  done < $file

  mv $file.bak $file
}

#pkill qemu || true
#cd ~/git/sample-images/osbuild-manifests
#cp f38-qemu-developer-regular.aarch64.qcow2 f38.qcow2
#preboot_time=$(date +%s.%N)
#taskset -c 4-7 ./runvm --aboot --nographics f38.qcow2 > /dev/null 2>&1 &
#cd -

#sleep 8

ssh -p2222 root@127.0.0.1 "sudo journalctl --output=short-unix -b" > legacy$i.txt
convert_file legacy$i.txt &

git-push.sh -p2222 root@127.0.0.1
ssh -p2222 root@127.0.0.1 "cd ~/git/initoverlayfs && ./build.sh" > build.txt 2>&1
ssh -p2222 root@127.0.0.1 "reboot" || true # > /dev/null 2>&1

