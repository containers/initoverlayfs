#!/bin/bash

set -ex

clang -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra -Werror pre-init.c
gcc -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O0 -ggdb -pedantic -Wall -Wextra -Werror -fanalyzer pre-init.c
valgrind ./a.out

