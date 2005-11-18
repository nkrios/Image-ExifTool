Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 5.77
Release: 1
License: Free
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a highly customizable Perl script for reading and writing meta
information in images.

ExifTool reads EXIF, GPS, IPTC, XMP, JFIF, GeoTIFF, ICC Profile, Photoshop
IRB and ID3 meta information from JPG, JP2, TIFF, GIF, BMP, PICT, QTIF, PNG,
MNG, JNG, MIFF, PPM, PGM, PBM, XMP, EPS, PS, AI, PDF, PSD, DCM, ACR, THM,
CRW, CR2, MRW, NEF, PEF, ORF, RAF, SRF, MOS, X3F and DNG images, MP3 and WAV
audio files, and MOV videos. ExifTool also extracts information from the
maker notes of many digital cameras by various manufacturers including
Canon, Casio, FujiFilm, Kodak, Leaf, Minolta/Konica-Minolta, Nikon,
Olympus/Epson, Panasonic/Leica, Pentax/Asahi, Ricoh, Sanyo and Sigma/Foveon.

ExifTool writes EXIF, GPS, IPTC, XMP and MakerNotes meta information to
JPEG, TIFF, GIF, PPM, PGM, PBM, PNG, MNG, JNG, CRW, THM, CR2, MRW, NEF, PEF,
MOS and DNG images.

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
