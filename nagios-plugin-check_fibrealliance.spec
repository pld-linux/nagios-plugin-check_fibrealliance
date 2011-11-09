%define		plugin	check_fibrealliance
Summary:	Nagios plugin to check Check SAN Switch Health
Name:		nagios-plugin-%{plugin}
Version:	0.0.3
Release:	0.1
# assume same as Nagios
License:	GPL v2
Group:		Networking
Source0:	http://exchange.nagios.org/components/com_mtree/attachment.php?link_id=1993&cf_id=24/%{plugin}.sh
# Source0-md5:	01999269f2b12c78f4682405b3826ab8
Source1:	%{plugin}.cfg
URL:		http://exchange.nagios.org/directory/Plugins/Hardware/Storage-Systems/SAN-and-NAS/Check-SAN-Switch-Health/details
Requires:	nagios-common
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%define		_noautoreq	perl(utils)

%define		_sysconfdir	/etc/nagios/plugins
%define		plugindir	%{_prefix}/lib/nagios/plugins

%description
This plugin checks sensors (PSU, temperature, fans et al) and overall health of
SAN switches that understand the Fibre Alliance MIB. There is a long list of
companies behind that MIB.

%prep
%setup -qcT
cp -p %{SOURCE0} %{plugin}

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT{%{_sysconfdir},%{plugindir}}
install -p %{plugin} $RPM_BUILD_ROOT%{plugindir}/%{plugin}
cp -p %{SOURCE1} $RPM_BUILD_ROOT%{_sysconfdir}/%{plugin}.cfg

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%attr(640,root,nagios) %config(noreplace) %verify(not md5 mtime size) %{_sysconfdir}/%{plugin}.cfg
%attr(755,root,root) %{plugindir}/%{plugin}
