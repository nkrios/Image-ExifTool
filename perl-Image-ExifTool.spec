Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 3.72
Release: 1
License: Free
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a highly customizable Perl script that extracts meta
information from JPG, TIFF, CRW, CR2, THM, NEF and GIF images.
ExifTool can read EXIF, IPTC, XMP and GeoTIFF formatted data as well
as the maker notes of many digital cameras from various manufacturers
including Canon, Casio, FujiFilm, Minolta, Nikon, Olympus, Pentax,
Sanyo and Sigma.

%prep
%setup -n Image-ExifTool-%{version}

%build
perl Makefile.PL PREFIX=$RPM_BUILD_ROOT%{_prefix}

%install
rm -rf $RPM_BUILD_ROOT
make PREFIX=$RPM_BUILD_ROOT%{_prefix} install
find $RPM_BUILD_ROOT -name perllocal.pod | xargs rm

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc Changes html
/usr/lib/perl5/*
%{_mandir}/*/*

%changelog
* Sat Jun 19 2004 Kayvan Sylvan <kayvan@sylvan.com> - Image-ExifTool
- Initial build.
