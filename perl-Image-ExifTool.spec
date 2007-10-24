Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 7.00
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
  ACR   r       JP2   r/w     PPT   r      |  EXIF           r/w/c
  AI    r       JPEG  r/w     PS    r/w    |  GPS            r/w/c
  AIFF  r       K25   r       PSD   r/w    |  IPTC           r/w/c
  APE   r       M4A   r       QTIF  r      |  XMP            r/w/c
  ARW   r       MEF   r/w     RA    r      |  MakerNotes     r/w/c
  ASF   r       MIE   r/w/c   RAF   r      |  Photoshop IRB  r/w/c
  AVI   r       MIFF  r       RAM   r      |  ICC Profile    r/w/c
  BMP   r       MNG   r/w     RAW   r/w    |  MIE            r/w/c
  BTF   r       MOS   r/w     RIFF  r      |  JFIF           r/w/c
  CR2   r/w     MOV   r       RM    r      |  Ducky APP12    r/w/c
  CRW   r/w     MP3   r       SR2   r      |  CIFF           r/w
  CS1   r/w     MP4   r       SRF   r      |  AFCP           r/w
  DCM   r       MPC   r       SWF   r      |  DICOM          r
  DCR   r       MPG   r       THM   r/w    |  Flash          r
  DNG   r/w     MRW   r/w     TIFF  r/w    |  FlashPix       r
  DOC   r       NEF   r/w     VRD   r/w/c  |  GeoTIFF        r
  EPS   r/w     OGG   r       WAV   r      |  PrintIM        r
  ERF   r/w     ORF   r/w     WDP   r/w    |  ID3            r
  FLAC  r       PBM   r/w     WMA   r      |  Kodak Meta     r
  FLV   r       PDF   r       WMV   r      |  Ricoh RMETA    r
  FPX   r       PEF   r/w     X3F   r      |  Picture Info   r
  GIF   r/w     PGM   r/w     XLS   r      |  Adobe APP14    r
  HTML  r       PICT  r       XMP   r/w/c  |  APE            r
  ICC   r/w/c   PNG   r/w                  |  Vorbis         r
  JNG   r/w     PPM   r/w                  |  (and more)

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
