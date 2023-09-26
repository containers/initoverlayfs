#!/bin/bash

set -ex

clang++ -o a -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra -Werror -Wno-language-extension-token -Wno-deprecated -std=c++20 pre-init.c &
g++ -o b -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O0 -ggdb -pedantic -Wall -Wextra -Werror -Wno-language-extension-token -std=c++20 pre-init.c &
clang -o c -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra -Werror -Wno-language-extension-token pre-init.c &

wait

gcc -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O0 -ggdb -pedantic -Wall -Wextra -Werror -Wno-language-extension-token -fanalyzer pre-init.c
valgrind ./a.out

