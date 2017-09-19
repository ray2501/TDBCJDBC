#
# spec file for package TDBDJDBC
#

Name:           TDBCJDBC
BuildRequires:  tcl
Version:        0.1.1
Release:        0
Summary:        Tcl DataBase Connectivity JDBC Driver
Url:            https://github.com/ray2501/TDBCJDBC
License:        MIT
Group:          Development/Libraries/Tcl
BuildArch:      noarch
Requires:       tcl >= 8.6
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}.tar.gz

%description
Tcl DataBase Connectivity JDBC Driver.

This extension needs Tcl >= 8.6, TDBC and tclBlend (or tclJBlend) package.

%prep
%setup -q -n %{name}

%build

%install
dir=%buildroot%{_libdir}/tcl/tcl8/8.6/tdbc
tclsh ./installer.tcl -path $dir

%files
%defattr(-,root,root)
%doc README.md
%{_libdir}/tcl/tcl8/8.6/tdbc/jdbc-0.1.1.tm

%changelog

