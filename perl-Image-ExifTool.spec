Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 6.76
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
  ACR   r       M4A   r       PSD   r/w    |  EXIF           r/w/c
  AI    r       MIE   r/w/c   QTIF  r      |  GPS            r/w/c
  AIFF  r       MIFF  r       RA    r      |  IPTC           r/w/c
  APE   r       MNG   r/w     RAF   r      |  XMP            r/w/c
  ARW   r       MOS   r/w     RAM   r      |  MakerNotes     r/w/c
  ASF   r       MOV   r       RAW   r      |  Photoshop IRB  r/w/c
  AVI   r       MP3   r       RIFF  r      |  ICC Profile    r/w/c
  BMP   r       MP4   r       RM    r      |  MIE            r/w/c
  CR2   r/w     MPC   r       SR2   r      |  JFIF           r/w/c
  CRW   r/w     MPG   r       SRF   r      |  CIFF           r/w
  DCM   r       MRW   r/w     SWF   r      |  AFCP           r/w
  DNG   r/w     NEF   r/w     THM   r/w    |  DICOM          r
  DOC   r       OGG   r       TIFF  r/w    |  FlashPix       r
  EPS   r/w     ORF   r/w     VRD   r/w    |  GeoTIFF        r
  ERF   r/w     PBM   r/w     WAV   r      |  PrintIM        r
  FLAC  r       PDF   r       WDP   r/w    |  ID3            r
  FPX   r       PEF   r/w     WMA   r      |  Kodak Meta     r
  GIF   r/w     PGM   r/w     WMV   r      |  Ricoh RMETA    r
  HTML  r       PICT  r       X3F   r      |  Picture Info   r
  ICC   r/w/c   PNG   r/w     XLS   r      |  Adobe APP14    r
  JNG   r/w     PPM   r/w     XMP   r/w/c  |  APE            r
  JP2   r       PPT   r                    |  Vorbis         r
  JPEG  r/w     PS    r/w                  |  (and more)

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
