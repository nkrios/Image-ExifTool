Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 8.77
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
manufacturers such as Canon, Casio, FujiFilm, GE, HP, JVC/Victor, Kodak,
Leaf, Minolta/Konica-Minolta, Nikon, Olympus/Epson, Panasonic/Leica,
Pentax/Asahi, Reconyx, Ricoh, Samsung, Sanyo, Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

  File Types
  ------------+-------------+-------------+-------------+------------
  3FR   r     | DYLIB r     | KEY   r     | OTF   r     | RWL   r/w
  3G2   r     | EIP   r     | LNK   r     | PAGES r     | RWZ   r
  3GP   r     | EPS   r/w   | M2TS  r     | PBM   r/w   | RM    r
  ACR   r     | ERF   r/w   | M4A/V r     | PDF   r/w   | SO    r
  AFM   r     | EXE   r     | MEF   r/w   | PEF   r/w   | SR2   r/w
  AI    r/w   | EXIF  r/w/c | MIE   r/w/c | PFA   r     | SRF   r
  AIFF  r     | EXR   r     | MIFF  r     | PFB   r     | SRW   r/w
  APE   r     | F4A/V r     | MKA   r     | PFM   r     | SVG   r
  ARW   r/w   | FFF   r/w   | MKS   r     | PGF   r     | SWF   r
  ASF   r     | FLA   r     | MKV   r     | PGM   r/w   | THM   r/w
  AVI   r     | FLAC  r     | MNG   r/w   | PICT  r     | TIFF  r/w
  BMP   r     | FLV   r     | MOS   r/w   | PMP   r     | TTC   r
  BTF   r     | FPX   r     | MOV   r     | PNG   r/w   | TTF   r
  CHM   r     | GIF   r/w   | MP3   r     | PPM   r/w   | VRD   r/w/c
  COS   r     | GZ    r     | MP4   r     | PPT   r     | VSD   r
  CR2   r/w   | HDP   r/w   | MPC   r     | PPTX  r     | WAV   r
  CRW   r/w   | HDR   r     | MPG   r     | PS    r/w   | WDP   r/w
  CS1   r/w   | HTML  r     | MPO   r/w   | PSB   r/w   | WEBP  r
  DCM   r     | ICC   r/w/c | MQV   r     | PSD   r/w   | WEBM  r
  DCP   r/w   | IDML  r     | MRW   r/w   | PSP   r     | WMA   r
  DCR   r     | IIQ   r/w   | MXF   r     | QTIF  r     | WMV   r
  DFONT r     | IND   r/w   | NEF   r/w   | RA    r     | X3F   r/w
  DIVX  r     | INX   r     | NRW   r/w   | RAF   r/w   | XCF   r
  DJVU  r     | ITC   r     | NUMBERS r   | RAM   r     | XLS   r
  DLL   r     | J2C   r     | ODP   r     | RAR   r     | XLSX  r
  DNG   r/w   | JNG   r/w   | ODS   r     | RAW   r/w   | XMP   r/w/c
  DOC   r     | JP2   r/w   | ODT   r     | RIFF  r     | ZIP   r
  DOCX  r     | JPEG  r/w   | OGG   r     | RSRC  r     |
  DV    r     | K25   r     | OGV   r     | RTF   r     |
  DVB   r     | KDC   r     | ORF   r/w   | RW2   r/w   |

  Meta Information
  ----------------------+----------------------+---------------------
  EXIF           r/w/c  |  CIFF           r/w  |  Ricoh RMETA    r
  GPS            r/w/c  |  AFCP           r/w  |  Picture Info   r
  IPTC           r/w/c  |  Kodak Meta     r/w  |  Adobe APP14    r
  XMP            r/w/c  |  FotoStation    r/w  |  MPF            r
  MakerNotes     r/w/c  |  PhotoMechanic  r/w  |  Stim           r
  Photoshop IRB  r/w/c  |  JPEG 2000      r    |  APE            r
  ICC Profile    r/w/c  |  DICOM          r    |  Vorbis         r
  MIE            r/w/c  |  Flash          r    |  SPIFF          r
  JFIF           r/w/c  |  FlashPix       r    |  DjVu           r
  Ducky APP12    r/w/c  |  QuickTime      r    |  M2TS           r
  PDF            r/w/c  |  Matroska       r    |  PE/COFF        r
  PNG            r/w/c  |  GeoTIFF        r    |  AVCHD          r
  Canon VRD      r/w/c  |  PrintIM        r    |  ZIP            r
  Nikon Capture  r/w/c  |  ID3            r    |  (and more)

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
