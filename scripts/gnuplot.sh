#!/bin/bash

set -e

if true; then
true > initramfs.txt
true > initoverlayfs.txt
true > initramfs_systemd_after_switch_root.txt
true > initoverlayfs_systemd_after_switch_root.txt
fi

#size=68
#size="$(echo "$i * 8" | bc)"
for i in {1..11} ; do
  initramfstime=$(grep -m1 -i "systemd 2" "initrd-$i.txt" | sed "s/\[//g" | sed "s/\]//g" | awk "{print \$1}")
  initoverlayfstime=$(grep -m1 -i "systemd 2" "initoverlayfs-$i.txt" | sed "s/\[//g" | sed "s/\]//g" | awk "{print \$1}")
  initramfstime_systemd_after_switch_root=$(grep -m2 -i "systemd 2" "initrd-$i.txt" | tail -n1 | sed "s/\[//g" | sed "s/\]//g" | awk "{print \$1}")
  initoverlayfstime_systemd_after_switch_root=$(grep -m2 -i "systemd 2" "initoverlayfs-$i.txt" | tail -n1 | sed "s/\[//g" | sed "s/\]//g" | awk "{print \$1}")
#  initramfstime=$(grep -m1 -i "Reached target initrd-switch-root" legacy-plus-data$i.txt | awk "{print \"$size \"\$1}")
#  initoverlayfstime=$(grep -m1 -i "starting kmod" initoverlayfs$i.txt | awk "{print \$1}")
#  initramfstime=$(grep -m1 -i "starting kmod" legacy-plus-data$i.txt | awk "{print \$1}")
  echo "$i $initoverlayfstime" >> initoverlayfs.txt
  echo "$i $initramfstime" >> initramfs.txt
  echo "$i $initoverlayfstime_systemd_after_switch_root" >> initoverlayfs_systemd_after_switch_root.txt
  echo "$i $initramfstime_systemd_after_switch_root" >> initramfs_systemd_after_switch_root.txt

#  echo "initoverlayfstime: $initoverlayfstime initramfstime: $initramfstime"
#  if (( $(echo "$initramfstime > $initoverlayfstime" | bc -l) )); then
#    echo "initoverlayfs is faster"
#  else
#    echo "initramfs is faster"
#  fi
done

if true; then
t="png"
echo "set terminal $t
set output 'initramfs-vs-initoverlayfs.$t'
set xlabel 'Iteration'
set ylabel 'Seconds'
set key at graph 1, 0.8

plot 'initramfs.txt' using 1:(\$2/1) title 'initramfs - systemd start' with lines lw 2, \
     'initramfs_systemd_after_switch_root.txt' using 1:(\$2/1) title 'initramfs - systemd start after 1st switch-root' with lines lw 2, \
     'initoverlayfs.txt' using 1:(\$2/1) title 'initoverlayfs - systemd start' with lines lw 2, \
     'initoverlayfs_systemd_after_switch_root.txt' using 1:(\$2/1) title 'initoverlayfs - systemd start after 1st switch-root' with lines lw 2" \
  | gnuplot
fi
