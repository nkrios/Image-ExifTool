Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 5.46
Release: 1
License: Free
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a highly customizable Perl script for reading and writing meta
information in images.

ExifTool reads EXIF, GPS, IPTC, XMP, GeoTIFF, ICC Profile and Photoshop IRB
meta information from JPG, JP2, TIFF, GIF, BMP, PNG, MNG, JNG, MIFF, EPS,
PS, AI, PDF, PSD, THM, CRW, CR2, MRW, NEF, PEF, ORF and DNG images. 
ExifTool also extracts information from the maker notes of many digital
cameras by various manufacturers including Canon, Casio, FujiFilm, Kodak,
Minolta/Konica-Minolta, Nikon, Olympus/Epson, Panasonic/Leica, Pentax/Asahi,
Ricoh, Sanyo and Sigma/Foveon.

ExifTool writes EXIF, GPS, IPTC, XMP and MakerNotes meta information to
JPEG, TIFF, GIF, CRW, THM, CR2, NEF, PEF and DNG images.

See html/index.html for more details about ExifTool features.

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
