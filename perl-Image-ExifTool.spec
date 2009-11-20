Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 8.00
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
  3FR   r       GZ    r       PEF   r/w    |  EXIF           r/w/c
  3G2   r       HDP   r/w     PGM   r/w    |  GPS            r/w/c
  3GP   r       HTML  r       PICT  r      |  IPTC           r/w/c
  ACR   r       ICC   r/w/c   PNG   r/w    |  XMP            r/w/c
  AI    r/w     IIQ   r       PPM   r/w    |  MakerNotes     r/w/c
  AIFF  r       IND   r/w     PPT   r      |  Photoshop IRB  r/w/c
  APE   r       ITC   r       PPTX  r      |  ICC Profile    r/w/c
  ARW   r       JNG   r/w     PS    r/w    |  MIE            r/w/c
  ASF   r       JP2   r/w     PSD   r/w    |  JFIF           r/w/c
  AVI   r       JPEG  r/w     QTIF  r      |  Ducky APP12    r/w/c
  BMP   r       K25   r       RA    r      |  PDF            r/w/c
  BTF   r       KDC   r       RAF   r/w    |  CIFF           r/w
  COS   r       KEY   r       RAM   r      |  AFCP           r/w
  CR2   r/w     LNK   r       RAW   r/w    |  JPEG 2000      r
  CRW   r/w     M2TS  r       RIFF  r      |  DICOM          r
  CS1   r/w     M4A/V r       RW2   r/w    |  Flash          r
  DCM   r       MEF   r/w     RWL   r/w    |  FlashPix       r
  DCP   r/w     MIE   r/w/c   RWZ   r      |  QuickTime      r
  DCR   r       MIFF  r       RM    r      |  GeoTIFF        r
  DIVX  r       MNG   r/w     SO    r      |  PrintIM        r
  DJVU  r       MOS   r/w     SR2   r      |  ID3            r
  DLL   r       MOV   r       SRF   r      |  Kodak Meta     r
  DNG   r/w     MP3   r       SVG   r      |  Ricoh RMETA    r
  DOC   r       MP4   r       SWF   r      |  Picture Info   r
  DOCX  r       MPC   r       THM   r/w    |  Adobe APP14    r
  DVB   r       MPG   r       TIFF  r/w    |  MPF            r
  DYLIB r       MPO   r/w     VRD   r/w/c  |  Stim           r
  EIP   r       MQV   r       WAV   r      |  APE            r
  EPS   r/w     MRW   r/w     WDP   r/w    |  Vorbis         r
  ERF   r/w     NEF   r/w     WMA   r      |  SPIFF          r
  EXE   r       NRW   r/w     WMV   r      |  DjVu           r
  EXIF  r/w/c   NUMBERS r     X3F   r      |  M2TS           r
  F4A/V r       OGG   r       XLS   r      |  PE/COFF        r
  FLAC  r       ORF   r/w     XLSX  r      |  AVCHD          r
  FLV   r       PAGES r       XMP   r/w/c  |  ZIP            r
  FPX   r       PBM   r/w     ZIP   r      |  (and more)
  GIF   r/w     PDF   r/w  

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
