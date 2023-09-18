#!/bin/bash

set -e

> initramfs.txt
> initoverlayfs.txt

#size=68
#size="$(echo "$i * 8" | bc)"
for i in {1..61} ; do
#  initramfstime=$(grep -m1 -i "Reached target initrd-switch-root" legacy$i.txt | awk "{print \$2}" | sed "s/]//g")
  size="$(echo "68 + $i * 8" | bc)"
#  initoverlayfstime=$(grep -m1 -i "Reached target initrd-switch-root" initoverlayfs$i.txt | awk "{print \"$size \"\$1}")
#  initramfstime=$(grep -m1 -i "Reached target initrd-switch-root" legacy-plus-data$i.txt | awk "{print \"$size \"\$1}")
  initoverlayfstime=$(grep -m1 -i "starting kmod" initoverlayfs$i.txt | awk "{print \$1}")
  initramfstime=$(grep -m1 -i "starting kmod" legacy-plus-data$i.txt | awk "{print \$1}")
  echo "$initoverlayfstime" >> initoverlayfs.txt
  echo "$initramfstime" >> initramfs.txt
#  echo "initoverlayfstime: $initoverlayfstime initramfstime: $initramfstime"
  if (( $(echo "$initramfstime > $initoverlayfstime" | bc -l) )); then
    echo "initoverlayfs is faster"
  else
    echo "initramfs is faster"
  fi
done

if false; then
t="png"
echo "set terminal $t
set output 'initramfs-vs-initoverlayfs.$t'
set xlabel 'Size of uncompressed initramfs in MB'
set ylabel 'Seconds to get to rootfs'

plot 'initramfs.txt' using 1:(\$2/1) title 'initramfs' with lines lw 2, \
     'initoverlayfs.txt' using 1:(\$2/1) title 'initoverlayfs' with lines lw 2" | gnuplot
fi

