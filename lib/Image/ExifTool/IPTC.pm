#------------------------------------------------------------------------------
# File:         IPTC.pm
#
# Description:  Definitions for IPTC information
#
# Revisions:    Jan. 08/03 - P. Harvey Created
#               Feb. 05/04 - P. Harvey Added support for records other than 2
#------------------------------------------------------------------------------

package Image::ExifTool::IPTC;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

sub ProcessIPTC($$$);

# main IPTC tag table
# Note: ALL entries in main IPTC table (except PROCESS_PROC) must be SubDirectory
# entries, each specifying a TagTable.
%Image::ExifTool::IPTC::Main = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessIPTC,
    1   => {
        Name => 'IPTCEnvelopeRecord',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::EnvelopeRecord',
        },
    },
    2   => {
        Name => 'IPTCEditorial',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::ApplicationRecord',
        },
    },
    3   => {
        Name => 'IPTCNewsPhoto',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::NewsPhoto',
        },
    },
    7   => {
        Name => 'IPTCPreObjectData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::PreObjectData',
        },
    },
    8   => {
        Name => 'IPTCObjectData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::ObjectData',
        },
    },
    9   => {
        Name => 'IPTCPostObjectData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::PostObjectData',
        },
    },
);

# Record 1 -- EnvelopeRecord
%Image::ExifTool::IPTC::EnvelopeRecord = (
    GROUPS => { 2 => 'Other' },
    0   => {
        Name => 'EnvelopeRecordVersion',
        Format => 'Binary',
    },
    5   => {
        Name => 'Destination',
        Groups => { 2 => 'Location' },
    },
    20  => {
        Name => 'FileFormat',
        Groups => { 2 => 'Image' },
        Format => 'Binary',
        PrintConv => {
            0 => 'No ObjectData',
            1 => 'IPTC-NAA Digital Newsphoto Parameter Record',
            2 => 'IPTC7901 Recommended Message Format',
            3 => 'Tagged Image File Format (Adobe/Aldus Image data)',
            4 => 'Illustrator (Adobe Graphics data)',
            5 => 'AppleSingle (Apple Computer Inc)',
            6 => 'NAA 89-3 (ANPA 1312)',
            7 => 'MacBinary II',
            8 => 'IPTC Unstructured Character Oriented File Format (UCOFF)',
            9 => 'United Press International ANPA 1312 variant',
            10 => 'United Press International Down-Load Message',
            11 => 'JPEG File Interchange (JFIF)',
            12 => 'Photo-CD Image-Pac (Eastman Kodak)',
            13 => 'Bit Mapped Graphics File [.BMP] (Microsoft)',
            14 => 'Digital Audio File [.WAV] (Microsoft & Creative Labs)',
            15 => 'Audio plus Moving Video [.AVI] (Microsoft)',
            16 => 'PC DOS/Windows Executable Files [.COM][.EXE]',
            17 => 'Compressed Binary File [.ZIP] (PKWare Inc)',
            18 => 'Audio Interchange File Format AIFF (Apple Computer Inc)',
            19 => 'RIFF Wave (Microsoft Corporation)',
            20 => 'Freehand (Macromedia/Aldus)',
            21 => 'Hypertext Markup Language [.HTML] (The Internet Society)',
            22 => 'MPEG 2 Audio Layer 2 (Musicom), ISO/IEC',
            23 => 'MPEG 2 Audio Layer 3, ISO/IEC',
            24 => 'Portable Document File [.PDF] Adobe',
            25 => 'News Industry Text Format (NITF)',
            26 => 'Tape Archive [.TAR]',
            27 => 'Tidningarnas TelegrambyrŒ NITF version (TTNITF DTD)',
            28 => 'Ritzaus Bureau NITF version (RBNITF DTD)',
            29 => 'Corel Draw [.CDR]',
        },
    },
    22  => {
        Name => 'FileVersion',
        Groups => { 2 => 'Image' },
        Format => 'Binary',
    },
    30  => 'ServiceIdentifier',
    40  => 'EnvelopeNumber',
    50  => 'ProductID',
    60  => 'EnvelopePriority',
    70  => {
        Name => 'DateSent',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    80  => {
        Name => 'TimeSent',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
    },
    90  => 'CodedCharacterSet',
    100 => 'UniqueObjectName',
    120 => {
        Name => 'ARMIdentifier',
        Format => 'Binary',
    },
    122 => {
        Name => 'ARMVersion',
        Format => 'Binary',
    },
);

# Record 2 -- ApplicationRecord   
%Image::ExifTool::IPTC::ApplicationRecord = (
    GROUPS => { 2 => 'Other' },
    0   => {
        Name => 'ApplicationRecordVersion',
        Format => 'Binary',
    },
    3   => 'ObjectTypeReference',
    4   => 'ObjectAttributeReference',
    5   => 'ObjectName',
    7   => 'EditStatus',
    8   => 'EditorialUpdate',
    10  => 'Urgency',
    12  => 'SubjectReference',
    15  => 'Category',
    20  => {
        Name => 'SupplementalCategory',
        Flags => 'List',
    },
    22  => 'FixtureIdentifier',
    25  => {
        Name => 'Keywords',
        Flags => 'List',
    },
    26  => {
        Name => 'ContentLocationCode',
        Groups => { 2 => 'Location' },
    },
    27  => {
        Name => 'ContentLocationName',
        Groups => { 2 => 'Location' },
    },
    30  => {
        Name => 'ReleaseDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    35  => {
        Name => 'ReleaseTime',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
    },
    37  => {
        Name => 'ExpirationDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    38  => {
        Name => 'ExpirationTime',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
    },
    40  => 'SpecialInstructions',
    42  => {
        Name => 'ActionAdvised',
        PrintConv => {
            '' => '',
            '01' => 'Object Kill',
            '02' => 'Object Replace',
            '03' => 'Ojbect Append',
            '04' => 'Object Reference',
        },
    },
    45  => 'ReferenceService',
    47  => {
        Name => 'ReferenceDate',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    50  => 'ReferenceNumber',
    55  => {
        Name => 'DateCreated',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    60  => {
        Name => 'TimeCreated',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
    },
    62  => {
        Name => 'DigitalCreationDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    63  => {
        Name => 'DigitalCreationTime',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
    },
    65  => 'OriginatingProgram',
    70  => 'ProgramVersion',
    75  => 'ObjectCycle',
    80  => {
        Name => 'By-line',
        Groups => { 2 => 'Author' },
    },
    85  => {
        Name => 'By-lineTitle',
        Groups => { 2 => 'Author' },
    },
    90  => {
        Name => 'City',
        Groups => { 2 => 'Location' },
    },
    92  => {
        Name => 'Sub-location',
        Groups => { 2 => 'Location' },
    },
    95  => {
        Name => 'Province-State',
        Groups => { 2 => 'Location' },
    },
    100 => {
        Name => 'Country-PrimaryLocationCode',
        Groups => { 2 => 'Location' },
    },
    101 => {
        Name => 'Country-PrimaryLocationName',
        Groups => { 2 => 'Location' },
    },
    103 => 'OriginalTransmissionReference',
    105 => 'Headline',
    110 => {
        Name => 'Credit',
        Groups => { 2 => 'Author' },
    },
    115 => {
        Name => 'Source',
        Groups => { 2 => 'Author' },
    },
    116 => {
        Name => 'CopyrightNotice',
        Groups => { 2 => 'Author' },
    },
    118 => {
        Name => 'Contact',
        Groups => { 2 => 'Author' },
    },
    120 => 'Caption-Abstract',
    122 => {
        Name => 'Writer-Editor',
        Groups => { 2 => 'Author' },
    },
    125 => {
        Name => 'RasterizedCaption',
        PrintConv => '\$val',
    },
    130 => {
        Name => 'ImageType',
        Groups => { 2 => 'Image' },
    },
    131 => {
        Name => 'ImageOrientation',
        Groups => { 2 => 'Image' },
    },
    135 => 'LanguageIdentifier',
    150 => 'AudioType',
    151 => 'AudioSamplingRate',
    152 => 'AudioSamplingResolution',
    153 => 'AudioDuration',
    154 => 'AudioOutcue',
    200 => {
        Name => 'ObjectPreviewFileFormat',
        Groups => { 2 => 'Image' },
        Format => 'Binary',
    },
    201 => {
        Name => 'ObjectPreviewFileVersion',
        Groups => { 2 => 'Image' },
        Format => 'Binary',
    },
    202 => {
        Name => 'ObjectPreviewData',
        Groups => { 2 => 'Image' },
        PrintConv => '\$val',
    },
);

# Record 3 -- News photo
# Note: I can't locate the reference for this record, so I'm not
# sure I've got the format correct.  Specifically, I'm not sure which of
# these fields are Binary and which are ASCII data.  This isn't a huge
# loss though, because this record isn't very popular. - PH
%Image::ExifTool::IPTC::NewsPhoto = (
    GROUPS => { 2 => 'Image' },
    0   => {
        Name => 'NewsPhotoVersion',
        Format => 'Binary',
    },
    10  => 'IPTCPictureNumber',
    20  => 'IPTCImageWidth',
    30  => 'IPTCImageHeight',
    40  => 'IPTCPixelWidth',
    50  => 'IPTCPixelHeight',
    55  => {
        Name => 'SupplementalType',
        Format => 'Binary',
        PrintConv => {
            0 => 'Main Image',
            1 => 'Reduced Resolution Image',
            2 => 'Logo',
            3 => 'Rasterized Caption',
        },
    },
    60  => 'ColorRepresentation',
    64  => {
        Name => 'InterchangeColorSpace',
        Format => 'Binary',
        PrintConv => {
            1 => 'X,Y,Z CIE',
            2 => 'RGB SMPTE',
            3 => 'Y,U,V (K) (D65)',
            4 => 'RGB Device Dependent',
            5 => 'CMY (K) Device Dependent',
            6 => 'Lab (K) CIE',
            7 => 'YCbCr',
            8 => 'sRGB',
        },
    },
    65  => 'ColorSequence',
    84  => 'NumIndexEntries',
    86  => 'IPTCBitsPerSample',
    90  => {
        Name => 'SampleStructure',
        Format => 'Binary',
        PrintConv => {
            0 => 'OrthogonalConstangSampling',
            1 => 'Orthogonal4-2-2Sampling',
            2 => 'CompressionDependent',
        },
    },
    100 => {
        Name => 'ScanningDirection',
        Format => 'Binary',
        PrintConv => {
            0 => 'L-R, Top-Bottom',
            1 => 'R-L, Top-Bottom',
            2 => 'L-R, Bottom-Top',
            3 => 'R-L, Bottom-Top',
            4 => 'Top-Bottom, L-R',
            5 => 'Bottom-Top, L-R',
            6 => 'Top-Bottom, R-L',
            7 => 'Bottom-Top, R-L',
        },
    },
    102 => {
        Name => 'IPTCImageRotation',
        Format => 'Binary',
        PrintConv => {
            0 => 0,
            1 => 90,
            2 => 180,
            3 => 270,
        },
    },
    110 => 'DataCompressionMethod',
    120 => {
        Name => 'QuantizationMethod',
        Format => 'Binary',
        PrintConv => {
            0 => 'Linear Reflectance/Transmittance',
            1 => 'Linear Density',
            2 => 'IPTC Ref B',
            3 => 'Linear Dot Percent',
            4 => 'AP Domestic Analogue',
            5 => 'Compression Method Specific',
            6 => 'Color Space Specific',
            7 => 'Gamma Compensated',
        },
    },
    125 => 'EndPoints',
    130 => {
        Name => 'ExcursionTolerance',
        Format => 'Binary',
        PrintConv => {
            0 => 'Not Allowed',
            1 => 'Allowed',
        },
    },
    135 => 'BitsPerComponent',
);

# Record 7 -- Pre-object Data
%Image::ExifTool::IPTC::PreObjectData = (
    10  => {
        Name => 'SizeMode',
        Format => 'Binary',
        PrintConv => {
            0 => 'Size Not Known',
            1 => 'Size Known',
        },
    },
    20  => {
        Name => 'MaxSubfileSize',
        Format => 'Binary',
    },
    90  => {
        Name => 'ObjectSizeAnnounced',
        Format => 'Binary',
    },
    95  => {
        Name => 'MaximumObjectSize',
        Format => 'Binary',
    },
);

# Record 8 -- ObjectData
%Image::ExifTool::IPTC::ObjectData = (
    10  => {
        Name => 'SubFile',
        PrintConv => '\$val',
    },
);

# Record 9 -- PostObjectData
%Image::ExifTool::IPTC::PostObjectData = (
    10  => {
        Name => 'ConfirmedObjectSize',
        Format => 'Binary',
    },
);

# Composite IPTC tags
%Image::ExifTool::IPTC::Composite = (
    # Note: the following 2 composite tags are duplicated in Image::ExifTool::XMP
    # (only the first loaded definition is used)
    DateTimeCreated => {
        Description => 'Date/Time Created',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'DateCreated',
            1 => 'TimeCreated',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    # set the original date/time from DateTimeCreated if not set already
    DateTimeOriginal => {
        Condition => 'not defined($oldVal)',
        Description => 'Shooting Date/Time',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'DateTimeCreated',
        },
        ValueConv => '$val[0]',
        PrintConv => '$valPrint[0]',
    },
);


#------------------------------------------------------------------------------
# get IPTC info
# Inputs: 0) ExifTool object reference, 1) reference to tag table
#         2) dirInfo reference
# Returns: 1 on success, 0 otherwise
sub ProcessIPTC($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $pos = $dirInfo->{DirStart};
    my $dirEnd = $pos + $dirInfo->{DirLen};
    my $verbose = $exifTool->Options('Verbose');
    my $success = 0;
    
    while ($pos + 5 <= $dirEnd) {
        my $buff = substr($$dataPt, $pos, 5);
        my ($id, $rec, $tag, $len) = unpack("CCCn", $buff);
        unless ($id == 0x1c) {
            unless ($id) {
                # scan the rest of the data an give warning unless all zeros
                # (iMatch pads the IPTC block with nulls for some reason)
                my $remaining = substr($$dataPt, $pos, $dirEnd - $pos);
                last unless $remaining =~ /[^\0]/;
            }
            $exifTool->Warn(sprintf('Bad IPTC data tag (marker 0x%x)',$id));
            last;
        }
        my $tableInfo = $tagTablePtr->{$rec};
        unless ($tableInfo) {
            $verbose and $exifTool->Warn("Unrecognized IPTC record: $rec");
            last;   # stop now because we're probably reading garbage
        }
        my $tableName = $tableInfo->{SubDirectory}->{TagTable};
        unless ($tableName) {
            $exifTool->Warn("No table for IPTC record $rec!");
            last;   # this shouldn't happen
        }
        $pos += 5;      # step to after field header
        my $recordPtr = Image::ExifTool::GetTagTable($tableName);
        # handle extended IPTC entry if necessary
        if ($len & 0x8000) {
            my $n = $len & 0x7fff; # get num bytes in length field
            if ($pos + $n > $dirEnd or $n > 8) {
                $verbose and print "Invalid extended IPTC entry (tag $tag)\n";
                $success = 0;
                last;
            }
            # determine length (a big-endian, variable sized binary number)
            for ($len = 0; $n; ++$pos, --$n) {
                $len = $len * 256 + ord(substr($$dataPt, $pos, 1));
            }
        }
        if ($pos + $len > $dirEnd) {
            $verbose and print "Invalid IPTC entry (tag $tag, len $len)\n";
            $success = 0;
            last;
        }
        my $val = substr($$dataPt, $pos, $len);
        my $tagInfo = $exifTool->GetTagInfo($recordPtr, $tag);
        if ($tagInfo) {
            if (ref $tagInfo eq 'HASH' and $tagInfo->{Format}) {
                if (lc($tagInfo->{Format}) eq 'binary') {
                    $val = 0;
                    my $i;
                    for ($i=0; $i<$len; ++$i) {
                        $val = $val * 256 + ord(substr($$dataPt, $pos+$i, 1));
                    }
                } else {
                    $exifTool->Warn("Invalid IPTC format: $tagInfo->{Format}");
                }
            }
        } else {
            $tagInfo = sprintf("IPTC_%d", $tag);
        }
        $exifTool->FoundTag($tagInfo, $val);
        $success = 1;
        
        $pos += $len;   # increment to next field
    }
    return $success;
}

1; # end
