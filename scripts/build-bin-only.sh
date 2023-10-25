#!/bin/bash

set -ex

clang++ -o a -O3 -pedantic -fno-exceptions -fno-rtti -Wall -Wextra -Werror -Wno-write-strings -Wno-language-extension-token -Wno-deprecated -std=c++20 storage-init.c &
g++ -o b -O0 -ggdb -pedantic -fno-exceptions -fno-rtti -Wall -Wextra -Werror -Wno-write-strings -Wno-language-extension-token -std=c++20 storage-init.c &
clang -o c -O3 -pedantic -fno-exceptions -Wall -Wextra -Werror -Wno-language-extension-token storage-init.c &

if [ -e /usr/lib/rpm/redhat/redhat-hardened-cc1 ]; then
  gcc -O2 -fanalyzer -fno-exceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection storage-init.c -o d &
else
  gcc -O2 -fanalyzer -fno-exceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection storage-init.c -o d &
fi

wait

gcc -O0 -fno-exceptions -ggdb -pedantic -Wall -Wextra -Werror -fanalyzer storage-init.c
sudo valgrind ./a.out

