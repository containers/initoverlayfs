#!/bin/bash
# disable shellcheck for "Double quote to prevent globbing" until tested fix
# shellcheck disable=SC2086
# 

set -ex

USER="$(id -un)"
REL="$(git tag | tail -1)"
UNAME_M="$(uname -m)"
if command -v distrobox-enter; then
  distrobox-enter -r centos-stream9 -- /bin/bash -c "sudo dnf install -y epel-release && sudo dnf install -y valgrind clang gcc erofs-utils dracut rpm-build git && cd $PWD && scripts/build-bin-only.sh && mkdir -p /home/$USER/rpmbuild/SOURCES/ && git archive -o /home/$USER/rpmbuild/SOURCES/initoverlayfs-$REL.tar.gz --prefix initoverlayfs-$REL/ HEAD && rpmbuild -ba *.spec && sudo mkdir -p /boot /initrofs /overlay /overlay/upper /overlay/work /initoverlayfs && sudo rpm --force -U ~/rpmbuild/RPMS/$UNAME_M/initoverlayfs-$REL-1.el9.$UNAME_M.rpm && sudo dracut -f --no-kernel && sudo initoverlayfs-install && sudo valgrind ./a.out"
else
  sudo podman build -t initoverlayfs .
  sudo podman run --rm -it -v $PWD:$PWD initoverlayfs -- /bin/bash -c "sudo dnf install -y epel-release && sudo dnf install -y valgrind clang gcc erofs-utils dracut rpm-build git && cd $PWD && scripts/build-bin-only.sh && mkdir -p /home/$USER/rpmbuild/SOURCES/ && git archive -o /home/$USER/rpmbuild/SOURCES/initoverlayfs-$REL.tar.gz --prefix initoverlayfs-$REL/ HEAD && rpmbuild -ba *.spec && sudo mkdir -p /boot /initrofs /overlay /overlay/upper /overlay/work /initoverlayfs && sudo rpm --force -U ~/rpmbuild/RPMS/$UNAME_M/initoverlayfs-$REL-1.el9.$UNAME_M.rpm && sudo dracut -f --no-kernel && sudo initoverlayfs-install && sudo valgrind ./a.out"
fi

