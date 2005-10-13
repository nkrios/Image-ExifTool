#------------------------------------------------------------------------------
# File:         WAV.pm
#
# Description:  Routines fro reading WAV files
#
# Revisions:    09/14/2005 - P. Harvey Created
#
# References:   1) http://www.exif.org/Exif2-2.PDF
#               2) http://www.vlsi.fi/datasheets/vs1011.pdf
#               3) http://www.music-center.com.br/spec_rif.htm
#               4) http://www.codeproject.com/audio/wavefiles.asp
#------------------------------------------------------------------------------

package Image::ExifTool::WAV;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.00';

# WAV info
%Image::ExifTool::WAV::Main = (
    PROCESS_PROC => \&Image::ExifTool::WAV::ProcessSubChunks,
    NOTES => q{
WAV is the native digital audio format for Windows.  This is a RIFF-based
format which supports meta information embedded in two types of RIFF C<LIST>
chunks: C<INFO> and C<exif>.  As well, some information about the audio
content is extracted from the C<fmt > chunk.
    },
    'fmt ' => {
        Name => 'Format',
        SubDirectory => { TagTable => 'Image::ExifTool::WAV::Format' },
    },
    'LIST' => {
        Name => 'List',
        SubDirectory => { TagTable => 'Image::ExifTool::WAV::List' },
    },
);

# Sub chunks of LIST chunk
%Image::ExifTool::WAV::List = (
    PROCESS_PROC => \&Image::ExifTool::WAV::ProcessChunk,
    'INFO' => {
        Name => 'Info',
        SubDirectory => { TagTable => 'Image::ExifTool::WAV::Info' },
    },
    'exif' => {
        Name => 'Exif',
        SubDirectory => { TagTable => 'Image::ExifTool::WAV::Exif' },
    },
);

# Format chunk data
%Image::ExifTool::WAV::Format = (
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
%Image::ExifTool::WAV::Info = (
    PROCESS_PROC => \&Image::ExifTool::WAV::ProcessSubChunks,
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
%Image::ExifTool::WAV::Exif = (
    PROCESS_PROC => \&Image::ExifTool::WAV::ProcessSubChunks,
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


#------------------------------------------------------------------------------
# Process RIFF sub-chunk
# Inputs: 0) ExifTool object reference, 1) directory information reference
#         2) tag table reference
# Returns: 1 on success
sub ProcessSubChunks($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $verbose = $exifTool->Options('Verbose');
    my $end = $offset + $size;

    $verbose and $exifTool->VerboseDir($$dirInfo{DirName}, 0, $size);

    while ($offset + 8 < $end) {
        my $tag = substr($$dataPt, $offset, 4);
        my $len = Get32u($dataPt, $offset + 4);
        $offset += 8;
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        if ($offset + $len > $end) {
            $exifTool->Warn("Bad $tag chunk");
            return 0;
        }
        if ($verbose) {
            my $val = substr($$dataPt, $offset, $len);
            $exifTool->VerboseInfo($tag, $tagInfo,
                Size => $len,
                Value => $val,
                DataPt => \$val,
            );
        }
        if ($tagInfo) {
            if ($$tagInfo{SubDirectory}) {
                my %subdirInfo = (
                    DataPt => $dataPt,
                    DirStart => $offset,
                    DirLen => $len,
                    DirName => $tag,
                );
                my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                $exifTool->ProcessDirectory(\%subdirInfo, $tagTablePtr);
            } else {
                $exifTool->FoundTag($tagInfo, substr($$dataPt, $offset, $len));
            }
        }
        ++$len if $len & 0x01;  # must account for padding if odd number of bytes
        $offset += $len;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process RIFF chunk
# Inputs: 0) ExifTool object reference, 1) directory information reference
#         2) tag table reference
# Returns: 1 on success
sub ProcessChunk($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    
    $size >= 4 or $exifTool->Warn('Chunk too small'), return 0;
    # get chunk type (the only difference between a chunk and a sub-chunk)
    my $chunkType = substr($$dataPt, $offset, 4);
    my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $chunkType);
    if ($tagInfo and $$tagInfo{SubDirectory}) {
        $tagTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
        my %subInfo = (
            DataPt => $dataPt,
            DirStart => $offset + 4,
            DirLen => $size - 4,
            DirName => $chunkType,
        );
        ProcessSubChunks($exifTool, \%subInfo, $tagTablePtr) or return 0;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from a WAV audio file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid WAV file
sub ProcessWAV($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $exifTool->Options('Verbose');
    my ($buff, $err);

    # verify this is a valid WAV file
    return 0 unless $raf->Read($buff, 12) == 12;
    return 0 unless $buff =~ /^RIFF....WAVE/s;
    $exifTool->SetFileType();
    SetByteOrder('II');
    my $tagTablePtr = GetTagTable('Image::ExifTool::WAV::Main');
#
# Read chunks in WAVE image until we get to the 'data' chunk
#
    for (;;) {
        $raf->Read($buff, 8) == 8 or $err=1, last;
        my ($tag, $len) = unpack('a4V', $buff);
        last if $tag eq 'data'; # stop when we hit the audio data
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        $verbose and print "WAVE '$tag' chunk:\n";
        if ($tagInfo and $$tagInfo{SubDirectory}) {
            $raf->Read($buff, $len) == $len or $err=1, last;
            my %dirInfo = (
                DataPt => \$buff,
                DirStart => 0,
                DirLen => $len,
            );
            my $tagTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            $exifTool->ProcessDirectory(\%dirInfo, $tagTablePtr);
        } else {
            $raf->Seek($len, 1) or $err=1, last;
        }
    }
    $err and $exifTool->Warn('Error reading WAV file -- corrupted?');
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::WAV - Routines for reading WAV files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from WAV audio files.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.exif.org/Exif2-2.PDF>

=item L<http://www.vlsi.fi/datasheets/vs1011.pdf>

=item L<http://www.music-center.com.br/spec_rif.htm>

=item L<http://www.codeproject.com/audio/wavefiles.asp>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/WAV Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

