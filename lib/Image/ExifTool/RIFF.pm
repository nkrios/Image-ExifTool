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
#------------------------------------------------------------------------------

package Image::ExifTool::RIFF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.05';

# RIFF info
%Image::ExifTool::RIFF::Main = (
    PROCESS_PROC => \&Image::ExifTool::RIFF::ProcessChunks,
    NOTES => q{
Windows WAV and AVI files are RIFF format files.  Meta information embedded
in two types of RIFF C<LIST> chunks: C<INFO> and C<exif>.  As well, some
information about the audio content is extracted from the C<fmt > chunk.
    },
   'fmt ' => {
        Name => 'Format',
        SubDirectory => { TagTable => 'Image::ExifTool::RIFF::Format' },
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

# Format chunk data
%Image::ExifTool::RIFF::Format = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    FORMAT => 'int16u',
    0 => {
        Name => 'Encoding',
        PrintHex => 1,
        PrintConv => { #2
            0x01 => 'PCM',
            0x02 => 'ADPCM',
            0x03 => 'IEEE float',
            0x04 => 'VSELP', #4
            0x05 => 'IBM CVSD', #4
            0x06 => 'a-Law',
            0x07 => 'u-Law',
            0x08 => 'DTS', #4
            0x09 => 'DRM', #4
            0x10 => 'OKI-ADPCM',
            0x11 => 'IMA-ADPCM',
            0x12 => 'Mediaspace ADPCM', #4
            0x13 => 'Sierra ADPCM', #4
            0x14 => 'G723 ADPCM', #4
            0x15 => 'DIGISTD',
            0x16 => 'DIGIFIX',
            0x30 => 'Dolby AC2',
            0x31 => 'GSM610',
            0x3b => 'Rockwell ADPCM',
            0x3c => 'Rockwell DIGITALK',
            0x40 => 'G721 ADPCM',
            0x41 => 'G728 CELP',
            0x50 => 'MPEG',
            0x52 => 'RT24', #4
            0x53 => 'PAC', #4
            0x55 => 'MP3',
            0x64 => 'G726 ADPCM',
            0x65 => 'G722 ADPCM',
            0x101 => 'IBM u-Law', #3
            0x102 => 'IBM a-Law', #3
            0x103 => 'IBM ADPCM', #3
            0xffff => 'Development', #4
        },
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
        ValueConv => '$val=~s/-/:/g;$val',
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
    emnt => { Name => 'MakerNotes', ValueConv => '\$val' },
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
);

%Image::ExifTool::RIFF::StreamHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'StreamType',
        Format => 'string[4]',
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
  # 10 => 'Quality',
  # 11 => 'SampleSize',
  # 12 => { Name => 'Frame', Format => 'int16u[4]' },
);

# RIFF composite tags
%Image::ExifTool::RIFF::Composite = (
    Duration => {
        Require => {
            0 => 'FrameRate',
            1 => 'FrameCount',
        },
        ValueConv => '$val[0] ? $val[1] / $val[0] : undef',
        PrintConv => 'sprintf("%.2fs",$val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::RIFF::Composite');


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
    if (@part >= 5 and $monthNum{$part[1]}) {
        # the standard AVI date format
        $val = sprintf("%.4d:%.2d:%.2d %s", $part[4],
                       $monthNum{$part[1]}, $part[2], $part[3]);
    } elsif ($val =~ /(\d{4})\/\s*(\d+)\/\s*(\d+)\s*(\d+):\s*(\d+)\s*(P?)/) {
        # but the Casio QV-3EX writes dates like this
        $val = sprintf("%.4d:%.2d:%.2d %.2d:%.2d:00",$1,$2,$3,$4+($6?12:0),$5);
    }
    return $val;
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
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $end = $offset + $size;

    if ($exifTool->Options('Verbose')) {
        $exifTool->VerboseDir($$dirInfo{DirName}, 0, $size);
    }
    while ($offset + 8 < $end) {
        my $tag = substr($$dataPt, $offset, 4);
        my $len = Get32u($dataPt, $offset + 4);
        $offset += 8;
        if ($offset + $len > $end) {
            $exifTool->Warn("Bad $tag chunk");
            return 0;
        }
        if ($tag eq 'LIST' and $len >= 4) {
            $tag .= '_' . substr($$dataPt, $offset, 4);
            $len -= 4;
            $offset += 4;
        }
        $exifTool->HandleTag($tagTablePtr, $tag, undef,
            DataPt => $dataPt,
            DataPos => $$dirInfo{DataPos},
            Start => $offset,
            Size => $len,
        );
        ++$len if $len & 0x01;  # must account for padding if odd number of bytes
        $offset += $len;
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
    $err and $exifTool->Warn('Error reading RIFF file -- corrupted?');
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

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

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

