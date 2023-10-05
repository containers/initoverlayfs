#!/bin/bash

set -ex

clang -o c -O3 -pedantic -Wno-gnu-conditional-omitted-operand -Wall -Wextra -Werror -Wno-language-extension-token bls-parser.c &

if [ -e /usr/lib/rpm/redhat/redhat-hardened-cc1 ]; then
  gcc -O2 -flto=auto -ffat-lto-objects -fexceptions -g -grecord-gcc-switches -pipe -Wno-gnu-conditional-omitted-operand -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection bls-parser.c -o d &
else
  gcc -O2 -flto=auto -ffat-lto-objects -fexceptions -g -grecord-gcc-switches -pipe -Wno-gnu-conditional-omitted-operand -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection bls-parser.c -o d &
fi

wait

gcc -O0 -ggdb -Wall -Wextra -Werror -Wno-language-extension-token -fanalyzer bls-parser.c
valgrind ./a.out

