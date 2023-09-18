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

ssh -p2222 root@127.0.0.1 "sudo journalctl --output=short-unix -b" > legacy$i.txt
convert_file legacy$i.txt &
git-push.sh -p2222 root@127.0.0.1
ssh -p2222 root@127.0.0.1 "cd ~/git/initoverlayfs && ./build.sh"
ssh -p2222 root@127.0.0.1 "init 0" || true # > /dev/null 2>&1

