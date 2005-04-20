#------------------------------------------------------------------------------
# File:         Jpeg2000.pm
#
# Description:  Routines for reading JPEG 2000 files
#
# Revisions:    02/11/2005 - P. Harvey Created
#
# References:   1) http://www.jpeg.org/public/fcd15444-2.pdf
#               2) ftp://ftp.remotesensing.org/jpeg2000/fcd15444-1.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Jpeg2000;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.05';

sub ProcessJpeg2000($$$);
sub ProcessExifUUID($$$);

my %jp2ResolutionUnit = (
    -3 => 'km',
    -2 => '100 m',
    -1 => '10 m',
     0 => 'm',
     1 => '10 cm',
     2 => 'cm',
     3 => 'mm',
     4 => '0.1 mm',
     5 => '0.01 mm',
     6 => 'um',
);

# JPEG 2000 "box" (ie. segment) names
%Image::ExifTool::Jpeg2000::Main = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessJpeg2000,
   'jP  ' => 'JP2Signature', # (ref 1)
   "jP\x1a\x1a" => 'JP2Signature', # (ref 2)
    prfl => 'Profile',
    ftyp => 'FileType',
    rreq => 'ReaderRequirements',
    jp2h => {
        Name => 'JP2Header',
        SubDirectory => { },
    },
        # JP2Header sub boxes...
        ihdr => {
            Name => 'ImageHeader',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Jpeg2000::ImageHeader',
            },
        },
        bpcc => 'BitsPerComponent',
        colr => {
            Name => 'ColorSpecification',
            SubDirectory => {
                TagTable => 'Image::ExifTool::ICC_Profile::Main',
                ProcessProc => \&ProcessColorSpecification,
            },
        },
        pclr => 'Palette',
        cdef => 'ComponentDefinition',
       'res '=> {
            Name => 'Resolution',
            SubDirectory => { },
        },
            # Resolution sub boxes...
            resc => {
                Name => 'CaptureResolution',
                SubDirectory => {
                    TagTable => 'Image::ExifTool::Jpeg2000::CaptureResolution',
                },
            },
            resd => {
                Name => 'DisplayResolution',
                SubDirectory => {
                    TagTable => 'Image::ExifTool::Jpeg2000::DisplayResolution',
                },
            },
    jpch => {
        Name => 'CodestreamHeader',
        SubDirectory => { },
    },
        # CodestreamHeader sub boxes...
       'lbl '=> {
            Name => 'Label',
            Format => 'string',
        },
        cmap => 'ComponentMapping',
        roid => 'ROIDescription',
    jplh => {
        Name => 'CompositingLayerHeader',
        SubDirectory => { },
    },
        # CompositingLayerHeader sub boxes...
        cgrp => 'ColorGroup',
        opct => 'Opacity',
        creg => 'CodestreamRegistration',
    dtbl => 'DataReference',
    ftbl => {
        Name => 'FragmentTable',
        Subdirectory => { },
    },
        # FragmentTable sub boxes...
        flst => 'FragmentList',
    cref => 'Cross-Reference',
    mdat => 'MediaData',
    comp => 'Composition',
    copt => 'CompositionOptions',
    inst => 'InstructionSet',
    asoc => 'Association',
    nlst => 'NumberList',
    bfil => 'BinaryFilter',
    drep => 'DesiredReproductions',
        # DesiredReproductions sub boxes...
        gtso => 'GraphicsTechnologyStandardOutput',
    chck => 'DigitalSignature',
    mp7b => 'MPEG7Binary',
    free => 'Free',
    jp2c => 'ContiguousCodestream',
    jp2i => {
        Name => 'IntellectualProperty',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
   'xml '=> {
        Name => 'XML',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
    uuid => [
        {
            Name => 'UUID-GeoJP2',
            # ref http://www.remotesensing.org/jpeg2000/
            Condition => q{
                my $id = "\xb1\x4b\xf8\xbd\x08\x3d\x4b\x43\xa5\xae\x8c\xd7\xd5\xa6\xce\x03";
                Image::ExifTool::Jpeg2000::CheckUUID($dataPt, $valuePtr, $id);
            },
            SubDirectory => {
                TagTable => 'Image::ExifTool::Exif::Main',
                ProcessProc => \&ProcessExifUUID,
                DirStart => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-XMP',
            # ref http://www.adobe.com/products/xmp/pdfs/xmpspec.pdf
            Condition => q{
                my $id = "\xbe\x7a\xcf\xcb\x97\xa9\x42\xe8\x9c\x71\x99\x94\x91\xe3\xaf\xac";
                Image::ExifTool::Jpeg2000::CheckUUID($dataPt, $valuePtr, $id);
            },
            SubDirectory => {
                TagTable => 'Image::ExifTool::XMP::Main',
                DirStart => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-Unknown',
        },
    ],
    uinf => {
        Name => 'UUIDInfo',
        SubDirectory => { },
    },
        # UUIDInfo sub boxes...
        ulst => 'UUIDList',
       'url '=> {
            Name => 'URL',
            Format => 'string',
        },
);

%Image::ExifTool::Jpeg2000::ImageHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    0 => {
        Name => 'ImageHeight',
        Format => 'int32u',
    },
    4 => {
        Name => 'ImageWidth',
        Format => 'int32u',
    },
    8 => {
        Name => 'NumberOfComponents',
        Format => 'int16u',
    },
    10 => {
        Name => 'BitsPerComponent',
        PrintConv => q{
            $val == 0xff and return 'Variable';
            my $sign = ($val & 0x80) ? 'Signed' : 'Unsigned';
            return (($val & 0x7f) + 1) . " Bits, $sign";
        },
    },
    11 => {
        Name => 'Compression',
        PrintConv => {
            0 => 'Uncompressed',
            1 => 'Modified Huffman',
            2 => 'Modified READ',
            3 => 'Modified Modified READ',
            4 => 'JBIG',
            5 => 'JPEG',
            6 => 'JPEG-LS',
            7 => 'JPEG 2000',
            8 => 'JBIG2',
        },
    },
);

%Image::ExifTool::Jpeg2000::CaptureResolution = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int8s',
    0 => {
        Name => 'CaptureYResolution',
        Format => 'rational16u',
    },
    4 => {
        Name => 'CaptureXResolution',
        Format => 'rational16u',
    },
    8 => {
        Name => 'CaptureYResolutionUnit',
        PrintConv => \%jp2ResolutionUnit,
    },
    9 => {
        Name => 'CaptureXResolutionUnit',
        PrintConv => \%jp2ResolutionUnit,
    },
);

%Image::ExifTool::Jpeg2000::DisplayResolution = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int8s',
    0 => {
        Name => 'DisplayYResolution',
        Format => 'rational16u',
    },
    4 => {
        Name => 'DisplayXResolution',
        Format => 'rational16u',
    },
    8 => {
        Name => 'DisplayYResolutionUnit',
        PrintConv => \%jp2ResolutionUnit,
    },
    9 => {
        Name => 'DisplayXResolutionUnit',
        PrintConv => \%jp2ResolutionUnit,
    },
);

#------------------------------------------------------------------------------
# Process JPEG 2000 ColorSpecification box (may contain ICC profile)
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessColorSpecification($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $$dirInfo{DataPt};
    return 0 unless $$dirInfo{DataLen} > 3;
    my $meth = Get8u($dataPt, 0);
    return 1 unless $meth == 2 or $meth == 3;
    $$dirInfo{DirStart} += 3;
    return $exifTool->ProcessTagTable($tagTablePtr, $dirInfo);
}

#------------------------------------------------------------------------------
# Check UUID type
# Inputs: 0) data reference, 1) box start, 2) 16-byte ID
# Returns: true if this the UUID ID matches
sub CheckUUID($$$)
{
    my ($dataPt, $valuePtr, $id) = @_;
    if (length($$dataPt) - $valuePtr >= 16) {
        return 1 if substr($$dataPt, $valuePtr, 16) eq $id;
    }
    return 0;
}

#------------------------------------------------------------------------------
# Process JPEG 2000 Exif UUID box
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessExifUUID($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $$dirInfo{DataPt};
    # get the data block (into a common variable)
    $exifTool->{EXIF_DATA} = substr($$dataPt, 16);
    $exifTool->{EXIF_POS} = $$dirInfo{DataPos} + 16;
    # extract the EXIF information (it is in standard TIFF format)
    my $success = $exifTool->TiffInfo('JP2');
    SetByteOrder('MM'); # return byte order to big-endian
    return $success;
}

#------------------------------------------------------------------------------
# Process JPEG 2000 box
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessJpeg2000($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = $$dirInfo{DataLen};
    my $dataPos = $$dirInfo{DataPos};
    my $dirLen = $$dirInfo{DirLen} || 0;
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $raf = $$dirInfo{RAF};
    my $verbose = $exifTool->{OPTIONS}->{Verbose};

    my $dirEnd = $dirStart + $dirLen;
    # loop through all contained boxes
    my ($pos, $boxLen);
    for ($pos=$dirStart; ; $pos+=$boxLen) {
        my ($boxID, $buff, $valuePtr);
        if ($raf) {
            $dataPos = $raf->Tell();
            $raf->Read($buff,8) == 8 or last;
            $dataPt = \$buff;
            $dirLen = 8;
            $pos = 0;
        } else {
            last if $pos >= $dirEnd - 8;
        }
        $boxLen = unpack("x$pos N",$$dataPt);
        $boxID = substr($$dataPt, $pos+4, 4);
        $pos += 8;
        if ($boxLen == 1) {
            return 0 if $pos < $dirLen - 8 and not $raf;
            $exifTool->Warn("Can't currently handle huge JPEG 2000 boxes");
            last;   # can't currently handle huge boxes
        } elsif ($boxLen == 0) {
            last if $raf;   # don't read the rest from file
            $boxLen = $dirLen - $pos;
        } else {
            $boxLen -= 8;
        }
        return 0 if $boxLen < 0;
        if ($raf) {
            # read the box data
            $raf->Read($buff,$boxLen);
            $valuePtr = 0;
            $dataLen = $boxLen;
        } else {
            return 0 if $boxLen + $pos > $dirStart + $dirLen;
            $valuePtr = $pos;
        }
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $boxID, $dataPt, $valuePtr);
        if ($verbose) {
            $exifTool->VerboseInfo($boxID, $tagInfo,
                Table  => $tagTablePtr,
                DataPt => $dataPt,
                Size   => $boxLen,
                Start  => $valuePtr,
            );
        }
        next unless $tagInfo;
        if ($$tagInfo{SubDirectory}) {
            my $subdir = $$tagInfo{SubDirectory};
            my $subdirStart = $valuePtr;
            if (defined $$subdir{Start}) {
                #### eval Start ($valuePtr)
                $subdirStart = eval($$subdir{Start});
            }
            my %subdirInfo = (
                DataPt => $dataPt,
                DataPos => $dataPos,
                DataLen => $dataLen,
                DirStart => $subdirStart,
                DirLen => $boxLen - ($subdirStart - $valuePtr),
                DirName => $$tagInfo{Name},
            );
            my $subTable = GetTagTable($$subdir{TagTable}) || $tagTablePtr;
            my $ok = $exifTool->ProcessTagTable($subTable, \%subdirInfo, $$subdir{ProcessProc});
            unless ($ok) {
                return 0 if $subTable eq $tagTablePtr;
                $exifTool->Warn("Unrecognized $$tagInfo{Name} box");
            }
        } elsif ($$tagInfo{Format}) {
            # only save tag values if Format was specified
            my $val = ReadValue($dataPt, $valuePtr, $$tagInfo{Format}, undef, $boxLen);
            $exifTool->FoundTag($tagInfo, $val) if defined $val;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Jpeg2000Info : extract meta information from a JPEG 2000 image
# Inputs: 0) ExifTool object reference
# Returns: 1 on success, 0 if this wasn't a valid JPEG 2000 file
sub Jpeg2000Info($)
{
    my $exifTool = shift;
    my $hdr;
    my $raf = $exifTool->{RAF};
    my $rtnVal = 0;

    # check to be sure this is a valid JPG2000 file
    return 0 unless $raf->Read($hdr,12) == 12;
    return 0 unless $hdr eq "\x00\x00\x00\x0cjP  \x0d\x0a\x87\x0a" or     # (ref 1)
                    $hdr eq "\x00\x00\x00\x0cjP\x1a\x1a\x0d\x0a\x87\x0a"; # (ref 2)
    SetByteOrder('MM'); # JPEG 2000 files are big-endian
    my %dirInfo = (
        RAF => $raf,
        DirName => 'JP2',
    );
    my $tagTablePtr = GetTagTable('Image::ExifTool::Jpeg2000::Main');
    return $exifTool->ProcessTagTable($tagTablePtr, \%dirInfo);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Jpeg2000 - Routines for reading JPEG 2000 files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read JPEG 2000
files.

=head1 NOTES

The JPEG 2000 code should be considered experimental, because I haven't
found many JPEG 2000 images to test it on.  If you have any images that
aren't decoded properly, please send them to me so I can improve the JPEG
2000 support.  Thanks.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://www.jpeg.org/public/fcd15444-2.pdf

=item ftp://ftp.remotesensing.org/jpeg2000/fcd15444-1.pdf

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Jpeg2000 Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

