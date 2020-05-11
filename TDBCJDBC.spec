#
# spec file for package TDBCJDBC
#

Name:           TDBCJDBC
BuildRequires:  tcl
Version:        0.2.0
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
dir=%buildroot%{tcl_noarchdir}/%{name}%{version}/tdbc
tclsh ./installer.tcl -path $dir

cat > %{buildroot}%{tcl_noarchdir}/%{name}%{version}/pkgIndex.tcl << 'EOD'
#
# Tcl package index file
#
package ifneeded tdbc::jdbc 0.2.0 \
    [list source [file join $dir tdbc jdbc-0.2.0.tm]]
EOD

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root)
%doc README.md
%{tcl_noarchdir}/%{name}%{version}

%changelog

