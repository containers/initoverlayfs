#!/bin/bash

set -ex

mkdir /vda4
mount /dev/vda4 /vda4

journalctl --output=short-monotonic > /journalctl-post.txt
journalctl --output=short-monotonic | grep -i "Reached target" > /reached-target-post.txt

export LD_LIBRARY_PATH=/vda4/lib64
/vda4/usr/bin/vimdiff /reached-target-pre.txt /reached-target-post.txt

