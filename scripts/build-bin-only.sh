#!/bin/bash

set -ex

FLAGS="-lblkid"

clang++ -o a -O3 $FLAGS -pedantic -fno-exceptions -fno-rtti -Wall -Wextra -Werror -Wno-write-strings -Wno-language-extension-token -Wno-deprecated -std=c++20 initoverlayfs.c &
g++ -o b -O0 $FLAGS -ggdb -pedantic -fno-exceptions -fno-rtti -Wall -Wextra -Werror -Wno-write-strings -Wno-language-extension-token -std=c++20 initoverlayfs.c &
clang -o c -O3 $FLAGS -pedantic -fno-exceptions -Wall -Wextra -Werror -Wno-language-extension-token initoverlayfs.c &

if [ -e /usr/lib/rpm/redhat/redhat-hardened-cc1 ]; then
  gcc -O2 $FLAGS -fanalyzer -fno-exceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection initoverlayfs.c -o d &
else
  gcc -O2 $FLAGS -fanalyzer -fno-exceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection initoverlayfs.c -o d &
fi

wait

gcc -O0 $FLAGS -fno-exceptions -ggdb -pedantic -Wall -Wextra -Werror -fanalyzer initoverlayfs.c
#sudo valgrind ./a.out

