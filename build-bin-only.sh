#!/bin/bash

set -ex

clang++ -o a -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra -Werror -Wno-language-extension-token -Wno-deprecated -std=c++20 pre-init.c &
g++ -o b -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O0 -ggdb -pedantic -Wall -Wextra -Werror -Wno-language-extension-token -std=c++20 pre-init.c &
clang -o c -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O3 -pedantic -Wall -Wextra -Werror -Wno-language-extension-token pre-init.c &
gcc -O2 -flto=auto -ffat-lto-objects -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection pre-init.c -o d &

wait

gcc -DUNLOCK_OVERLAYDIR=\"$UNLOCK_OVERLAYDIR\" -O0 -ggdb -pedantic -Wall -Wextra -Werror -Wno-language-extension-token -fanalyzer pre-init.c
valgrind ./a.out

