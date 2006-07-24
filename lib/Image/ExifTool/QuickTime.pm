#------------------------------------------------------------------------------
# File:         QuickTime.pm
#
# Description:  Read QuickTime and MP4 meta information
#
# Revisions:    10/04/2005 - P. Harvey Created
#               12/19/2005 - P. Harvey Added MP4 support
#
# References:   1) http://developer.apple.com/documentation/QuickTime/
#------------------------------------------------------------------------------

package Image::ExifTool::QuickTime;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.08';

sub FixWrongFormat($);

# information for time/date-based tags (time zero is Jan 1, 1904)
my %timeInfo = (
    Groups => { 2 => 'Time' },
    ValueConv => 'ConvertUnixTime($val - ((66 * 365 + 17) * 24 * 3600))',
    PrintConv => '$self->ConvertDateTime($val)',
);
# information for duration tags
my %durationInfo = (
    ValueConv => '$self->{TimeScale} ? $val / $self->{TimeScale} : $val',
    PrintConv => '$self->{TimeScale} ? sprintf("%.2fs", $val) : $val',
);

# QuickTime atoms
%Image::ExifTool::QuickTime::Main = (
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessMOV,
    GROUPS => { 2 => 'Video' },
    NOTES => q{
        These tags are used in QuickTime MOV and MP4 videos, and QTIF images.  Tags
        with a question mark after their name are not extracted unless the Unknown
        option is set.
    },
    free => { Unknown => 1, ValueConv => '\$val' },
    skip => { Unknown => 1, ValueConv => '\$val' },
    wide => { Unknown => 1, ValueConv => '\$val' },
    ftyp => { #MP4
        Name => 'FrameType',
        Unknown => 1,
        Notes => 'MP4 only',
        ValueConv => '\$val',
    },
    pnot => {
        Name => 'Preview',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Preview' },
    },
    PICT => {
        Name => 'PreviewPICT',
        ValueConv => '\$val',
    },
    moov => {
        Name => 'Movie',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Movie' },
    },
    mdat => { Unknown => 1, ValueConv => '\$val' },
);

# atoms used in QTIF files
%Image::ExifTool::QuickTime::ImageFile = (
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessMOV,
    GROUPS => { 2 => 'Image' },
    NOTES => 'Tags used in QTIF QuickTime Image Files.',
    idsc => {
        Name => 'ImageDescription',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ImageDesc' },
    },
    idat => {
        Name => 'ImageData',
        ValueConv => '\$val',
    },
    iicc => {
        Name => 'ICC_Profile',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' },
    },
);

# image description data block
%Image::ExifTool::QuickTime::ImageDesc = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    4 => { Name => 'CompressorID',  Format => 'string[4]' },
    20 => { Name => 'VendorID',     Format => 'string[4]' },
    28 => { Name => 'Quality',      Format => 'int32u' },
    32 => { Name => 'ImageWidth',   Format => 'int16u' },
    34 => { Name => 'ImageHeight',  Format => 'int16u' },
    36 => { Name => 'XResolution',  Format => 'int32u' },
    40 => { Name => 'YResolution',  Format => 'int32u' },
    48 => { Name => 'FrameCount',   Format => 'int16u' },
    50 => { Name => 'NameLength',   Format => 'int8u' },
    51 => { Name => 'Compressor',   Format => 'string[$val{46}]' },
    82 => { Name => 'BitDepth',     Format => 'int16u' },
);

# preview data block
%Image::ExifTool::QuickTime::Preview = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int16u',
    0 => {
        Name => 'PreviewDate',
        Format => 'int32u',
        %timeInfo,
    },
    2 => 'PreviewVersion',
    3 => {
        Name => 'PreviewAtomType',
        Format => 'string[4]',
    },
    5 => 'PreviewAtomIndex',
);

# movie atoms
%Image::ExifTool::QuickTime::Movie = (
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessMOV,
    GROUPS => { 2 => 'Video' },
    mvhd => {
        Name => 'MovieHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::MovieHdr' },
    },
    trak => {
        Name => 'Track',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Track' },
    },
    udta => {
        Name => 'UserData',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::UserData' },
    },
);

# movie header data block
%Image::ExifTool::QuickTime::MovieHdr = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    0 => { Name => 'Version', Format => 'int8u' },
    1 => {
        Name => 'CreateDate',
        %timeInfo,
    },
    2 => {
        Name => 'ModifyDate',
        %timeInfo,
    },
    3 => {
        Name => 'TimeScale',
        RawConv => '$self->{TimeScale} = $val',
    },
    4 => { Name => 'Duration', %durationInfo },
    5 => {
        Name => 'PreferredRate',
        ValueConv => '$val / 0x10000',
    },
    6 => {
        Name => 'PreferredVolume',
        Format => 'int16u',
        ValueConv => '$val / 256',
        PrintConv => 'sprintf("%.2f%%", $val * 100)',
    },
    18 => { Name => 'PreviewTime',      %durationInfo },
    19 => { Name => 'PreviewDuration',  %durationInfo },
    20 => { Name => 'PosterTime',       %durationInfo },
    21 => { Name => 'SelectionTime',    %durationInfo },
    22 => { Name => 'SelectionDuration',%durationInfo },
    23 => { Name => 'CurrentTime',      %durationInfo },
    24 => 'NextTrackID',
);

# track atoms
%Image::ExifTool::QuickTime::Track = (
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessMOV,
    GROUPS => { 2 => 'Video' },
    tkhd => {
        Name => 'TrackHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::TrackHdr' },
    },
    udta => {
        Name => 'UserData',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::UserData' },
    },
    mdia => { #MP4
        Name => 'Media',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Media' },
    },
);

# track header data block
%Image::ExifTool::QuickTime::TrackHdr = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 1 => 'Track#', 2 => 'Video' },
    FORMAT => 'int32u',
    0 => {
        Name => 'TrackVersion',
        Format => 'int8u',
        Priority => 0,
    },
    1 => {
        Name => 'TrackCreateDate',
        Priority => 0,
        %timeInfo,
    },
    2 => {
        Name => 'TrackModifyDate',
        Priority => 0,
        %timeInfo,
    },
    3 => {
        Name => 'TrackID',
        Priority => 0,
    },
    5 => {
        Name => 'TrackDuration',
        Priority => 0,
        %durationInfo,
    },
    8 => {
        Name => 'TrackLayer',
        Format => 'int16u',
        Priority => 0,
    },
    9 => {
        Name => 'TrackVolume',
        Format => 'int16u',
        Priority => 0,
        ValueConv => '$val / 256',
        PrintConv => 'sprintf("%.2f%%", $val * 100)',
    },
    19 => {
        Name => 'ImageWidth',
        Priority => 0,
        RawConv => \&FixWrongFormat,
    },
    20 => {
        Name => 'ImageHeight',
        Priority => 0,
        RawConv => \&FixWrongFormat,
    },
);

# user data atoms
%Image::ExifTool::QuickTime::UserData = (
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessMOV,
    GROUPS => { 2 => 'Video' },
    NOTES => q{
        Tag ID's beginning with the copyright symbol (hex 0xa9) are multi-language
        text, but ExifTool only extracts the text from the first language in the
        record.  ExifTool will extract any multi-language user data tags found, even
        if they don't exist in this table.
    },
    "\xa9cpy" => 'Copyright',
    "\xa9day" => 'CreateDate',
    "\xa9dir" => 'Director',
    "\xa9ed1" => 'Edit1',
    "\xa9ed2" => 'Edit2',
    "\xa9ed3" => 'Edit3',
    "\xa9ed4" => 'Edit4',
    "\xa9ed5" => 'Edit5',
    "\xa9ed6" => 'Edit6',
    "\xa9ed7" => 'Edit7',
    "\xa9ed8" => 'Edit8',
    "\xa9ed9" => 'Edit9',
    "\xa9fmt" => 'Format',
    "\xa9inf" => 'Information',
    "\xa9prd" => 'Producer',
    "\xa9prf" => 'Performers',
    "\xa9req" => 'Requirements',
    "\xa9src" => 'Source',
    "\xa9wrt" => 'Writer',
    name => 'Name',
    WLOC => {
        Name => 'WindowLocation',
        Format => 'int16u',
    },
    LOOP => {
        Name => 'LoopStyle',
        Format => 'int32u',
        PrintConv => {
            1 => 'Normal',
            2 => 'Palindromic',
        },
    },
    SelO => {
        Name => 'PlaySelection',
        Format => 'int8u',
    },
    AllF => {
        Name => 'PlayAllFrames',
        Format => 'int8u',
    },
   'ptv '=> {
        Name => 'PrintToVideo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Video' },
    },
    # hnti => 'HintInfo',
    # hinf => 'HintTrackInfo',
    TAGS => [
        {
            # these tags were initially discovered in a Pentax movie, but
            # seem very similar to those used by Nikon
            Name => 'PentaxTags',
            Condition => '$$valPt =~ /^PENTAX DIGITAL CAMERA\0/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Pentax::MOV',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'NikonTags',
            Condition => '$$valPt =~ /^NIKON DIGITAL CAMERA\0/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::MOV',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'UnknownTags',
            Unknown => 1,
            ValueConv => '\$val'
        },
    ],
);

# print to video data block
%Image::ExifTool::QuickTime::Video = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    0 => {
        Name => 'DisplaySize',
        PrintConv => {
            0 => 'Normal',
            1 => 'Double Size',
            2 => 'Half Size',
            3 => 'Full Screen',
            4 => 'Current Size',
        },
    },
    6 => {
        Name => 'SlideShow',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
);

# MP4 media
%Image::ExifTool::QuickTime::Media = (
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessMOV,
    GROUPS => { 2 => 'Video' },
    NOTES => 'MP4 only (most tags unknown because ISO charges for the specification).',
    minf => {
        Name => 'Minf',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Minf' },
    },
);

# MP4 media
%Image::ExifTool::QuickTime::Minf = (
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessMOV,
    GROUPS => { 2 => 'Video' },
    NOTES => 'MP4 only (most tags unknown because ISO charges for the specification).',
    stbl => {
        Name => 'Stbl',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Stbl' },
    },
);

# MP4 media
%Image::ExifTool::QuickTime::Stbl = (
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessMOV,
    GROUPS => { 2 => 'Video' },
    NOTES => 'MP4 only (most tags unknown because ISO charges for the specification).',
);

#------------------------------------------------------------------------------
# Fix incorrect format for ImageWidth/Height as written by Pentax
sub FixWrongFormat($)
{
    my $val = shift;
    return undef unless $val;
    if ($val & 0xffff0000) {
        $val = unpack('n',pack('N',$val));
    }
    return $val;
}

#------------------------------------------------------------------------------
# Process a QuickTime atom
# Inputs: 0) ExifTool object reference, 1) directory information reference
#         2) optional tag table reference
# Returns: 1 on success
sub ProcessMOV($$;$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $dataPt = $$dirInfo{DataPt};
    my $verbose = $exifTool->Options('Verbose');
    my ($buff, $tag, $size, $track);

    $raf or $raf = new File::RandomAccess($dataPt);
    $raf->Read($buff,8) == 8 or return 0;
    $tagTablePtr or $tagTablePtr = GetTagTable('Image::ExifTool::QuickTime::Main');
    ($size, $tag) = unpack('Na4', $buff);
    if ($dataPt) {
        $verbose and $exifTool->VerboseDir($$dirInfo{DirName});
    } else {
        # check on file type if called with a RAF
        $$tagTablePtr{$tag} or return 0;
        if ($tag eq 'ftyp') {
            $exifTool->SetFileType('MP4');
        } else {
            $exifTool->SetFileType();
        }
        SetByteOrder('MM');
    }
    for (;;) {
        if ($size < 8) {
            last if $size == 0;
            $size == 1 or $exifTool->Warn('Invalid atom size'), last;
            $raf->Read($buff, 8) == 8 or last;
            my ($hi, $lo) = unpack('NN', $buff);
            $hi and $exifTool->Warn('End of processing at large atom'), last;
            $size = $lo;
        }
        $size -= 8;
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        # generate tagInfo if Unknown option set
        if (not defined $tagInfo and ($exifTool->{OPTIONS}->{Unknown} or
            $tag =~ /^\xa9/))
        {
            my $name = $tag;
            $name =~ s/([\x00-\x1f\x7f-\xff])/'x'.unpack('H*',$1)/eg;
            if ($name =~ /^xa9(.*)/) {
                $tagInfo = {
                    Name => "UserData_$1",
                    Description => "User Data $1",
                };
            } else {
                $tagInfo = {
                    Name => "Unknown_$name",
                    Description => "Unknown $name",
                    Unknown => 1,
                    ValueConv => '\$val',
                };
            }
            Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        if (defined $tagInfo or $verbose) {
            my $val;
            $raf->Read($val, $size) == $size or last;
            # use value to get tag info if necessary
            $tagInfo or $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag, \$val);
            if ($verbose) {
                $exifTool->VerboseInfo($tag, $tagInfo, Value => $val, DataPt => \$val);
            }
            if ($tagInfo) {
                my $subdir = $$tagInfo{SubDirectory};
                if ($subdir) {
                    my %dirInfo = (
                        DataPt => \$val,
                        DirStart => 0,
                        DirLen => $size,
                        DirName => $$tagInfo{Name},
                    );
                    if ($$subdir{ByteOrder} and $$subdir{ByteOrder} =~ /^Little/) {
                        SetByteOrder('II');
                    }
                    if ($$tagInfo{Name} eq 'Track') {
                        $track or $track = 0;
                        $exifTool->{SET_GROUP1} = 'Track' . (++$track);
                    }
                    my $subTable = GetTagTable($$subdir{TagTable});
                    $exifTool->ProcessDirectory(\%dirInfo, $subTable);
                    delete $exifTool->{SET_GROUP1};
                    SetByteOrder('MM');
                } else {
                    if ($tag =~ /^\xa9/) {
                        # parse international text to extract first string
                        my $len = unpack('n', $val);
                        # $len should include 4 bytes for length and type words,
                        # but Pentax forgets to add these in, so allow for this
                        $len += 4 if $len == $size - 4;
                        $val = substr($val, 4, $len - 4) if $len <= $size;
                    } elsif ($$tagInfo{Format}) {
                        $val = ReadValue(\$val, 0, $$tagInfo{Format}, $$tagInfo{Count}, length($val));
                    }
                    $exifTool->FoundTag($tagInfo, $val);
                }
            }
        } else {
            $raf->Seek($size, 1) or last;
        }
        $raf->Read($buff, 8) == 8 or last;
        ($size, $tag) = unpack('Na4', $buff);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process a QuickTime Image File
# Inputs: 0) ExifTool object reference, 1) directory information reference
# Returns: 1 on success
sub ProcessQTIF($$)
{
    my $table = GetTagTable('Image::ExifTool::QuickTime::ImageFile');
    return ProcessMOV($_[0], $_[1], $table);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::QuickTime - Read QuickTime and MP4 meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from QuickTime and MP4 video files.

=head1 BUGS

The MP4 support is rather pathetic since the specification documentation is
not freely available (yes, ISO sucks).

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://developer.apple.com/documentation/QuickTime/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/QuickTime Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

