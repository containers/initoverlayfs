Name:          initoverlayfs
Version:       0.96
Release:       2%{?dist}
Summary:       An initial scalable filesystem for Linux operating systems

License:       GPL-2.0-only
URL:           https://github.com/containers/initoverlayfs
Source0:       %{url}/archive/%{version}/%{name}-%{version}.tar.gz

BuildRequires: gcc
Recommends: erofs-utils
Requires: dracut

%global debug_package %{nil}

%description
%{summary}.

%prep
%setup -q -n %{name}-%{version}

%build
RPM_OPT_FLAGS="${RPM_OPT_FLAGS/-flto=auto /}"
gcc ${RPM_OPT_FLAGS} storage-init.c -o storage-init

%install
install -D -m755 bin/initoverlayfs-install ${RPM_BUILD_ROOT}/%{_bindir}/initoverlayfs-install
install -D -m755 storage-init ${RPM_BUILD_ROOT}/%{_prefix}/sbin/storage-init
install -D -m755 lib/dracut/modules.d/81initoverlayfs/module-setup.sh $RPM_BUILD_ROOT/%{_prefix}/lib/dracut/modules.d/81initoverlayfs/module-setup.sh

%files
%license LICENSE
%doc README.md
%attr(0755,root,root) 
%{_bindir}/initoverlayfs-install
%{_prefix}/sbin/storage-init
%{_prefix}/lib/dracut/modules.d/81initoverlayfs/

%changelog
* Wed Nov  8 2023 Stephen Smoogen <ssmoogen@redhat.com> - 0.96-2
- Make changes to pass fedora-review tests on permissions and other items

* Tue Oct 24 2023 Eric Curtin <ecurtin@redhat.com> - 0.96-1
- Leave initoverlayfs dracut module out of initoverlayfs.
* Tue Oct 24 2023 Eric Curtin <ecurtin@redhat.com> - 0.95-1
- Install script changes.
* Wed Oct 18 2023 Eric Curtin <ecurtin@redhat.com> - 0.94-1
- Add partlabel support.
* Mon Oct 16 2023 Eric Curtin <ecurtin@redhat.com> - 0.93-1
- More optimization, can now install initoverlayfs files for kernels that
  aren't currently running.
* Fri Oct 13 2023 Eric Curtin <ecurtin@redhat.com> - 0.92-1
- Add default fs and fstype.
* Fri Oct 13 2023 Eric Curtin <ecurtin@redhat.com> - 0.91-1
- Rm custom tokenizer, replace with strtok.
* Thu Oct 12 2023 Eric Curtin <ecurtin@redhat.com> - 0.9-1
- Change to bls_parser, split into separate files. Remove grub dependancy.
* Thu Oct 5 2023 Eric Curtin <ecurtin@redhat.com> - 0.8-1
- Change to initoverlayfs.bootfs and initoverlay.bootfstype
* Wed Oct 4 2023 Eric Curtin <ecurtin@redhat.com> - 0.7-1
- Some bugfixes, leading / in fs=, asprintf check incorrect
* Tue Oct 3 2023 Eric Curtin <ecurtin@redhat.com> - 0.6-1
- initoverlayfs-install generates /etc/initoverlayfs.conf
* Mon Oct 2 2023 Eric Curtin <ecurtin@redhat.com> - 0.5-1
- Add dracut files to initramfs
* Wed Sep 27 2023 Eric Curtin <ecurtin@redhat.com> - 0.4-1
- Package initoverlayfs

