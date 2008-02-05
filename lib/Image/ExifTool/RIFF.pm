#------------------------------------------------------------------------------
# File:         RIFF.pm
#
# Description:  Read RIFF/WAV/AVI meta information
#
# Revisions:    09/14/2005 - P. Harvey Created
#
# References:   1) http://www.exif.org/Exif2-2.PDF
#               2) http://www.vlsi.fi/datasheets/vs1011.pdf
#               3) http://www.music-center.com.br/spec_rif.htm
#               4) http://www.codeproject.com/audio/wavefiles.asp
#               5) http://msdn.microsoft.com/archive/en-us/directx9_c/directx/htm/avirifffilereference.asp
#               6) http://research.microsoft.com/invisible/tests/riff.h.htm
#               7) http://www.onicos.com/staff/iz/formats/wav.html
#               8) http://graphics.cs.uni-sb.de/NMM/dist-0.9.1/Docs/Doxygen/html/mmreg_8h-source.html
#               9) http://developers.videolan.org/vlc/vlc/doc/doxygen/html/codecs_8h-source.html
#------------------------------------------------------------------------------

package Image::ExifTool::RIFF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.10';

# type of current stream
$Image::ExifTool::RIFF::streamType = '';

my %riffEncoding = ( #2
    0x01 => 'Microsoft PCM',
    0x02 => 'Microsoft ADPCM',
    0x03 => 'Microsoft IEEE float',
    0x04 => 'Compaq VSELP', #4
    0x05 => 'IBM CVSD', #4
    0x06 => 'Microsoft a-Law',
    0x07 => 'Microsoft u-Law',
    0x08 => 'Microsoft DTS', #4
    0x09 => 'DRM', #4
    0x0a => 'WMA 9 Speech', #9
    0x10 => 'OKI-ADPCM',
    0x11 => 'Intel IMA/DVI-ADPCM',
    0x12 => 'Videologic Mediaspace ADPCM', #4
    0x13 => 'Sierra ADPCM', #4
    0x14 => 'Antex G.723 ADPCM', #4
    0x15 => 'DSP Solutions DIGISTD',
    0x16 => 'DSP Solutions DIGIFIX',
    0x17 => 'Dialoic OKI ADPCM', #6
    0x18 => 'Media Vision ADPCM', #6
    0x19 => 'HP CU', #7
    0x20 => 'Yamaha ADPCM', #6
    0x21 => 'SONARC Speech Compression', #6
    0x22 => 'DSP Group True Speech', #6
    0x23 => 'Echo Speech Corp.', #6
    0x24 => 'Virtual Music Audiofile AF36', #6
    0x25 => 'Audio Processing Tech.', #6
    0x26 => 'Virtual Music Audiofile AF10', #6
    0x27 => 'Aculab Prosody 1612', #7
    0x28 => 'Merging Tech. LRC', #7
    0x30 => 'Dolby AC2',
    0x31 => 'Microsoft GSM610',
    0x32 => 'MSN Audio', #6
    0x33 => 'Antex ADPCME', #6
    0x34 => 'Control Resources VQLPC', #6
    0x35 => 'DSP Solutions DIGIREAL', #6
    0x36 => 'DSP Solutions DIGIADPCM', #6
    0x37 => 'Control Resources CR10', #6
    0x38 => 'Natural MicroSystems VBX ADPCM', #6
    0x39 => 'Crystal Semiconductor IMA ADPCM', #6
    0x3a => 'Echo Speech ECHOSC3', #6
    0x3b => 'Rockwell ADPCM',
    0x3c => 'Rockwell DIGITALK',
    0x3d => 'Xebec Multimedia', #6
    0x40 => 'Antex G.721 ADPCM',
    0x41 => 'Antex G.728 CELP',
    0x42 => 'Microsoft MSG723', #7
    0x45 => 'ITU-T G.726', #9
    0x50 => 'Microsoft MPEG',
    0x51 => 'RT23 or PAC', #7
    0x52 => 'InSoft RT24', #4
    0x53 => 'InSoft PAC', #4
    0x55 => 'MP3',
    0x59 => 'Cirrus', #7
    0x60 => 'Cirrus Logic', #6
    0x61 => 'ESS Tech. PCM', #6
    0x62 => 'Voxware Inc.', #6
    0x63 => 'Canopus ATRAC', #6
    0x64 => 'APICOM G.726 ADPCM',
    0x65 => 'APICOM G.722 ADPCM',
    0x66 => 'Microsoft DSAT', #6
    0x67 => 'Micorsoft DSAT DISPLAY', #6
    0x69 => 'Voxware Byte Aligned', #7
    0x70 => 'Voxware AC8', #7
    0x71 => 'Voxware AC10', #7
    0x72 => 'Voxware AC16', #7
    0x73 => 'Voxware AC20', #7
    0x74 => 'Voxware MetaVoice', #7
    0x75 => 'Voxware MetaSound', #7
    0x76 => 'Voxware RT29HW', #7
    0x77 => 'Voxware VR12', #7
    0x78 => 'Voxware VR18', #7
    0x79 => 'Voxware TQ40', #7
    0x80 => 'Soundsoft', #6
    0x81 => 'Voxware TQ60', #7
    0x82 => 'Microsoft MSRT24', #7
    0x83 => 'AT&T G.729A', #7
    0x84 => 'Motion Pixels MVI MV12', #7
    0x85 => 'DataFusion G.726', #7
    0x86 => 'DataFusion GSM610', #7
    0x88 => 'Iterated Systems Audio', #7
    0x89 => 'Onlive', #7
    0x91 => 'Siemens SBC24', #7
    0x92 => 'Sonic Foundry Dolby AC3 APDIF', #7
    0x93 => 'MediaSonic G.723', #8
    0x94 => 'Aculab Prosody 8kbps', #8
    0x97 => 'ZyXEL ADPCM', #7,
    0x98 => 'Philips LPCBB', #7
    0x99 => 'Studer Professional Audio Packed', #7
    0xa0 => 'Malden PhonyTalk', #8
    0x100 => 'Rhetorex ADPCM', #6
    0x101 => 'IBM u-Law', #3
    0x102 => 'IBM a-Law', #3
    0x103 => 'IBM ADPCM', #3
    0x111 => 'Vivo G.723', #7
    0x112 => 'Vivo Siren', #7
    0x123 => 'Digital G.723', #7
    0x125 => 'Sanyo LD ADPCM', #8
    0x130 => 'Sipro Lab ACEPLNET', #8
    0x131 => 'Sipro Lab ACELP4800', #8
    0x132 => 'Sipro Lab ACELP8V3', #8
    0x133 => 'Sipro Lab G.729', #8
    0x134 => 'Sipro Lab G.729A', #8
    0x135 => 'Sipro Lab Kelvin', #8
    0x140 => 'Dictaphone G.726 ADPCM', #8
    0x150 => 'Qualcomm PureVoice', #8
    0x151 => 'Qualcomm HalfRate', #8
    0x155 => 'Ring Zero Systems TUBGSM', #8
    0x160 => 'Microsoft Audio1', #8
    0x200 => 'Creative Labs ADPCM', #6
    0x202 => 'Creative Labs FASTSPEECH8', #6
    0x203 => 'Creative Labs FASTSPEECH10', #6
    0x210 => 'UHER ADPCM', #8
    0x220 => 'Quarterdeck Corp.', #6
    0x230 => 'I-Link VC', #8
    0x240 => 'Aureal Semiconductor Raw Sport', #8
    0x250 => 'Interactive Products HSX', #8
    0x251 => 'Interactive Products RPELP', #8
    0x260 => 'Consistent CS2', #8
    0x270 => 'Sony SCX', #8
    0x300 => 'Fujitsu FM TOWNS SND', #6
    0x400 => 'Brooktree Digital', #6
    0x450 => 'QDesign Music', #8
    0x680 => 'AT&T VME VMPCM', #7
    0x681 => 'AT&T TCP', #8
    0x1000 => 'Olivetti GSM', #6
    0x1001 => 'Olivetti ADPCM', #6
    0x1002 => 'Olivetti CELP', #6
    0x1003 => 'Olivetti SBC', #6
    0x1004 => 'Olivetti OPR', #6
    0x1100 => 'Lernout & Hauspie', #6
    0x1400 => 'Norris Comm. Inc.', #6
    0x1401 => 'ISIAudio', #7
    0x1500 => 'AT&T Soundspace Music Compression', #7
    0x2000 => 'FAST Multimedia DVM', #7
    0xfffe => 'Extensible', #7
    0xffff => 'Development', #4
);

# RIFF info
%Image::ExifTool::RIFF::Main = (
    PROCESS_PROC => \&Image::ExifTool::RIFF::ProcessChunks,
    NOTES => q{
        Windows WAV and AVI files are RIFF format files.  Meta information embedded
        in two types of RIFF C<LIST> chunks: C<INFO> and C<exif>.  As well, some
        information about the audio content is extracted from the C<fmt > chunk.
    },
   'fmt ' => {
        Name => 'AudioFormat',
        SubDirectory => { TagTable => 'Image::ExifTool::RIFF::AudioFormat' },
    },
    LIST_INFO => {
        Name => 'Info',
        SubDirectory => { TagTable => 'Image::ExifTool::RIFF::Info' },
    },
    LIST_exif => {
        Name => 'Exif',
        SubDirectory => { TagTable => 'Image::ExifTool::RIFF::Exif' },
    },
    LIST_hdrl => { # AVI header LIST chunk
        Name => 'Hdrl',
        SubDirectory => { TagTable => 'Image::ExifTool::RIFF::Hdrl' },
    },
);

# Format and Audio Stream Format chunk data
%Image::ExifTool::RIFF::AudioFormat = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    FORMAT => 'int16u',
    0 => {
        Name => 'Encoding',
        PrintHex => 1,
        PrintConv => \%riffEncoding,
    },
    1 => 'NumChannels',
    2 => {
        Name => 'SampleRate',
        Format => 'int32u',
    },
    4 => {
        Name => 'AvgBytesPerSec',
        Format => 'int32u',
    },
   # uninteresting
   # 6 => 'BlockAlignment',
    7 => 'BitsPerSample',
);

# Sub chunks of INFO LIST chunk
%Image::ExifTool::RIFF::Info = (
    PROCESS_PROC => \&Image::ExifTool::RIFF::ProcessChunks,
    GROUPS => { 2 => 'Audio' },
    IARL => 'ArchivalLocation',
    IART => { Name => 'Artist',    Groups => { 2 => 'Author' } },
    ICMS => 'Commissioned',
    ICMT => 'Comment',
    ICOP => { Name => 'Copyright', Groups => { 2 => 'Author' } },
    ICRD => {
        Name => 'DateCreated',
        Groups => { 2 => 'Time' },
        ValueConv => '$_=$val; s/-/:/g; s/\0.*//s; $_',
    },
    ICRP => 'Cropped',
    IDIM => 'Dimensions',
    IDPI => 'DotsPerInch',
    IENG => 'Engineer',
    IGNR => 'Genre',
    IKEY => 'Keywords',
    ILGT => 'Lightness',
    IMED => 'Medium',
    INAM => 'Title',
    IPLT => 'NumColors',
    IPRD => 'Product',
    ISBJ => 'Subject',
    ISFT => 'Software',
    ISHP => 'Sharpness',
    ISRC => 'Source',
    ISRF => 'SourceForm',
    ITCH => 'Technician',
);

# Sub chunks of EXIF LIST chunk
%Image::ExifTool::RIFF::Exif = (
    PROCESS_PROC => \&Image::ExifTool::RIFF::ProcessChunks,
    GROUPS => { 2 => 'Audio' },
    ever => 'ExifVersion',
    erel => 'RelatedImageFile',
    etim => { Name => 'TimeCreated', Groups => { 2 => 'Time' } },
    ecor => { Name => 'Make',        Groups => { 2 => 'Camera' } },
    emdl => { Name => 'Model',       Groups => { 2 => 'Camera' } },
    emnt => { Name => 'MakerNotes',  Binary => 1 },
    eucm => {
        Name => 'UserComment',
        PrintConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val)',
    },
);

# Sub chunks of hdrl LIST chunk
%Image::ExifTool::RIFF::Hdrl = (
    PROCESS_PROC => \&Image::ExifTool::RIFF::ProcessChunks,
    GROUPS => { 2 => 'Image' },
    avih => {
        Name => 'AVIHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::RIFF::AVIHeader' },
    },
    IDIT => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::RIFF::ConvertRIFFDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ISMP => 'TimeCode',
    LIST_strl => {
        Name => 'Stream',
        SubDirectory => { TagTable => 'Image::ExifTool::RIFF::Stream' },
    },
);

%Image::ExifTool::RIFF::AVIHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'FrameRate',
        ValueConv => '$val ? 1e6 / $val : undef',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
    },
    1 => {
        Name => 'MaxDataRate',
        PrintConv => 'sprintf("%.4g kB/s",$val / 1024)',
    },
  # 2 => 'PaddingGranularity',
  # 3 => 'Flags',
    4 => 'FrameCount',
  # 5 => 'InitialFrames',
    6 => 'StreamCount',
  # 7 => 'SuggestedBufferSize',
    8 => 'ImageWidth',
    9 => 'ImageHeight',
);

%Image::ExifTool::RIFF::Stream = (
    PROCESS_PROC => \&Image::ExifTool::RIFF::ProcessChunks,
    GROUPS => { 2 => 'Image' },
    strh => {
        Name => 'StreamHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::RIFF::StreamHeader' },
    },
    strn => 'StreamName',
    strd => { #PH
        Name => 'StreamData',
        SubDirectory => { TagTable => 'Image::ExifTool::RIFF::StreamData' },
    },
    strf => [
        {
            Name => 'AudioFormat',
            Condition => '$Image::ExifTool::RIFF::streamType eq "auds"',
            SubDirectory => { TagTable => 'Image::ExifTool::RIFF::AudioFormat' },
        },
        {
            Name => 'VideoFormat',
            Condition => '$Image::ExifTool::RIFF::streamType eq "vids"',
            SubDirectory => { TagTable => 'Image::ExifTool::BMP::Main' },
        },
    ],
);

%Image::ExifTool::RIFF::StreamHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'StreamType',
        Format => 'string[4]',
        RawConv => '$Image::ExifTool::RIFF::streamType = $val',
        PrintConv => {
            auds => 'Audio',
            mids => 'MIDI',
            txts => 'Text',
            vids => 'Video',
        },
    },
    1 => {
        Name => 'Codec',
        Format => 'string[4]',
    },
  # 2 => 'StreamFlags',
  # 3 => 'StreamPriority',
  # 3.5 => 'Language',
  # 4 => 'InitialFrames',
  # 5 => 'Scale',
  # 6 => 'Rate',
  # 7 => 'Start',
  # 8 => 'Length',
  # 9 => 'SuggestedBufferSize',
    10 => 'Quality',
    11 => {
        Name => 'SampleSize',
        PrintConv => '$val ? "$val byte" . ($val==1 ? "" : "s") : "Variable"',
    },
  # 12 => { Name => 'Frame', Format => 'int16u[4]' },
);

%Image::ExifTool::RIFF::StreamData = ( #PH
    PROCESS_PROC => \&Image::ExifTool::RIFF::ProcessStreamData,
    GROUPS => { 2 => 'Video' },
    NOTES => 'This chunk contains EXIF information in FujiFilm F30 AVI files.',
    AVIF => {
        Name => 'AVIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            DirName => 'IFD0',
            Start => 8,
            ByteOrder => 'II',
        },
    },
);

# RIFF composite tags
%Image::ExifTool::RIFF::Composite = (
    Duration => {
        Require => {
            0 => 'FrameRate',
            1 => 'FrameCount',
        },
        ValueConv => '$val[0] ? $val[1] / $val[0] : undef',
        PrintConv => 'sprintf("%.2f s",$val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::RIFF');


#------------------------------------------------------------------------------
# Convert RIFF date to EXIF format
my %monthNum = (
    Jan=>1, Feb=>2, Mar=>3, Apr=>4, May=>5, Jun=>6,
    Jul=>7, Aug=>8, Sep=>9, Oct=>10,Nov=>11,Dec=>12
);
sub ConvertRIFFDate($)
{
    my $val = shift;
    my @part = split ' ', $val;
    my $mon;
    if (@part >= 5 and $mon = $monthNum{ucfirst(lc($part[1]))}) {
        # the standard AVI date format (ie. "Mon Mar 10 15:04:43 2003")
        $val = sprintf("%.4d:%.2d:%.2d %s", $part[4],
                       $mon, $part[2], $part[3]);
    } elsif ($val =~ m{(\d{4})/\s*(\d+)/\s*(\d+)/?\s+(\d+):\s*(\d+)\s*(P?)}) {
        # but the Casio QV-3EX writes dates like "2001/ 1/27  1:42PM",
        # and the Casio EX-Z30 writes "2005/11/28/ 09:19"... doh!
        $val = sprintf("%.4d:%.2d:%.2d %.2d:%.2d:00",$1,$2,$3,$4+($6?12:0),$5);
    }
    return $val;
}

#------------------------------------------------------------------------------
# Process stream data
# Inputs: 0) ExifTool object ref, 1) dirInfo reference, 2) tag table ref
# Returns: 1 on success
sub ProcessStreamData($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    return 0 if $size < 4;
    if ($exifTool->Options('Verbose')) {
        $exifTool->VerboseDir($$dirInfo{DirName}, 0, $size);
    }
    my $tag = substr($$dataPt, $start, 4);
    my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
    my $subdir = $$tagInfo{SubDirectory};
    if ($subdir) {
        my $offset = $$subdir{Start} || 0;
        my $baseShift = $$dirInfo{DataPos} + $$dirInfo{DirStart} + $offset;
        my %subdirInfo = (
            DataPt  => $dataPt,
            DataPos => $$dirInfo{DataPos} - $baseShift,
            Base    => ($$dirInfo{Base} || 0) + $baseShift,
            DataLen => $$dirInfo{DataLen},
            DirStart=> $$dirInfo{DirStart} + $offset,
            DirLen  => $$dirInfo{DirLen} - $offset,
            DirName => $$subdir{DirName},
            Parent  => $$dirInfo{DirName},
        );
        # (we could set FIRST_EXIF_POS to $subdirInfo{Base} here to make
        #  htmlDump offsets relative to EXIF base if we wanted...)
        my $subTable = GetTagTable($$subdir{TagTable});
        $exifTool->ProcessDirectory(\%subdirInfo, $subTable);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process RIFF chunks
# Inputs: 0) ExifTool object reference, 1) directory information reference
#         2) tag table reference
# Returns: 1 on success
sub ProcessChunks($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $end = $start + $size;

    if ($exifTool->Options('Verbose')) {
        $exifTool->VerboseDir($$dirInfo{DirName}, 0, $size);
    }
    while ($start + 8 < $end) {
        my $tag = substr($$dataPt, $start, 4);
        my $len = Get32u($dataPt, $start + 4);
        $start += 8;
        if ($start + $len > $end) {
            $exifTool->Warn("Bad $tag chunk");
            return 0;
        }
        if ($tag eq 'LIST' and $len >= 4) {
            $tag .= '_' . substr($$dataPt, $start, 4);
            $len -= 4;
            $start += 4;
        }
        $exifTool->HandleTag($tagTablePtr, $tag, undef,
            DataPt => $dataPt,
            DataPos => $$dirInfo{DataPos},
            Start => $start,
            Size => $len,
        );
        ++$len if $len & 0x01;  # must account for padding if odd number of bytes
        $start += $len;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from a RIFF file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid RIFF file
sub ProcessRIFF($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $err);
    my %types = ( 'WAVE' => 'WAV', 'AVI ' => 'AVI' );

    # verify this is a valid RIFF file
    return 0 unless $raf->Read($buff, 12) == 12;
    return 0 unless $buff =~ /^RIFF....(.{4})/s;
    $exifTool->SetFileType($types{$1}); # set type to 'WAV', 'AVI' or 'RIFF'
    $Image::ExifTool::RIFF::streamType = '';    # initialize stream type
    SetByteOrder('II');
    my $tagTablePtr = GetTagTable('Image::ExifTool::RIFF::Main');
    my $pos = 12;
#
# Read chunks in RIFF image until we get to the 'data' chunk
#
    for (;;) {
        $raf->Read($buff, 8) == 8 or $err=1, last;
        $pos += 8;
        my ($tag, $len) = unpack('a4V', $buff);
        # special case: construct new tag name from specific LIST type
        if ($tag eq 'LIST') {
            $raf->Read($buff, 4) == 4 or $err=1, last;
            $pos += 4;
            $tag .= "_$buff";
            $len -= 4;  # already read 4 bytes (the LIST type)
        }
        $exifTool->VPrint(0, "RIFF '$tag' chunk ($len bytes of data):\n");
        # stop when we hit the audio data or AVI index or AVI movie data
        if ($tag eq 'data' or $tag eq 'idx1' or $tag eq 'LIST_movi') {
            $exifTool->VPrint(0, "(end of parsing)\n");
            last;
        }
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        # RIFF chunks are padded to an even number of bytes
        my $len2 = $len + ($len & 0x01);
        if ($tagInfo and $$tagInfo{SubDirectory}) {
            $raf->Read($buff, $len2) == $len2 or $err=1, last;
            my %dirInfo = (
                DataPt => \$buff,
                DataPos => $pos,
                DirStart => 0,
                DirLen => $len,
            );
            my $tagTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            $exifTool->ProcessDirectory(\%dirInfo, $tagTablePtr);
        } else {
            $raf->Seek($len2, 1) or $err=1, last;
        }
        $pos += $len2;
    }
    $err and $exifTool->Warn('Error reading RIFF file (corrupted?)');
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::RIFF - Read RIFF/WAV/AVI meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from RIFF-based (Resource Interchange File Format) files,
including Windows WAV audio and AVI video files.

=head1 AUTHOR

Copyright 2003-2008, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.exif.org/Exif2-2.PDF>

=item L<http://www.vlsi.fi/datasheets/vs1011.pdf>

=item L<http://www.music-center.com.br/spec_rif.htm>

=item L<http://www.codeproject.com/audio/wavefiles.asp>

=item L<http://msdn.microsoft.com/archive/en-us/directx9_c/directx/htm/avirifffilereference.asp>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/RIFF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

