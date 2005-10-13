#------------------------------------------------------------------------------
# File:         ICC_Profile.pm
#
# Description:  Definitions for ICC_Profile table
#
# Revisions:    11/16/04 - P. Harvey Created
#
# References:   1) http://www.color.org/icc_specs2.html (ICC.1:2003-09)
#               2) http://www.color.org/icc_specs2.html (ICC.1:2001-04)
#               3) http://developer.apple.com/documentation/GraphicsImaging/Reference/ColorSync_Manager/ColorSync_Manager.pdf
#
# Notes:        The ICC profile information is different: the format of each
#               tag is embedded in the information instead of in the directory
#               structure. This makes things a bit more complex because I need
#               an extra level of logic to decode the variable-format tags.
#------------------------------------------------------------------------------

package Image::ExifTool::ICC_Profile;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);

$VERSION = '1.06';

sub ProcessICC_Profile($$$);

# illuminant type definitions
my %illuminantType = (
    1 => 'D50',
    2 => 'D65',
    3 => 'D93',
    4 => 'F2',
    5 => 'D55',
    6 => 'A',
    7 => 'Equi-Power (E)',
    8 => 'F8',
);

# ICC_Profile tag table
%Image::ExifTool::ICC_Profile::Main = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessICC_Profile,
    A2B0 => 'AToB0',
    A2B1 => 'AToB1',
    A2B2 => 'AToB2',
    bXYZ => 'BlueMatrixColumn', # (called BlueColorant in ref 2)
    bTRC => {
        Name => 'BlueTRC',
        Description => 'Blue Tone Reproduction Curve',
    },
    B2A0 => 'BToA0',
    B2A1 => 'BToA1',
    B2A2 => 'BToA2',
    calt => {
        Name => 'CalibrationDateTime',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    targ => 'CharTarget',
    chad => 'ChromaticAdaptation',
    chrm => {
        Name => 'Chromaticity',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Chromaticity',
            Validate => '$type eq "chrm"',
        },
    },
    clro => 'ColorantOrder',
    clrt => {
        Name => 'ColorantTable',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::ColorantTable',
            Validate => '$type eq "clrt"',
        },
    },
    cprt => 'Copyright',
    crdi => 'CRDInfo', #2
    dmnd => {
        Name => 'DeviceMfgDesc',
        Groups => { 2 => 'Camera' },
    },
    dmdd => {
        Name => 'DeviceModelDesc',
        Groups => { 2 => 'Camera' },
    },
    devs => {
        Name => 'DeviceSettings', #2
        Groups => { 2 => 'Camera' },
    },
    gamt => 'Gamut',
    kTRC => {
        Name => 'GrayTRC',
        Description => 'Gray Tone Reproduction Curve',
    },
    gXYZ => 'GreenMatrixColumn', # (called GreenColorant in ref 2)
    gTRC => {
        Name => 'GreenTRC',
        Description => 'Green Tone Reproduction Curve',
    },
    lumi => 'Luminance',
    meas => {
        Name => 'Measurement',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Measurement',
            Validate => '$type eq "meas"',
        },
    },
    bkpt => 'MediaBlackPoint',
    wtpt => 'MediaWhitePoint',
    ncol => 'NamedColor', #2
    ncl2 => 'NamedColor2',
    resp => 'OutputResponse',
    pre0 => 'Preview0',
    pre1 => 'Preview1',
    pre2 => 'Preview2',
    desc => 'ProfileDescription',
    pseq => 'ProfileSequenceDesc',
    psd0 => 'PostScript2CRD0', #2
    psd1 => 'PostScript2CRD1', #2
    psd2 => 'PostScript2CRD2', #2
    ps2s => 'PostScript2CSA', #2
    ps2i => 'PS2RenteringIntent', #2
    rXYZ => 'RedMatrixColumn', # (called RedColorant in ref 2)
    rTRC => {
        Name => 'RedTRC',
        Description => 'Red Tone Reproduction Curve',
    },
    scrd => 'ScreeningDesc',
    scrn => 'Screening',
   'bfd '=> {
        Name => 'UCRBG',
        Description => 'Under Color Removal & Black Gen.',
    },
    tech => {
        Name => 'Technology',
        PrintConv => {
            fscn => 'Film Scanner',
            dcam => 'Digital Camera',
            rscn => 'Reflective Scanner',
            ijet => 'Ink Jet Printer',
            twax => 'Thermal Wax Printer',
            epho => 'Electrophotographic Printer',
            esta => 'Electrostatic Printer',
            dsub => 'Dye Sublimation Printer',
            rpho => 'Photographic Paper Printer',
            fprn => 'Film Writer',
            vidm => 'Video Monitor',
            vidc => 'Video Camera',
            pjtv => 'Projection Television',
           'CRT '=> 'Cathode Ray Tube Display',
           'PMD '=> 'Passive Matrix Display',
           'AMD '=> 'Active Matrix Display',
            KPCD => 'Photo CD',
            imgs => 'Photo Image Setter',
            grav => 'Gravure',
            offs => 'Offset Lithography',
            silk => 'Silkscreen',
            flex => 'Flexography',
        },
    },
    vued => 'ViewingCondDesc',
    view => {
        Name => 'ViewingConditions',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::ViewingConditions',
            Validate => '$type eq "view"',
        },
    },
    # ColorSync custom tags (ref 3)
    psvm => 'PS2CRDVMSize',
    vcgt => 'VideoCardGamma',
    mmod => 'MakeAndModel',
    dscm => 'ProfileDescriptionML',
    ndin => 'NativeDisplayInfo',

    # the following entry represents the ICC profile header, and doesn't
    # exist as a tag in the directory.  It is only in this table to provide
    # a link so ExifTool can locate the header tags
    Header => {
        Name => 'ProfileHeader',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Header',
        },
    },
);

# ICC profile header definition
%Image::ExifTool::ICC_Profile::Header = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-header', 2 => 'Image' },
    4 => {
        Name => 'ProfileCMMType',
        Format => 'string[4]',
    },
    8 => {
        Name => 'ProfileVersion',
        Format => 'int16s',
        PrintConv => '($val >> 8).".".(($val & 0xf0)>>4).".".($val & 0x0f)',
    },
    12 => {
        Name => 'ProfileClass',
        Format => 'string[4]',
        PrintConv => {
            scnr => 'Input Device Profile',
            mntr => 'Display Device Profile',
            prtr => 'Output Device Profile',
           'link'=> 'DeviceLink Profile',
            spac => 'ColorSpace Conversion Profile',
            abst => 'Abstract Profile',
            nmcl => 'NamedColor Profile',
        },
    },
    16 => {
        Name => 'ColorSpaceData',
        Format => 'string[4]',
    },
    20 => {
        Name => 'ProfileConnectionSpace',
        Format => 'string[4]',
    },
    24 => {
        Name => 'ProfileDateTime',
        Groups => { 2 => 'Time' },
        Format => 'int16u[6]',
        ValueConv => 'sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d",split(" ",$val));',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    36 => {
        Name => 'ProfileFileSignature',
        Format => 'string[4]',
    },
    40 => {
        Name => 'PrimaryPlatform',
        Format => 'string[4]',
        PrintConv => {
            'APPL' => 'Apple Computer Inc.',
            'MSFT' => 'Microsoft Corporation',
            'SGI ' => 'Silicon Graphics Inc.',
            'SUNW' => 'Sun Microsystems Inc.',
            'TGNT' => 'Taligent Inc.',
        },
    },
    44 => {
        Name => 'CMMFlags',
        Format => 'int32u',
        PrintConv => q[
            ($val & 0x01 ? "Embedded, " : "Not Embedded, ") .
            ($val & 0x02 ? "Not Independent" : "Independent")
        ],
    },
    48 => {
        Name => 'DeviceManufacturer',
        Format => 'string[4]',
    },
    52 => {
        Name => 'DeviceModel',
        Format => 'string[4]',
    },
    56 => {
        Name => 'DeviceAttributes',
        Format => 'int32u',
        PrintConv => q[
            ($val & 0x01 ? "Transparency, " : "Reflective, ") .
            ($val & 0x02 ? "Matte, " : "Glossy, ") .
            ($val & 0x04 ? "Negative, " : "Positive, ") .
            ($val & 0x08 ? "B&W" : "Color")
        ],
    },
    64 => {
        Name => 'RenderingIntent',
        Format => 'int32u',
        PrintConv => {
            0 => 'Perceptual',
            1 => 'Media-Relative Colorimetric',
            2 => 'Saturation',
            3 => 'ICC-Absolute Colorimetric',
        },
    },
    68 => {
        Name => 'ProfileConnectionSpace',
        Format => 'fixed32s[3]',  # xyz
    },
    80 => {
        Name => 'ProfileCreator',
        Format => 'string[4]',
    },
    84 => {
        Name => 'ProfileID',
        Format => 'int8u[16]',
        PrintConv => 'Image::ExifTool::ICC_Profile::HexID($val)',
    },
);

# viewingConditionsType (view) definition
%Image::ExifTool::ICC_Profile::ViewingConditions = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-view', 2 => 'Image' },
    8 => {
        Name => 'ViewingCondIlluminant',
        Format => 'fixed32s[3]',   # xyz
    },
    20 => {
        Name => 'ViewingCondSurround',
        Format => 'fixed32s[3]',   # xyz
    },
    32 => {
        Name => 'ViewingCondIlluminantType',
        Format => 'int32u',
        PrintConv => \%illuminantType,
    },
);

# measurementType (meas) definition
%Image::ExifTool::ICC_Profile::Measurement = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-meas', 2 => 'Image' },
    8 => {
        Name => 'MeasurementObserver',
        Format => 'int32u',
        PrintConv => {
            1 => 'CIE 1931',
            2 => 'CIE 1964',
        },
    },
    12 => {
        Name => 'MeasurementBacking',
        Format => 'fixed32s[3]',   # xyz
    },
    24 => {
        Name => 'MeasurementGeometry',
        Format => 'int32u',
        PrintConv => {
            1 => '0/45 or 45/0',
            2 => '0/d or d/0',
        },
    },
    28 => {
        Name => 'MeasurementFlare',
        Format => 'fixed32u',
        PrintConv => '$val*100 . " %"',  # change into a percent
    },
    32 => {
        Name => 'MeasurementIlluminant',
        Format => 'int32u',
        PrintConv => \%illuminantType,
    },
);

# chromaticity (chrm) definition
%Image::ExifTool::ICC_Profile::Chromaticity = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-chrm', 2 => 'Image' },
    8 => {
        Name => 'ChromaticityChannels',
        Format => 'int16u',
    },
    10 => {
        Name => 'ChromaticityColorant',
        Format => 'int16u',
        PrintConv => {
            1 => 'ITU-R BT.709',
            2 => 'SMPTE RP145-1994',
            3 => 'EBU Tech.3213-E',
            4 => 'P22',
        },
    },
    # include definitions for 4 channels -- if there are
    # fewer then the ProcessBinaryData logic won't print them.
    # If there are more, oh well.
    12 => {
        Name => 'ChromaticityChannel1',
        Format => 'fixed32u[2]',
    },
    20 => {
        Name => 'ChromaticityChannel2',
        Format => 'fixed32u[2]',
    },
    28 => {
        Name => 'ChromaticityChannel3',
        Format => 'fixed32u[2]',
    },
    36 => {
        Name => 'ChromaticityChannel4',
        Format => 'fixed32u[2]',
    },
);

# colorantTable (clrt) definition
%Image::ExifTool::ICC_Profile::ColorantTable = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-clrt', 2 => 'Image' },
    8 => {
        Name => 'ColorantCount',
        Format => 'int32u',
    },
    # include definitions for 3 colorants -- if there are
    # fewer then the ProcessBinaryData logic won't print them.
    # If there are more, oh well.
    12 => {
        Name => 'Colorant1Name',
        Format => 'string[32]',
    },
    44 => {
        Name => 'Colorant1Coordinates',
        Format => 'int16u[3]',
    },
    50 => {
        Name => 'Colorant2Name',
        Format => 'string[32]',
    },
    82 => {
        Name => 'Colorant2Coordinates',
        Format => 'int16u[3]',
    },
    88 => {
        Name => 'Colorant3Name',
        Format => 'string[32]',
    },
    120 => {
        Name => 'Colorant3Coordinates',
        Format => 'int16u[3]',
    },
);


#------------------------------------------------------------------------------
# print ICC Profile ID in hex
# Inputs: 1) string of numbers
# Returns: string of hex digits
sub HexID($)
{
    my $val = shift;
    my @vals = split(' ', $val);
    # return a simple zero if no MD5 done
    return 0 unless grep(!/^0/, @vals);
    $val = '';
    foreach (@vals) { $val .= sprintf("%.2x",$_); }
    return $val;
}

#------------------------------------------------------------------------------
# get formatted value from ICC tag (which has the type embedded)
# Inputs: 0) data reference, 1) offset to tag data, 2) tag data size
# Returns: Formatted value or undefined if format not supported
# Notes: The following types are handled by BinaryTables:
#  chromaticityType, colorantTableType, measurementType, viewingConditionsType
# The following types are not currently handled (most are large tables):
#  curveType, lut16Type, lut8Type, lutAtoBType, lutBtoAType, namedColor2Type,
#  parametricCurveType, profileSeqDescType, responseCurveSet16Type
sub FormatICCTag($$$)
{
    my ($dataPt, $offset, $size) = @_;

    my $type;
    if ($size >= 8) {
        # get data type from start of tag data
        $type = substr($$dataPt, $offset, 4);
    } else {
        $type = 'err';
    }
    # colorantOrderType
    if ($type eq 'clro' and $size >= 12) {
        my $num = Get32u($dataPt, $offset+8);
        if ($size >= $num + 12) {
            my $pos = $offset + 12;
            return join(' ',unpack("x$pos c$num", $$dataPt));
        }
    }
    # dataType
    if ($type eq 'data' and $size >= 12) {
        my $form = Get32u($dataPt, $offset+8);
        # format 0 is ASCII data
        $form == 0 and return substr($$dataPt, $offset+12, $size-12);
        # binary data and other data types treat as binary (ie. don't format)
    }
    # dateTimeType
    if ($type eq 'dtim' and $size >= 20) {
        return sprintf("%.4d:$.2d:%.2d %.2d:%.2d:%.2d",
               Get16u($dataPt, $offset+8),  Get16u($dataPt, $offset+10),
               Get16u($dataPt, $offset+12), Get16u($dataPt, $offset+14),
               Get16u($dataPt, $offset+16), Get16u($dataPt, $offset+18));
    }
    # multiLocalizedUnicodeType (replaces textDescriptionType of ref 2)
    if ($type eq 'mluc' and $size >= 28) {
        # take first language in list (pray that it is ascii)
        my $len = Get32u($dataPt, $offset + 20);
        my $pos = Get32u($dataPt, $offset + 24);
        if ($size >= $pos + $len) {
            my $str = substr($$dataPt, $offset + $pos, $len);
            $str =~ tr/\x00-\x1f\x80-\xff//d; # remove control characters and non-ascii
            return $str;
        }
    }
    # s15Fixed16ArrayType
    if ($type eq 'sf32') {
        return ReadValue($dataPt,$offset+8,'fixed32s',($size-8)/4,$size-8);
    }
    # signatureType
    if ($type eq 'sig ' and $size >= 12) {
        return substr($$dataPt, $offset+8, 4);
    }
    # textType
    $type eq 'text' and return substr($$dataPt, $offset+8, $size-8);
    # textDescriptionType (ref 2, replaced by multiLocalizedUnicodeType)
    if ($type eq 'desc' and $size >= 12) {
        my $len = Get32u($dataPt, $offset+8);
        if ($size >= $len + 12) {
            my $str = substr($$dataPt, $offset+12, $len);
            $str =~ s/\0.*//s;   # truncate at null terminator
            return $str;
        }
    }
    # u16Fixed16ArrayType
    if ($type eq 'uf32') {
        return ReadValue($dataPt,$offset+8,'fixed32u',($size-8)/4,$size-8);
    }
    # uInt32ArrayType
    if ($type eq 'ui32') {
        return ReadValue($dataPt,$offset+8,'int32u',($size-8)/4,$size-8);
    }
    # uInt64ArrayType
    if ($type eq 'ui64') {
        return ReadValue($dataPt,$offset+8,'int64u',($size-8)/8,$size-8);
    }
    # uInt8ArrayType
    if ($type eq 'ui08') {
        return ReadValue($dataPt,$offset+8,'int8u',$size-8,$size-8);
    }
    # XYZType
    if ($type eq 'XYZ ') {
        my $str = '';
        my $pos;
        for ($pos=8; $pos+12<=$size; $pos+=12) {
            $str and $str .= ', ';
            $str .= ReadValue($dataPt,$offset+$pos,'fixed32s',3,$size-$pos);
        }
        return $str;
    }
    return undef;   # data type is not supported
}

#------------------------------------------------------------------------------
# Process ICC_Profile APP13 record
# Inputs: 0) ExifTool object reference, 1) Reference to directory information
#         2) Tag table reference
# Returns: 1 on success
sub ProcessICC_Profile($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $verbose = $exifTool->Options('Verbose');

    my $oldOrder = GetByteOrder();
    SetByteOrder('MM');     # ICC_Profile is always big-endian

    # check length of table
    my $len = Get32u($dataPt, $dirStart);
    if ($len != $dirLen or $len < 128) {
        $exifTool->Warn("Bad length ICC_Profile (length $len)");
        SetByteOrder($oldOrder);
        return 0;
    }
    my $pos = $dirStart + 128;  # position at start of table
    my $numEntries = Get32u($dataPt, $pos);
    if ($numEntries < 1 or $numEntries >= 0x100
        or $numEntries * 12 + 132 > $dirLen)
    {
        $exifTool->Warn("Bad ICC_Profile table ($numEntries entries)");
        SetByteOrder($oldOrder);
        return 0;
    }
    if ($verbose) {
        $exifTool->VerboseDir('ICC_Profile', $numEntries, $dirLen);
        my $fakeInfo = { Name=>'ProfileHeader', SubDirectory => { } };
        $exifTool->VerboseInfo(undef, $fakeInfo);
    }
    if ($exifTool->{ICC_COUNT}++) {
        $exifTool->{SET_TAG_EXTRA} = '+' . $exifTool->{ICC_COUNT};
    }
    # process the header block
    my %subdirInfo = (
        Name     => 'ProfileHeader',
        DataPt   => $dataPt,
        DataLen  => $$dirInfo{DataLen},
        DirStart => $dirStart,
        DirLen   => 128,
        Parent   => $$dirInfo{DirName},
    );
    my $newTagTable = Image::ExifTool::GetTagTable('Image::ExifTool::ICC_Profile::Header');
    $exifTool->ProcessDirectory(\%subdirInfo, $newTagTable);

    $pos += 4;    # skip item count
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $tagID  = substr($$dataPt, $pos, 4);
        my $offset = Get32u($dataPt, $pos + 4);
        my $size   = Get32u($dataPt, $pos + 8);
        $pos += 12;
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID);
        # unknown tags aren't generated automatically by GetTagInfo()
        # if the tagID's aren't numeric, so we must do this manually:
        if (not $tagInfo and $exifTool->{OPTIONS}->{Unknown}) {
            $tagInfo = { Unknown => 1 };
            Image::ExifTool::AddTagToTable($tagTablePtr, $tagID, $tagInfo);
        }
        next unless defined $tagInfo;

        if ($offset + $size > $dirLen) {
            $exifTool->Warn("Bad ICC_Profile table (truncated)");
            last;
        }
        my $valuePtr = $dirStart + $offset;

        my $subdir = $$tagInfo{SubDirectory};
        # format the value unless this is a subdirectory
        my $value;
        $value = FormatICCTag($dataPt, $valuePtr, $size) unless $subdir;
        $verbose and $exifTool->VerboseInfo($tagID, $tagInfo,
            'Table'  => $tagTablePtr,
            'Index'  => $index,
            'Value'  => $value,
            'DataPt' => $dataPt,
            'Size'   => $size,
            'Start'  => $valuePtr,
        );
        if ($subdir) {
            my $name = $$tagInfo{Name};
            undef $newTagTable;
            if ($$subdir{TagTable}) {
                $newTagTable = Image::ExifTool::GetTagTable($$subdir{TagTable});
                unless ($newTagTable) {
                    warn "Unknown tag table $$subdir{TagTable}\n";
                    next;
                }
            } else {
                warn "Must specify TagTable for SubDirectory $name\n";
                next;
            }
            %subdirInfo = (
                Name     => $name,
                DataPt   => $dataPt,
                DataPos  => $$dirInfo{DataPos},
                DataLen  => $$dirInfo{DataLen},
                DirStart => $valuePtr,
                DirLen   => $size,
                Parent   => $$dirInfo{DirName},
            );
            my $type = substr($$dataPt, $valuePtr, 4);
            #### eval Validate ($type)
            if (defined $$subdir{Validate} and not eval $$subdir{Validate}) {
                $exifTool->Warn("Invalid $name data");
            } else {
                $exifTool->ProcessDirectory(\%subdirInfo, $newTagTable, $$subdir{ProcessProc});
            }
        } elsif (defined $value) {
            $exifTool->FoundTag($tagInfo, $value);
        } else {
            $value = substr($$dataPt, $valuePtr, $size);
            # treat unsupported formats as binary data
            my $oldValueConv = $$tagInfo{ValueConv};
            $$tagInfo{ValueConv} = '\$val';
            $exifTool->FoundTag($tagInfo, $value);
            $$tagInfo{ValueConv} = $oldValueConv;
        }
    }
    SetByteOrder($oldOrder);
    delete $exifTool->{SET_TAG_EXTRA};
    return 1;
}


1; # end


__END__

=head1 NAME

Image::ExifTool::ICC_Profile - Definitions for ICC profile tables

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains the definitions to read information from ICC profiles.
ICC (International Color Consortium) profiles are used to translate color
data created on one device into another device's native color space.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.color.org/icc_specs2.html>

=item L<http://developer.apple.com/documentation/GraphicsImaging/Reference/ColorSync_Manager/ColorSync_Manager.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ICC_Profile Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
