#!/bin/bash

set -e

UNLOCK_OVERLAYDIR="/var/tmp/initoverlay"
mkdir -p "$UNLOCK_OVERLAYDIR/upper" "$UNLOCK_OVERLAYDIR/work"
gcc -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra initoverlayfs2init.c -o initoverlayfs2init

