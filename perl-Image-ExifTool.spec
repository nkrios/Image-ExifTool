Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 4.36
Release: 1
License: Free
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a highly customizable Perl script that extracts EXIF,
IPTC, XMP, GPS, GeoTIFF, ICC Profile and Photoshop IRB meta
information from JPG, TIFF, GIF, CRW, THM, CR2, MRW, NEF and DNG
images.  ExifTool also extracts information from the maker notes of
many digital cameras by various manufacturers including Canon, Casio,
FujiFilm, Minolta/Konica-Minolta, Nikon, Olympus/Epson,
Panasonic/Leica, Pentax/Asahi, Sanyo and Sigma/Foveon.

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
%{_bindir}/*

%changelog
* Sat Jun 19 2004 Kayvan Sylvan <kayvan@sylvan.com> - Image-ExifTool
- Initial build.
