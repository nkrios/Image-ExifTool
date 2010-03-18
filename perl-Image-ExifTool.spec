Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 8.15
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

  File Types
  ------------+-------------+-------------+-------------+------------
  3FR   r     | DOC   r     | K25   r     | PAGES r     | RWZ   r
  3G2   r     | DOCX  r     | KDC   r     | PBM   r/w   | RM    r
  3GP   r     | DVB   r     | KEY   r     | PDF   r/w   | SO    r
  ACR   r     | DYLIB r     | LNK   r     | PEF   r/w   | SR2   r/w
  AFM   r     | EIP   r     | M2TS  r     | PFA   r     | SRF   r
  AI    r/w   | EPS   r/w   | M4A/V r     | PFB   r     | SRW   r/w
  AIFF  r     | ERF   r/w   | MEF   r/w   | PFM   r     | SVG   r
  APE   r     | EXE   r     | MIE   r/w/c | PGM   r/w   | SWF   r
  ARW   r/w   | EXIF  r/w/c | MIFF  r     | PICT  r     | THM   r/w
  ASF   r     | F4A/V r     | MNG   r/w   | PNG   r/w   | TIFF  r/w
  AVI   r     | FLA   r     | MOS   r/w   | PPM   r/w   | TTC   r
  BMP   r     | FLAC  r     | MOV   r     | PPT   r     | TTF   r
  BTF   r     | FLV   r     | MP3   r     | PPTX  r     | VRD   r/w/c
  COS   r     | FPX   r     | MP4   r     | PS    r/w   | WAV   r
  CR2   r/w   | GIF   r/w   | MPC   r     | PSB   r/w   | WDP   r/w
  CRW   r/w   | GZ    r     | MPG   r     | PSD   r/w   | WMA   r
  CS1   r/w   | HDP   r/w   | MPO   r/w   | PSP   r     | WMV   r
  DCM   r     | HTML  r     | MQV   r     | QTIF  r     | X3F   r
  DCP   r/w   | ICC   r/w/c | MRW   r/w   | RA    r     | XLS   r
  DCR   r     | IIQ   r     | NEF   r/w   | RAF   r/w   | XLSX  r
  DFONT r     | IND   r/w   | NRW   r/w   | RAM   r     | XMP   r/w/c
  DIVX  r     | ITC   r     | NUMBERS r   | RAW   r/w   | ZIP   r
  DJVU  r     | JNG   r/w   | OGG   r     | RIFF  r     |
  DLL   r     | JP2   r/w   | ORF   r/w   | RW2   r/w   |
  DNG   r/w   | JPEG  r/w   | OTF   r     | RWL   r/w   |

  Meta Information
  ----------------------+----------------------+---------------------
  EXIF           r/w/c  |  JPEG 2000      r    |  APE            r
  GPS            r/w/c  |  DICOM          r    |  Vorbis         r
  IPTC           r/w/c  |  Flash          r    |  SPIFF          r
  XMP            r/w/c  |  FlashPix       r    |  DjVu           r
  MakerNotes     r/w/c  |  QuickTime      r    |  M2TS           r
  Photoshop IRB  r/w/c  |  GeoTIFF        r    |  PE/COFF        r
  ICC Profile    r/w/c  |  PrintIM        r    |  AVCHD          r
  MIE            r/w/c  |  ID3            r    |  ZIP            r
  JFIF           r/w/c  |  Kodak Meta     r    |  (and more)
  Ducky APP12    r/w/c  |  Ricoh RMETA    r    |
  PDF            r/w/c  |  Picture Info   r    |
  CIFF           r/w    |  Adobe APP14    r    |
  AFCP           r/w    |  MPF            r    |
  PhotoMechanic  r/w    |  Stim           r    |

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
