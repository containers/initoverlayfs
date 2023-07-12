#!/bin/bash

set -e

gcc -O3 -pedantic -Wall -Wextra initoverlayfs2init.c -o /boot/initoverlayfs/usr/bin/initoverlayfs2init

