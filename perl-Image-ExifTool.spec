Summary: perl module for image data extraction 
Name: perl-Image-ExifTool
Version: 6.29
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
supported by ExifTool (r = read support, w = write support):

                 File Type                      Meta Information
    -----------------------------------        ------------------
    JPEG  r/w     ICC   r/w     MIFF  r        EXIF           r/w
    TIFF  r/w     MIE   r/w     PICT  r        GPS            r/w
    GIF   r/w     PPM   r/w     QTIF  r        IPTC           r/w
    CRW   r/w     PGM   r/w     RIFF  r        XMP            r/w
    CR2   r/w     PBM   r/w     AIFF  r        MakerNotes     r/w
    ERF   r/w     WDP   r/w     AVI   r        Photoshop IRB  r/w
    NEF   r/w     JP2   r       WAV   r        AFCP           r/w
    PEF   r/w     BMP   r       MPG   r        JFIF           r/w
    MRW   r/w     FPX   r       MP3   r        ICC Profile    r/w
    MOS   r/w     ORF   r       MP4   r        MIE            r/w
    DNG   r/w     RAF   r       MOV   r        FlashPix       r
    PNG   r/w     RAW   r       ASF   r        GeoTIFF        r
    MNG   r/w     SRF   r       WMA   r        PrintIM        r
    JNG   r/w     SR2   r       WMV   r        ID3            r
    XMP   r/w     X3F   r       RA    r
    THM   r/w     DCM   r       RM    r
    PSD   r/w     ACR   r       RAM   r
    EPS   r/w     AI    r       SWF   r
    PS    r/w     PDF   r

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
