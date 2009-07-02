Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 7.82
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
  3FR   r       HTML  r       PNG   r/w    |  EXIF           r/w/c
  ACR   r       ICC   r/w/c   PPM   r/w    |  GPS            r/w/c
  AI    r       IND   r/w     PPT   r      |  IPTC           r/w/c
  AIFF  r       ITC   r       PS    r/w    |  XMP            r/w/c
  APE   r       JNG   r/w     PSD   r/w    |  MakerNotes     r/w/c
  ARW   r       JP2   r/w     QTIF  r      |  Photoshop IRB  r/w/c
  ASF   r       JPEG  r/w     RA    r      |  ICC Profile    r/w/c
  AVI   r       K25   r       RAF   r/w    |  MIE            r/w/c
  BMP   r       KDC   r       RAM   r      |  JFIF           r/w/c
  BTF   r       M4A   r       RAW   r/w    |  Ducky APP12    r/w/c
  CR2   r/w     MEF   r/w     RIFF  r      |  PDF            r/w/c
  CRW   r/w     MIE   r/w/c   RW2   r/w    |  CIFF           r/w
  CS1   r/w     MIFF  r       RWL   r/w    |  AFCP           r/w
  DCM   r       MNG   r/w     RWZ   r      |  JPEG 2000      r
  DCP   r/w     MOS   r/w     RM    r      |  DICOM          r
  DCR   r       MOV   r       SO    r      |  Flash          r
  DIVX  r       MP3   r       SR2   r      |  FlashPix       r
  DJVU  r       MP4   r       SRF   r      |  QuickTime      r
  DLL   r       MPC   r       SVG   r      |  GeoTIFF        r
  DNG   r/w     MPG   r       SWF   r      |  PrintIM        r
  DOC   r       MPO   r/w     THM   r/w    |  ID3            r
  DYLIB r       MRW   r/w     TIFF  r/w    |  Kodak Meta     r
  EPS   r/w     NEF   r/w     VRD   r/w/c  |  Ricoh RMETA    r
  ERF   r/w     NRW   r/w     WAV   r      |  Picture Info   r
  EXE   r       OGG   r       WDP   r/w    |  Adobe APP14    r
  EXIF  r/w/c   ORF   r/w     WMA   r      |  MPF            r
  FLAC  r       PBM   r/w     WMV   r      |  APE            r
  FLV   r       PDF   r/w     X3F   r      |  Vorbis         r
  FPX   r       PEF   r/w     XLS   r      |  SPIFF          r
  GIF   r/w     PGM   r/w     XMP   r/w/c  |  DjVu           r
  HDP   r/w     PICT  r       ZIP   r      |  (and more)

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
