Name:          initoverlayfs
Version:       0.2
Release:       1%{?dist}
Summary:       An initial scalable filesystem for Linux operating systems

License:       GPLv2
URL:           https://github.com/ericcurtin/initoverlayfs
Source0:       %{url}/archive/%{version}/%{name}-%{version}.tar.gz

BuildRequires: gcc

%global dracutdir %(pkg-config --variable=dracutdir dracut)
%global debug_package %{nil}

%description
%{summary}.

%prep
%setup -q -n %{name}-%{version}

%build
gcc ${RPM_OPT_FLAGS} pre-init.c -o pre-init

%install
install -D -m644 -p pre-init ${RPM_BUILD_ROOT}/%{_prefix}/sbin/pre-init
install -D -m644 lib/dracut/modules.d/81initoverlayfs/module-setup.sh $RPM_BUILD_ROOT%{dracutdir}/modules.d/81initoverlayfs/module-setup.sh

%files
%{_prefix}/sbin/pre-init
%{dracutdir}/modules.d/81initoverlayfs/module-setup.sh

%changelog
* Wed Sep 27 2023 Eric Curtin <ecurtin@redhat.com> - 0.2-1
- Package initoverlayfs

