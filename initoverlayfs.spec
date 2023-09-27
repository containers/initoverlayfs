Name:          initoverlayfs
Version:       0.4
Release:       1%{?dist}
Summary:       An initial scalable filesystem for Linux operating systems

License:       GPLv2
URL:           https://github.com/ericcurtin/initoverlayfs
Source0:       %{url}/archive/%{version}/%{name}-%{version}.tar.gz

BuildRequires: gcc
Recommends: grubby
Recommends: erofs-utils

%global dracutdir %(pkg-config --variable=dracutdir dracut)
%global debug_package %{nil}

%description
%{summary}.

%prep
%setup -q -n %{name}-%{version}

%build
gcc ${RPM_OPT_FLAGS} pre-init.c -o pre-init

%install
install -D -m744 initoverlayfs-install ${RPM_BUILD_ROOT}/%{_bindir}/initoverlayfs-install
install -D -m744 pre-init ${RPM_BUILD_ROOT}/%{_prefix}/sbin/pre-init
install -D -m644 lib/dracut/modules.d/81initoverlayfs/module-setup.sh $RPM_BUILD_ROOT%{dracutdir}/modules.d/81initoverlayfs/module-setup.sh

%files
install -D -m644 initoverlayfs-install ${RPM_BUILD_ROOT}/%{_bindir}/initoverlayfs-install
%{_prefix}/sbin/pre-init
%{dracutdir}/modules.d/81initoverlayfs/module-setup.sh

%changelog
* Wed Sep 27 2023 Eric Curtin <ecurtin@redhat.com> - 0.4-1
- Package initoverlayfs

