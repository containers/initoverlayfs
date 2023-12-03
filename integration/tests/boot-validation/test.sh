#!/bin/bash

set -x

if [ "${TMT_REBOOT_COUNT}" == "1" ];then
   echo -n "machine is up"
   storage_init=$(journalctl -r | grep "init -> usr/sbin/storage-init" | tail -1)
   exit_code="$?"
   if [ "$exit_code" != "0" ]; then
      echo -n "initoverlayfs,  storage-init messages not found in journal"
      exit "$exit_code"
   fi 
   echo -n "initoverlayfs boot complete"
   exit 0
fi

RPM_EXIST=$(rpm -qa | grep -i initoverlayfs)

if [ -z "${RPM_EXIST}" ]; then
   echo -n "initoverlayfs rpm is missing"
   exit 127
fi

echo -n "Install initoverlayfs"
/usr/bin/initoverlayfs-install

exit_code="$?"

if [ "$exit_code" != "0" ]; then
   echo -n "initoverlayfs-install completeted with $exit_code"
   exit "$exit_code"
fi

echo -n "Verifying initoverlayfs in /boot"
du -sh /boot/init* | grep initoverlayfs

exit_code="$?"
if [ "$exit_code" != "0" ]; then
   echo -n "initoverlayfs  not found under /boot please check runnin machine"
   exit "$exit_code"
fi

/usr/local/bin/tmt-reboot

