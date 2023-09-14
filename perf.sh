#!/bin/bash

set -ex

convert_file() {
  file="$1"

  touch $file.bak

  while read j; do
    first_word=$(echo "$j" | awk '{print $1}')
    rest_of_line=$(echo "$j" | sed 's/[^ ]* //')
    difference=$(echo  "$first_word - $preboot_time" | bc)
    echo "$difference $rest_of_line" >> $file.bak
  done < $file

  mv $file.bak $file
}

pkill qemu || true

for i in {1..64}; do
  cd ~/git/sample-images/osbuild-manifests
  wait
  cp f38-qemu-developer-regular.aarch64.qcow2 f38.qcow2
  preboot_time=$(date +%s.%N)
  taskset -c 4-7 ./runvm --aboot --nographics f38.qcow2 > /dev/null 2>&1 &
  cd -
  sleep 32
  ssh -p2222 root@127.0.0.1 "sudo journalctl --output=short-unix -b" > legacy$i.txt
  convert_file legacy$i.txt &
  git-push.sh -p2222 root@127.0.0.1
  ssh -p2222 root@127.0.0.1 "cd ~/git/initoverlayfs && ./build.sh && sudo init 0" # > /dev/null 2>&1

  cd ~/git/sample-images/osbuild-manifests
  preboot_time=$(date +%s.%N)
  wait
  taskset -c 4-7 ./runvm --aboot --nographics f38.qcow2 > /dev/null 2>&1 &
  cd -
  sleep 32
  ssh -p2222 root@127.0.0.1 "sudo journalctl --output=short-unix -b" > initoverlayfs$i.txt
  convert_file initoverlayfs$i.txt &
  ssh -p2222 root@127.0.0.1 "sudo init 0"
done

