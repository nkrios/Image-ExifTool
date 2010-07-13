Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 8.25
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
Ricoh, Samsung, Sanyo, Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

  File Types
  ------------+-------------+-------------+-------------+------------
  3FR   r     | DVB   r     | M2TS  r     | PAGES r     | RWL   r/w
  3G2   r     | DYLIB r     | M4A/V r     | PBM   r/w   | RWZ   r
  3GP   r     | EIP   r     | MEF   r/w   | PDF   r/w   | RM    r
  ACR   r     | EPS   r/w   | MIE   r/w/c | PEF   r/w   | SO    r
  AFM   r     | ERF   r/w   | MIFF  r     | PFA   r     | SR2   r/w
  AI    r/w   | EXE   r     | MKA   r     | PFB   r     | SRF   r
  AIFF  r     | EXIF  r/w/c | MKS   r     | PFM   r     | SRW   r/w
  APE   r     | F4A/V r     | MKV   r     | PGM   r/w   | SVG   r
  ARW   r/w   | FLA   r     | MNG   r/w   | PICT  r     | SWF   r
  ASF   r     | FLAC  r     | MOS   r/w   | PMP   r     | THM   r/w
  AVI   r     | FLV   r     | MOV   r     | PNG   r/w   | TIFF  r/w
  BMP   r     | FPX   r     | MP3   r     | PPM   r/w   | TTC   r
  BTF   r     | GIF   r/w   | MP4   r     | PPT   r     | TTF   r
  COS   r     | GZ    r     | MPC   r     | PPTX  r     | VRD   r/w/c
  CR2   r/w   | HDP   r/w   | MPG   r     | PS    r/w   | WAV   r
  CRW   r/w   | HTML  r     | MPO   r/w   | PSB   r/w   | WDP   r/w
  CS1   r/w   | ICC   r/w/c | MQV   r     | PSD   r/w   | WMA   r
  DCM   r     | IIQ   r     | MRW   r/w   | PSP   r     | WMV   r
  DCP   r/w   | IND   r/w   | NEF   r/w   | QTIF  r     | X3F   r
  DCR   r     | ITC   r     | NRW   r/w   | RA    r     | XLS   r
  DFONT r     | JNG   r/w   | NUMBERS r   | RAF   r/w   | XLSX  r
  DIVX  r     | JP2   r/w   | ODP   r     | RAM   r     | XMP   r/w/c
  DJVU  r     | JPEG  r/w   | ODS   r     | RAW   r/w   | ZIP   r
  DLL   r     | K25   r     | ODT   r     | RIFF  r     |
  DNG   r/w   | KDC   r     | OGG   r     | RSRC  r     |
  DOC   r     | KEY   r     | ORF   r/w   | RTF   r     |
  DOCX  r     | LNK   r     | OTF   r     | RW2   r/w   |

  Meta Information
  ----------------------+----------------------+---------------------
  EXIF           r/w/c  |  Kodak Meta     r/w  |  Adobe APP14    r
  GPS            r/w/c  |  PhotoMechanic  r/w  |  MPF            r
  IPTC           r/w/c  |  JPEG 2000      r    |  Stim           r
  XMP            r/w/c  |  DICOM          r    |  APE            r
  MakerNotes     r/w/c  |  Flash          r    |  Vorbis         r
  Photoshop IRB  r/w/c  |  FlashPix       r    |  SPIFF          r
  ICC Profile    r/w/c  |  QuickTime      r    |  DjVu           r
  MIE            r/w/c  |  Matroska       r    |  M2TS           r
  JFIF           r/w/c  |  GeoTIFF        r    |  PE/COFF        r
  Ducky APP12    r/w/c  |  PrintIM        r    |  AVCHD          r
  PDF            r/w/c  |  ID3            r    |  ZIP            r
  CIFF           r/w    |  Ricoh RMETA    r    |  (and more)
  AFCP           r/w    |  Picture Info   r    |

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
