#------------------------------------------------------------------------------
# File:         XMP.pm
#
# Description:  Definitions for XMP tags
#
# Revisions:    11/25/2003 - P. Harvey Created
#               10/28/2004 - P. Harvey Major overhaul to conform with XMP spec
#
# Reference:    http://www.adobe.com/products/xmp/pdfs/xmpspec.pdf
#               http://www.w3.org/TR/rdf-syntax-grammar/  (20040210)
#
# Notes:      - Only UTF-8 (ASCII) encoded XMP is supported
#
#             - I am handling property qualifiers as if they were separate
#               properties (with no associated namespace).
#
#             - Currently, there is no special treatment of the following
#               properties which could potentially effect the extracted
#               information: xml:base, xml:lang, rdf:parseType (note that
#               parseType Literal isn't allowed by the XMP spec).
#
#             - The family 2 group names will be set to 'Unknown' for any XMP
#               tags not found in the XMP or Exif tag tables.
#
#             - The 'ThumbnailImage' is untested since I can't find a file
#               with an embedded XMP thumbnail.
#------------------------------------------------------------------------------

package Image::ExifTool::XMP;

use strict;
use vars qw($VERSION);

$VERSION = '1.15';

sub ProcessXMP($$$);
sub ParseXMPElement($$$;$);
sub DecodeBase64($);

# XMP namespaces which we don't want to contribute to generated EXIF tag names
my %ignoreNamespace = ( 'x'=>1, 'rdf'=>1, 'xmlns'=>1, 'xml'=>1 );

# XMP tags need only be specified if a conversion or name change is necessary
# (Note: 'List' attribute is set automatically for any 'rdf:li' resource)
%Image::ExifTool::XMP::Main = (
    GROUPS => { 2 => 'Unknown' },
    PROCESS_PROC => \&ProcessXMP,
#
# Define tags for necessary schema properties
# (only need to define tag if we want to change the default group
#  or any other tag information, or if we want the tag name to show
#  up in the complete list of tags.  Also, we give the family 1 group
#  name for one of the properties so it will show up in the group list.
#  Family 1 groups are generated from the property namespace.)
#
# - Dublin Core schema properties (dc)
#
    Contributor     => { Groups => { 1 => 'XMP-dc', 2 => 'Author' } },
    Coverage        => { },
    Creator         => { Groups => { 2 => 'Author' } },
    Date            => { Groups => { 2 => 'Time'   } },
    Description     => { Groups => { 2 => 'Image'  } },
    Format          => { Groups => { 2 => 'Image'  } },
    Identifier      => { Groups => { 2 => 'Image'  } },
    Language        => { },
    Publisher       => { Groups => { 2 => 'Author' } },
    Relation        => { },
    Rights          => { Groups => { 2 => 'Author' } },
    Source          => { Groups => { 2 => 'Author' } },
    Subject         => { Groups => { 2 => 'Image'  } },
    Title           => { Groups => { 2 => 'Image'  } },
    Type            => { Groups => { 2 => 'Image'  } },
#
# - XMP Basic schema properties (xmp (was xap))
#
    Advisory        => { Groups => { 1 => 'XMP-xmp' } },
    BaseURL         => { },
  # CreateDate (covered by Exif)
    CreatorTool     => { },
    Identifier      => { },
    MetadataDate    => {
        Groups => { 2 => 'Time'  },
        PrintConv => '$self->ConvertDateTime($val)',
    },
  # ModifyDate (covered by Exif)
    Nickname        => { },
    ThumbnailsHeight=> { Groups => { 2 => 'Image'  } },
    ThumbnailsWidth => { Groups => { 2 => 'Image'  } },
    ThumbnailsFormat=> { Groups => { 2 => 'Image'  } },
    ThumbnailsImage => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Image' },
        # translate Base64-encoded thumbnail
        ValueConv => 'Image::ExifTool::XMP::DecodeBase64($val)',
        PrintConv => '\$val',
    },
#
# - XMP Rights Management schema properties (xmpRights)
#
    Certificate     => { Groups => { 1 => 'XMP-xmpRights', 2 => 'Author' } },
    Marked          => { },
    Owner           => { Groups => { 2 => 'Author' } },
    UsageTerms      => { },
    WebStatement    => { Groups => { 2 => 'Author' } },
#
# - XMP Media Management schema properties (xmpMM)
#
    DerivedFrom     => { Groups => { 1 => 'XMP-xmpMM'} },
  # DerivedFrom (ResourceRef=InstanceID,DocumentID,VersionID,RenditionClass
  #              RenditionParams,Manager,mManagerVariant,ManageTo,ManageUI)
    DocumentID      => { },
    History         => { },
  # History (ResourceEvent=Action,InstanceID,Parameters,SoftwareAgent,When)
    HistoryWhen     => { Groups => { 2 => 'Time'  } },
    ManagedFrom     => { },
  # ManagedFrom (ResourceRef)
    Manager         => { Groups => { 2 => 'Author' } },
    ManageTo        => { Groups => { 2 => 'Author' } },
    ManageUI        => { },
    ManagerVariant  => { },
    RenditionClass  => { },
    RenditionParams => { },
    VersionID       => { },
    Versions        => { },
  # Versions (Version=Comments,Event,ModifyDate,Modifier,Version)
    LastURL         => { },
    RenditionOf     => { },
    SaveID          => { },
#
# - XMP Basic Job Ticket schema properties
#
    JobRef          => { Groups => { 1 => 'XMP-xmpBJ'} },
  # JobRef (Job=Name,Id,Url)
#
# - Photoshop schema properties (photoshop)
#
    AuthorsPosition => { Groups => { 1 => 'XMP-photoshop', 2 => 'Author' } },
    CaptionWriter   => { Groups => { 2 => 'Author' } },
    Category        => { Groups => { 2 => 'Image'  } },
    City            => { Groups => { 2 => 'Location' } },
    Country         => { Groups => { 2 => 'Location' } },
    Credit          => { Groups => { 2 => 'Author' } },
    DateCreated => {
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    Headline        => { Groups => { 2 => 'Image'  } },
    Instructions    => { },
  # Source (handled by Dublin core)
    State           => { Groups => { 2 => 'Location' } },
    SupplementalCategories  => { Groups => { 2 => 'Image' } },
    TransmissionReference   => { Groups => { 2 => 'Image' } },
    Urgency         => { },
#
# - Photoshop Raw Converter schema properties (crs) - not documented
#
    Version         => { Groups => { 1 => 'XMP-crs', 2 => 'Image' } },
    RawFileName     => { Groups => { 2 => 'Image' } },
    WhiteBalance    => { Groups => { 2 => 'Image' } },
    Exposure        => { Groups => { 2 => 'Image' } },
    Shadows         => { Groups => { 2 => 'Image' } },
    Brightness      => { Groups => { 2 => 'Image' } },
    Contrast        => { Groups => { 2 => 'Image' } },
    Saturation      => { Groups => { 2 => 'Image' } },
    Sharpness       => { Groups => { 2 => 'Image' } },
    LuminanceSmoothing  => { Groups => { 2 => 'Image' } },
    ColorNoiseReduction => { Groups => { 2 => 'Image' } },
    ChromaticAberrationR=> { Groups => { 2 => 'Image' } },
    ChromaticAberrationB=> { Groups => { 2 => 'Image' } },
    VignetteAmount  => { Groups => { 2 => 'Image' } },
    VignetteMidpoint=> { Groups => { 2 => 'Image' } },
    ShadowTint      => { Groups => { 2 => 'Image' } },
    RedHue          => { Groups => { 2 => 'Image' } },
    RedSaturation   => { Groups => { 2 => 'Image' } },
    GreenHue        => { Groups => { 2 => 'Image' } },
    GreenSaturation => { Groups => { 2 => 'Image' } },
    BlueHue         => { Groups => { 2 => 'Image' } },
    BlueSaturation  => { Groups => { 2 => 'Image' } },
#
# - Auxiliary schema properties (aux) - not documented
#
    Lens            => { Groups => { 1 => 'XMP-aux', 2 => 'Camera' } },
    SerialNumber    => { Groups => { 2 => 'Camera' } },
#
# - Tiff schema properties (tiff)
#
# (Note: only include exif/tiff properties if the name differs from the
#  EXIF tag name, since the EXIF table entries are copied into this table)
#
    ImageLength => {
        Name => 'ImageHeight',
        Groups => { 1 => 'XMP-tiff', 2 => 'Image' },
    },
    DateTime => {
        Name => 'ModifyDate',
        Description => 'Date/Time Of Last Modification',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
#
# - Exif schema properties (exif)
#
    PixelXDimension => {
        Name => 'ImageWidth',
        Groups => { 1 => 'XMP-exif', 2 => 'Image' },
    },
    PixelYDimension => {
        Name => 'ImageHeight',
        Groups => { 2 => 'Image' },
    },
    DateTimeDigitized => {
        Description => 'Date/Time Digitized',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ISOSpeedRatings => {
        Name => 'ISO',
        Description => 'ISO Speed',
        Groups => { 2 => 'Image' },
    },
    OECF => {
        Name => 'Opto-ElectricConvFactor',
    },
    ExposureBiasValue => {
        Name => 'ExposureCompensation',
        Groups => { 2 => 'Image' },
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    SubjectArea => {
        Name => 'SubjectLocation',
        Groups => { 2 => 'Camera' },
    },
    FocalLengthIn35mmFilm => {
        Name => 'FocalLengthIn35mmFormat',
        Groups => { 2 => 'Camera' },
    },
    FlashFired => {
        Groups => { 2 => 'Camera' },
    },
    FlashReturn => {
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'No return detection',
            2 => 'Return not detected',
            3 => 'Return detected',
        },
    },
    FlashMode => {
        Groups => { 2 => 'Camera' },
        PrintConv => {
            1 => 'On',
            2 => 'Off',
            3 => 'Auto',
        },
    },
);

# composite tags
# (the main script looks for the special 'Composite' hash)
%Image::ExifTool::XMP::Composite = (
    # Note: the following 2 composite tags are duplicated in Image::ExifTool::IPTC
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

# fill out XMP table with entries from main table if they don't exist
foreach (Image::ExifTool::TagTableKeys(\%Image::ExifTool::Exif::Main)) {
    next if Image::ExifTool::GetSpecialTag($_); # ignore special tags
    my $exifInfo = $Image::ExifTool::Exif::Main{$_};
    # just take first entry in table info array
    my $name;
    if (ref $exifInfo) {
        ref($exifInfo) eq 'ARRAY' and $exifInfo = $$exifInfo[0];
        $name = $$exifInfo{Name};
    } else {
        $name = $exifInfo;
    }
    next if $Image::ExifTool::XMP::Main{$name};
    my $tagInfo = { Name => $name };
    if (ref $exifInfo) {
        # use ValueConv, PrintConv, Description and Groups
        # from EXIF tag information (except Groups family 0 and 1)
        if (defined $$exifInfo{ValueConv}) {
            $$tagInfo{ValueConv} = $$exifInfo{ValueConv};
        }
        if (defined $$exifInfo{Description}) {
            $$tagInfo{Description} = $$exifInfo{Description};
        }
        if (defined $$exifInfo{PrintConv}) {
            $$tagInfo{PrintConv} = $$exifInfo{PrintConv};
        }
        my $groupHash;
        foreach $groupHash ($Image::ExifTool::Exif::Main{GROUPS}, $$exifInfo{Groups}) {
            next unless defined $groupHash;
            foreach (keys %$groupHash) {
                next if $_ < 2;
                $$tagInfo{Groups} or $$tagInfo{Groups} = { };
                $tagInfo->{Groups}->{$_} = $groupHash->{$_};
            }
        }
    }
    $Image::ExifTool::XMP::Main{$name} = $tagInfo;
}

#------------------------------------------------------------------------------
# Utility routine to decode a base64 string
# Inputs: 0) base64 string
# Returns:   decoded data
sub DecodeBase64($)
{
    local($^W) = 0; # unpack("u",...) gives bogus warning in 5.00[123]
    my $str = shift;
    
    # truncate at first unrecognized character (base 64 data
    # may only contain A-Z, a-z, 0-9, +, /, =, or white space)
    $str =~ s/[^A-Za-z0-9+\/= \t\n\r\f].*//;    
    # translate to uucoded and remove padding and white space
    $str =~ tr/A-Za-z0-9+\/= \t\n\r\f/ -_/d;

    # convert the data to binary in chunks
    my $chunkSize = 60;
    my $uuLen = pack("c", 32 + $chunkSize * 3 / 4); # calculate length byte
    my $dat = '';
    my ($i, $substr);
    # loop through the whole chunks
    my $len = length($str) - $chunkSize;
    for ($i=0; $i<=$len; $i+=$chunkSize) {
        $substr = substr($str, $i, $chunkSize);     # get a chunk of the data
        $dat .= unpack("u", $uuLen . $substr);      # decode it
    }
    $len += $chunkSize;
    # handle last partial chunk if necessary
    if ($i < $len) {
        $uuLen = pack("c", 32 + ($len-$i) * 3 / 4); # recalculate length
        $substr = substr($str, $i, $len-$i);        # get the last partial chunk
        $dat .= unpack("u", $uuLen . $substr);      # decode it
    }
    return($dat);
}

#------------------------------------------------------------------------------
# We found an XMP property name/value
# Inputs: 0) ExifTool object reference
#         1) Pointer to tag table
#         2) reference to array of XMP property names (last is current property)
#         3) property value
sub FoundXMP($$$$)
{
    my ($exifTool, $tagTablePtr, $nameList, $val) = @_;

    if ($exifTool->Options('Verbose') > 1) {
        print '    ', join('/',@$nameList), " = '$val'\n";
    }
    my $tag = '';
    my ($name, $namespace);
    foreach $name (@$nameList) {
        # split name into namespace and property name
        # (Note: namespace can be '' for property qualifiers)
        my ($ns, $nm) = ($name =~ /:/) ? ($`, $') : ('', $name);
        if ($ignoreNamespace{$ns}) {
            # special case: don't ignore rdf numbered items
            next unless $name =~ /^rdf:(_\d+)$/; 
            $tag .= $1;
        } else {
            $tag .= ucfirst($nm);       # add to tag name
        }
        # save namespace of first property to contribute to tag name
        $namespace = $ns unless defined $namespace;
    }
    # save values for valid tags
    if ($tag) {
        # convert quotient and date values to a more sensible format
        if ($val =~ /^(-{0,1}\d+)\/(-{0,1}\d+)/) {
            $val = $1 / $2 if $2;       # calculate quotient
        } elsif ($val =~ /^(\d{4})-(\d{2})-(\d{2}).{1}(\d{2}:\d{2}:\d{2})/) {
            $val = "$1:$2:$3 $4";       # convert back to EXIF time format
        }
        # look up this tag in the XMP table
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            # construct tag information (use the default groups)
            $tagInfo = { Name => $tag };
            Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        # set 'List' attribute in tagInfo if this is a list
        $$tagInfo{List} = ($$nameList[-1] eq 'rdf:li');
        $tag = $exifTool->FoundTag($tagInfo, $val);
        $exifTool->SetTagExtra($tag, $namespace);
    }
}

#------------------------------------------------------------------------------
# Recursively parse nested XMP data element
# Inputs: 0) ExifTool object reference
#         1) Pointer to tag table
#         2) reference to XMP data
#         3) reference to array of enclosing XMP property names (undef if none)
# Returns: Number of contained XMP elements
sub ParseXMPElement($$$;$)
{
    my $exifTool = shift;
    my $tagTablePtr = shift;
    my $dataPt = shift;
    my $nameListPt = shift || [ ];
    my $count = 0;

    Element: while ($$dataPt =~ m/<([\w:]+)(.*?)>/sg) {
        my ($name, $attrs) = ($1, $2);
        my $val = '';
        # only look for closing token if this is not an empty element
        # (empty elements end with '/', ie. <a:b/>)
        if ($attrs !~ s/\/$//) {
            my $nesting = 1;
            for (;;) {
                $$dataPt =~ m/(.*?)<\/$name>/sg or last Element;
                my $val2 = $1;
                # increment nesting level for each contained similar opening token
                ++$nesting while $val2 =~ m/<$name\b.*?(\/{0,1})>/sg and $1 ne '/';
                $val .= $val2;
                --$nesting or last;
                $val .= "</$name>";
            }
        }
        # trim comments and whitespace from rdf:Description properties only
        if ($name eq 'rdf:Description') {
            $val =~ s/<!--.*?-->//g;
            $val =~ s/^\s*(.*)\s*$/$1/;
        }
        # push this property name onto our hierarchy list
        push @$nameListPt, $name;
        # handle properties inside element attributes (RDF shorthand format):
        # (attributes take the form a:b='c' or a:b="c")
        while ($attrs =~ m/(\S+)=('|")(.*?)\2/sg) {
            my ($shortName, $shortVal) = ($1, $3);
            my $ns;
            if ($shortName =~ /:/) {
                $ns = $`;   # specified namespace
            } elsif ($name =~ /:/) {
                $ns = $`;   # assume same namespace as parent
                $shortName = "$ns:$shortName";    # add namespace to property name
            } else {
                # a property qualifier is the only property name that may not
                # have a namespace, and a qualifier shouldn't have attributes,
                # but what the heck, let's allow this anyway
                $ns = '';
            }
            $ignoreNamespace{$ns} and next;
            push @$nameListPt, $shortName;
            # save this shorthand XMP property
            FoundXMP($exifTool, $tagTablePtr, $nameListPt, $shortVal);
            pop @$nameListPt;
        }
        # if element value is empty, take value from 'resource' attribute
        # (preferentially) or 'about' attribute (if no 'resource')
        $val = $2 if $val eq '' and ($attrs =~ /\bresource=('|")(.*?)\1/ or
                                     $attrs =~ /\babout=('|")(.*?)\1/);
        # look for additional elements contained within this one
        if (!ParseXMPElement($exifTool, $tagTablePtr, \$val, $nameListPt)) {
            # there are no contained elements, so this must be a simple property value
            FoundXMP($exifTool, $tagTablePtr, $nameListPt, $val);
        }
        pop @$nameListPt;
        ++$count;
    }
    return $count;  # return the number of elements found at this level
}

#------------------------------------------------------------------------------
# Process XMP data
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessXMP($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $buff;
    my $rtnVal = 0;

    return 0 unless $tagTablePtr;

    # take substring if necessary
    if ($dirInfo->{DirStart} != 0 or $dirInfo->{DataLen} != $dirInfo->{DirLen}) {
        $buff = substr($$dataPt, $dirInfo->{DirStart}, $dirInfo->{DirLen});
        $dataPt = \$buff;
    }
    # split XMP information into separate lines
    $exifTool->Options('Verbose') and print "-------- Start XMP --------\n";

    $rtnVal = 1 if ParseXMPElement($exifTool, $tagTablePtr, $dataPt);
    
    $exifTool->Options('Verbose') and print "-------- End XMP --------\n";

    return $rtnVal;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::XMP - Definitions for XMP meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

XMP stands for Extensible Metadata Platform.  It is a format based on XML that
Adobe developed for embedding metadata information in image files.  This module
contains the definitions required by Image::ExifTool to read XMP information.

=head1 AUTHOR

Copyright 2003-2004, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://www.adobe.com/products/xmp/pdfs/xmpspec.pdf

=item http://www.w3.org/TR/rdf-syntax-grammar/

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
