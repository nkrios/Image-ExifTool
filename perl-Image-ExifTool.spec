Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 6.57
Release: 1
License: Free
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a customizable set of Perl modules plus an application script
for reading and writing meta information in image, audio and video files,
including the maker note information of many digital cameras by various
manufacturers such as Canon, Casio, FujiFilm, JVC/Victor, Kodak, Leaf,
Minolta/Konica-Minolta, Nikon, Olympus/Epson, Panasonic/Leica, Pentax/Asahi,
Ricoh, Sanyo, Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

                File Types                 |    Meta Information
  ---------------------------------------  |  --------------------
  ACR   r       M4A   r       PS    r/w    |  EXIF           r/w/c
  AI    r       MIE   r/w/c   PSD   r/w    |  GPS            r/w/c
  AIFF  r       MIFF  r       QTIF  r      |  IPTC           r/w/c
  APE   r       MNG   r/w     RA    r      |  XMP            r/w/c
  ARW   r       MOS   r/w     RAF   r      |  MakerNotes     r/w/c
  ASF   r       MOV   r       RAM   r      |  Photoshop IRB  r/w/c
  AVI   r       MP3   r       RAW   r      |  ICC Profile    r/w/c
  BMP   r       MP4   r       RIFF  r      |  MIE            r/w/c
  CR2   r/w     MPC   r       RM    r      |  JFIF           r/w/c
  CRW   r/w     MPG   r       SR2   r      |  CIFF           r/w
  DCM   r       MRW   r/w     SRF   r      |  AFCP           r/w
  DNG   r/w     NEF   r/w     SWF   r      |  FlashPix       r
  EPS   r/w     OGG   r       THM   r/w    |  GeoTIFF        r
  ERF   r/w     ORF   r/w     TIFF  r/w    |  PrintIM        r
  FLAC  r       PBM   r/w     VRD   r/w    |  ID3            r
  FPX   r       PDF   r       WAV   r      |  Kodak Meta     r
  GIF   r/w     PEF   r/w     WDP   r/w    |  Ricoh RMETA    r
  ICC   r/w/c   PGM   r/w     WMA   r      |  Picture Info   r
  JNG   r/w     PICT  r       WMV   r      |  Adobe APP14    r
  JP2   r       PNG   r/w     X3F   r      |  APE            r
  JPEG  r/w     PPM   r/w     XMP   r/w/c  |  (and more)

See html/index.html for more details about ExifTool features.

%prep
%setup -n Image-ExifTool-%{version}

%build
perl Makefile.PL INSTALLDIRS=vendor

%install
rm -rf $RPM_BUILD_ROOT
%makeinstall DESTDIR=%{?buildroot:%{buildroot}}
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
* Tue May 09 2006 - Niels Kristian Bech Jensen <nkbj@mail.tele.dk>
- Spec file fixed for Mandriva Linux 2006.
* Mon May 08 2006 - Volker Kuhlmann <VolkerKuhlmann@gmx.de>
- Spec file fixed for SUSE.
- Package available from: http://volker.dnsalias.net/soft/
* Sat Jun 19 2004 Kayvan Sylvan <kayvan@sylvan.com> - Image-ExifTool
- Initial build.
