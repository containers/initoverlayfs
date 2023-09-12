#!/bin/bash

set -e

> initramfs.txt
> initoverlayfs.txt

for i in {1..100} ; do
  initramfstime=$(grep -m1 -i "Reached target initrd-switch-root" legacy$i.txt | awk "{print \$2}" | sed "s/]//g")
  initoverlayfstime=$(grep -m1 -i "Reached target initrd-switch-root" initoverlayfs$i.txt | awk "{print \$2}" | sed "s/]//g")
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
set xlabel 'Individual runs'
set ylabel 'Seconds to get to rootfs'

plot 'initramfs.txt' using 1:(\$2/1) title 'initramfs' with lines lw 2, \
     'initoverlayfs.txt' using 1:(\$2/1) title 'initoverlayfs' with lines lw 2" | gnuplot
fi

