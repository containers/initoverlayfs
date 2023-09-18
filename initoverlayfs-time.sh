#!/bin/bash

for i in {1..61}; do
 time_preinit_start=$(grep -m1 -i "pre-initoverlayfs as" initoverlayfs$i.txt | awk '{print $1}')
 time_preinit_end=$(grep -m1 -i "fedora systemd" initoverlayfs$i.txt | awk '{print $1}')
 difference=$(echo "$time_preinit_end - $time_preinit_start" | bc)
 difference=$(echo "$difference * 1000" | bc)
 echo "$difference ms"
done

