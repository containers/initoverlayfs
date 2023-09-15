#!/bin/bash

set -ex

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
    rest_of_line=$(echo "$j" | sed 's/[^ ]* //')
    difference=$(echo  "$first_word - $preboot_time" | bc)
    echo "$difference $rest_of_line" >> $file.bak
  done < $file

  mv $file.bak $file
}

pkill qemu || true

cd ~/git/sample-images/osbuild-manifests
#cp f38-qemu-developer-regular.aarch64.qcow2 f38.qcow2
taskset -c 4-7 ./runvm --aboot --nographics f38-qemu-developer-regular.aarch64.qcow2 > /dev/null 2>&1 &
sleep 32
sshpass -p password ssh-copy-id -p 2222 root@127.0.0.1
ssh -p2222 root@127.0.0.1 "dracut --lz4 -v -f --strip -f -M & dnf install -y */mkfs.erofs; wait; init 0"
cd -

set +x

if true; then
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
  size="$(echo "$i * 4" | bc)M"
  ssh -p2222 root@127.0.0.1 "cd ~/git/initoverlayfs && ./build.sh $size initramfs"
  ssh -p2222 root@127.0.0.1 "init 0" || true # > /dev/null 2>&1

  cd ~/git/sample-images/osbuild-manifests
  wait
  preboot_time=$(date +%s.%N)
  taskset -c 4-7 ./runvm --aboot --nographics f38.qcow2 > /dev/null 2>&1 &
  cd -
  sleep 32
  ssh -p2222 root@127.0.0.1 "sudo journalctl --output=short-unix -b" > legacy-plus-data-$i.txt
  convert_file legacy-plus-data-$i.txt &
  ssh -p2222 root@127.0.0.1 "cd ~/git/initoverlayfs && ./build.sh $size"
  ssh -p2222 root@127.0.0.1 "init 0" || true

  cd ~/git/sample-images/osbuild-manifests
  wait
  preboot_time=$(date +%s.%N)
  taskset -c 4-7 ./runvm --aboot --nographics f38.qcow2 > /dev/null 2>&1 &
  cd -
  sleep 32
  ssh -p2222 root@127.0.0.1 "sudo journalctl --output=short-unix -b" > initoverlayfs$i.txt
  convert_file initoverlayfs$i.txt &
  ssh -p2222 root@127.0.0.1 "init 0" || true
done
else
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
  ssh -p2222 root@127.0.0.1 "cd ~/git/initoverlayfs && ./build.sh"
  ssh -p2222 root@127.0.0.1 "init 0" || true # > /dev/null 2>&1

  cd ~/git/sample-images/osbuild-manifests
  wait
  preboot_time=$(date +%s.%N)
  taskset -c 4-7 ./runvm --aboot --nographics f38.qcow2 > /dev/null 2>&1 &
  cd -
  sleep 32
  ssh -p2222 root@127.0.0.1 "sudo journalctl --output=short-unix -b" > initoverlayfs$i.txt
  convert_file initoverlayfs$i.txt &
  ssh -p2222 root@127.0.0.1 "init 0" || true
done
fi




