#!/bin/bash

set -ex

clang -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra -Werror pre-initoverlayfs.c
gcc -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O0 -ggdb -pedantic -Wall -Wextra -Werror -fanalyzer pre-initoverlayfs.c
valgrind ./a.out

