Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 7.67
Release: 1
License: Artistic/GPL
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a customizable set of Perl modules plus an application script
for reading and writing meta information in image, audio and video files,
including the maker note information of many digital cameras by various
manufacturers such as Canon, Casio, FujiFilm, HP, JVC/Victor, Kodak, Leaf,
Minolta/Konica-Minolta, Nikon, Olympus/Epson, Panasonic/Leica, Pentax/Asahi,
Ricoh, Sanyo, Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

                File Types                 |    Meta Information
  ---------------------------------------  |  --------------------
  3FR   r       HDP   r/w     PPM   r/w    |  EXIF           r/w/c
  ACR   r       HTML  r       PPT   r      |  GPS            r/w/c
  AI    r       ICC   r/w/c   PS    r/w    |  IPTC           r/w/c
  AIFF  r       ITC   r       PSD   r/w    |  XMP            r/w/c
  APE   r       JNG   r/w     QTIF  r      |  MakerNotes     r/w/c
  ARW   r       JP2   r/w     RA    r      |  Photoshop IRB  r/w/c
  ASF   r       JPEG  r/w     RAF   r/w    |  ICC Profile    r/w/c
  AVI   r       K25   r       RAM   r      |  MIE            r/w/c
  BMP   r       KDC   r       RAW   r/w    |  JFIF           r/w/c
  BTF   r       M4A   r       RIFF  r      |  Ducky APP12    r/w/c
  CR2   r/w     MEF   r/w     RW2   r      |  PDF            r/w/c
  CRW   r/w     MIE   r/w/c   RWZ   r      |  CIFF           r/w
  CS1   r/w     MIFF  r       RM    r      |  AFCP           r/w
  DCM   r       MNG   r/w     SO    r      |  JPEG 2000      r
  DCP   r/w     MOS   r/w     SR2   r      |  DICOM          r
  DCR   r       MOV   r       SRF   r      |  Flash          r
  DIVX  r       MP3   r       SVG   r      |  FlashPix       r
  DJVU  r       MP4   r       SWF   r      |  QuickTime      r
  DLL   r       MPC   r       THM   r/w    |  GeoTIFF        r
  DNG   r/w     MPG   r       TIFF  r/w    |  PrintIM        r
  DOC   r       MRW   r/w     VRD   r/w/c  |  ID3            r
  DYLIB r       NEF   r/w     WAV   r      |  Kodak Meta     r
  EPS   r/w     OGG   r       WDP   r/w    |  Ricoh RMETA    r
  ERF   r/w     ORF   r/w     WMA   r      |  Picture Info   r
  EXE   r       PBM   r/w     WMV   r      |  Adobe APP14    r
  EXIF  r/w/c   PDF   r/w     X3F   r      |  APE            r
  FLAC  r       PEF   r/w     XLS   r      |  Vorbis         r
  FLV   r       PGM   r/w     XMP   r/w/c  |  SPIFF          r
  FPX   r       PICT  r       ZIP   r      |  (and more)
  GIF   r/w     PNG   r/w

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
