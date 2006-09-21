Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 6.42
Release: 1
License: Free
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a customizable set of Perl libraries plus an application script
for reading and writing meta information in image, audio and video files,
including the maker note information of many digital cameras by various
manufacturers such as Canon, Casio, FujiFilm, JVC/Victor, Kodak, Leaf,
Minolta/Konica-Minolta, Nikon, Olympus/Epson, Panasonic/Leica, Pentax/Asahi,
Ricoh, Sanyo and Sigma/Foveon.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

                File Types                 |    Meta Information
  ---------------------------------------  |  --------------------
  ACR   r       MIE   r/w/c   PSD   r/w    |  EXIF           r/w/c
  AI    r       MIFF  r       QTIF  r      |  GPS            r/w/c
  AIFF  r       MNG   r/w     RA    r      |  IPTC           r/w/c
  ARW   r       MOS   r/w     RAF   r      |  XMP            r/w/c
  ASF   r       MOV   r       RAM   r      |  MakerNotes     r/w/c
  AVI   r       MP3   r       RAW   r      |  Photoshop IRB  r/w/c
  BMP   r       MP4   r       RIFF  r      |  ICC Profile    r/w/c
  CR2   r/w     MPG   r       RM    r      |  MIE            r/w/c
  CRW   r/w     MRW   r/w     SR2   r      |  JFIF           r/w
  DCM   r       NEF   r/w     SRF   r      |  CIFF           r/w
  DNG   r/w     ORF   r       SWF   r      |  AFCP           r/w
  EPS   r/w     PBM   r/w     THM   r/w    |  FlashPix       r
  ERF   r/w     PDF   r       TIFF  r/w    |  GeoTIFF        r
  FPX   r       PEF   r/w     WAV   r      |  PrintIM        r
  GIF   r/w     PGM   r/w     WDP   r/w    |  ID3            r
  ICC   r/w/c   PICT  r       WMA   r      |  Kodak Meta     r
  JNG   r/w     PNG   r/w     WMV   r      |  ASCII APP12    r
  JP2   r       PPM   r/w     X3F   r      |  Adobe APP14    r
  JPEG  r/w     PS    r/w     XMP   r/w/c  |

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
