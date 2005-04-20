#------------------------------------------------------------------------------
# File:         WriteXMP.pl
#
# Description:  Routines for writing XMP metadata
#
# Revisions:    12/19/2004 - P. Harvey Created
#
# Limitations:  - only writes x-default language in Alt Lang lists
#------------------------------------------------------------------------------
#
# Syntax names
#
#   RDF Description ID about parseType resource li nodeID datatype
#
# Class names
#
#   Seq Bag Alt Statement Property XMLLiteral List
#
# Property names
#
#   subject predicate object type value first rest _n
#   (where n is a decimal integer greater than zero with no leading zeros)
#
# Resource names
#
#   nil
#
package Image::ExifTool::XMP;

use strict;

sub CheckXMP($$$);
sub SetPropertyPath($$$);
sub CaptureXMP($$$$;$);

my $debug = 0;

# namespace/property definitions for all writable XMP tags
my %xmpResourceRef = (
    stRef => [
        'InstanceID', 'DocumentID', 'VersionID', 'RenditionClass',
        'RenditionParams', 'Manager', 'ManagerVariant', 'ManageTo', 'ManageUI',
    ],
);
my %xmpResourceEvent = (
    stEvt => [
        'action', 'instanceID', 'parameters', 'softwareAgent', 'when',
    ],
);
my %xmpJobRef = (
    stJob => [ 'name', 'id', 'url' ],
);
my %xmpVersion = (
    stVer => [
        'comments',
        [ 'event', \%xmpResourceEvent ],
        'modifyDate', 'modifier', 'version',
    ],
);
my %xmpThumbnail = (
    xapGImg => [ 'height', 'width', 'format', 'image' ],
);
my %xmpPagedTex = (
    xmpTPg => [ 'maxPageSize', 'NPages' ],
);
my %xmpIdentifierScheme = (
    xmpidq => [ 'Scheme' ], # qualifier for xmp:Scheme only
);
my %xmpDimensions = (
    stDim => [ 'w', 'h', 'unit' ],
);
# the following stuctures are funny -- they don't have their own namespaces defined
# (apparently they use the 'exif' namespace)
my %xmpFlash = (
    exif => [ 'Fired', 'Return', 'Mode', 'Function', 'RedEyeMode' ],
);
my %xmpOECF = (
    exif => [ 'Columns', 'Rows', 'Names', 'Values' ],
);
my %xmpCFAPattern = (
    exif => [ 'Columns', 'Rows', 'Values' ],
);
my %xmpDeviceSettings = (
    exif => [ 'Columns', 'Rows', 'Settings' ],
);
# Iptc4xmpCore structures
my %xmpContactInfo = (
    Iptc4xmpCore => [
        'CiAdrCity', 'CiAdrCtry', 'CiAdrExtadr', 'CiAdrPcode',
        'CiAdrRegion', 'CiEmailWork', 'CiTelWork', 'CiUrlWork',
    ],
);

# complete lookup for all tags of each XMP namespace
my %writableXMP = (
    dc => [
        'contributor', 'coverage', 'creator', 'date', 'description', 'format',
        'identifier', 'language', 'publisher','relation', 'rights', 'source',
        'subject', 'title', 'type',
    ],
    xmp => ['Advisory', 'BaseURL', 'CreateDate', 'CreatorTool', 'Identifier',
        'MetadataDate', 'ModifyDate', 'Nickname', [ 'Thumbnails', \%xmpThumbnail ],
    ],
    xmpRights => [
        'Certificate', 'Marked', 'Owner', 'UsageTerms', 'WebStatement',
    ],
    xmpMM => [
        [ 'DerivedFrom', \%xmpResourceRef ], 'DocumentID',
        [ 'History', \%xmpResourceEvent ], [ 'ManagedFrom', \%xmpResourceRef ],
        'Manager', 'ManageTo', 'ManageUI', 'ManagerVariant', 'RenditionClass',
        'RenditionParams', 'VersionID', [ 'Versions', \%xmpVersion ], 'LastURL',
        [ 'RenditionOf', \%xmpResourceRef ], 'SaveID',
    ],
    xmpBJ => [
        [ 'JobRef', \%xmpJobRef ],
    ],
    pdf => [
        'Author', 'ModDate', 'CreationDate', 'PDFVersion', 'Producer', 'Keywords',
        # These are undocumented and conflict with dc tags, so we won't write them:
        # 'Creator', 'Subject', 'Title',
    ],
    photoshop => [
        'AuthorsPosition', 'CaptionWriter', 'Category', 'City', 'Country', 'Credit',
        'DateCreated', 'Headline', 'Instructions', 'Source', 'State',
        'SupplementalCategories', 'TransmissionReference', 'Urgency',
    ],
    crs => [
        'Version', 'RawFileName', 'WhiteBalance', 'Exposure', 'Shadows',
        'Brightness', 'Contrast', 'Saturation', 'Sharpness', 'LuminanceSmoothing',
        'ColorNoiseReduction', 'ChromaticAberrationR', 'ChromaticAberrationB',
        'VignetteAmount', 'VignetteMidpoint', 'ShadowTint', 'RedHue',
        'RedSaturation', 'GreenHue', 'GreenSaturation', 'BlueHue', 'BlueSaturation',
    ],
    aux => [
        'Lens', 'SerialNumber',
    ],
    tiff => [
        'ImageWidth', 'ImageLength', 'BitsPerSample', 'Compression',
        'PhotometricInterpretation', 'Orientation', 'SamplesPerPixel',
        'PlanarConfiguration', 'YCbCrSubSampling', 'XResolution', 'YResolution',
        'ResolutionUnit', 'TransferFunction', 'WhitePoint', 'PrimaryChromaticities',
        'YCbCrCoefficients', 'ReferenceBlackWhite', 'DateTime', 'ImageDescription',
        'Make', 'Model', 'Software', 'Artist', 'Copyright',
    ],
    exif => [
        'ExifVersion', 'FlashpixVersion', 'ColorSpace', 'ComponentsConfiguration',
        'CompressedBitsPerPixel', 'PixelXDimension', 'PixelYDimension', 'MakerNote',
        'UserComment', 'RelatedSoundFile', 'DateTimeOriginal', 'DateTimeDigitized',
        'ExposureTime', 'FNumber', 'ExposureProgram', 'SpectralSensitivity',
        'ISOSpeedRatings', ['OECF', \%xmpOECF], 'ShutterSpeedValue', 'ApertureValue',
        'BrightnessValue', 'ExposureBiasValue', 'MaxApertureValue', 'SubjectDistance',
        'MeteringMode', 'LightSource', ['Flash', \%xmpFlash], 'FocalLength',
        'SubjectArea', 'FlashEnergy', ['SpatialFrequencyResponse', \%xmpOECF],
        'FocalPlaneXResolution', 'FocalPlaneYResolution', 'FocalPlaneResolutionUnit',
        'SubjectLocation', 'ExposureIndex', 'SensingMethod', 'FileSource',
        'SceneType', ['CFAPattern', \%xmpCFAPattern], 'CustomRendered',
        'ExposureMode', 'WhiteBalance', 'DigitalZoomRatio', 'FocalLengthIn35mmFilm',
        'SceneCaptureType', 'GainControl', 'Contrast', 'Saturation', 'Sharpness',
        ['DeviceSettingDescription', \%xmpDeviceSettings], 'SubjectDistanceRange',
        'ImageUniqueID', 'GPSVersionID', 'GPSLatitude', 'GPSLongitude',
        'GPSAltitudeRef', 'GPSAltitude', 'GPSVersionID', 'GPSTimeStamp',
        'GPSSatellites', 'GPSStatus', 'GPSSpeedRef', 'GPSSpeed', 'GPSTrackRef',
        'GPSTrack', 'GPSImgDirectionRef', 'GPSImgDirection', 'GPSMapDatum',
        'GPSDestLatitude', 'GPSDestLongitude', 'GPSDestBearingRef', 'GPSDestBearing',
        'GPSDestDistanceRef', 'GPSDestDistance', 'GPSProcessingMethod',
        'GPSAreaInformation', 'GPSDifferential',
    ],
    Iptc4xmpCore => [
        'CountryCode', ['CreatorContactInfo', \%xmpContactInfo], 'IntellectualGenre',
        'Location', 'Scene', 'SubjectCode',
    ],
);

# Lookup to translate our namespace prefixes into URI's.  This
# list need not be complete, but it must contain an entry for each
# namespace prefix used in the above tables
my %nsURI = (
    aux       => 'http://ns.adobe.com/exif/1.0/aux/',
    crs       => 'http://ns.adobe.com/camera-raw-settings/1.0/',
    dc        => 'http://purl.org/dc/elements/1.1/',
    exif      => 'http://ns.adobe.com/exif/1.0/',
    iX        => 'http://ns.adobe.com/iX/1.0/',
    pdf       => 'http://ns.adobe.com/pdf/1.3/',
    photoshop => 'http://ns.adobe.com/photoshop/1.0/',
    rdf       => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    stDim     => 'http://ns.adobe.com/xap/1.0/sType/Dimensions#',
    stEvt     => 'http://ns.adobe.com/xap/1.0/sType/ResourceEvent#',
    stJob     => 'http://ns.adobe.com/xap/1.0/sType/Job#',
    stRef     => 'http://ns.adobe.com/xap/1.0/sType/ResourceRef#',
    stVer     => 'http://ns.adobe.com/xap/1.0/sType/Version#',
    tiff      => 'http://ns.adobe.com/tiff/1.0/',
   'x'        => 'adobe:ns:meta/',
    xapGImg   => 'http://ns/adobe.com/xap/1.0/g/img/',
    xmp       => 'http://ns.adobe.com/xap/1.0/',
    xmpBJ     => 'http://ns.adobe.com/xap/1.0/bj/',
    xmpMM     => 'http://ns.adobe.com/xap/1.0/mm/',
    xmpRights => 'http://ns.adobe.com/xap/1.0/rights/',
    xmpTPg    => 'http://ns.adobe.com/xap/1.0/t/pg/',
    xmpidq    => 'http://ns/adobe.com/xmp/Identifier/qual/1.0',
    Iptc4xmpCore => 'http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/',
);

# these are the attributes that we handle for properties that contain
# sub-properties.  Attributes for simple properties are easy, and we
# just copy them over.  These are harder since we don't store attributes
# for properties without simple values.  (maybe this will change...)
my %recognizedAttrs = (
    'x:xaptk' => 1,
    'x:xmptk' => 1,
    'about' => 1,
    'rdf:about' => 1,
    'rdf:parseType' => 1,
);

my $seeded;     # flag indicating we seeded our random number generateor
my $x_toolkit = "x:xmptk='Image::ExifTool $Image::ExifTool::VERSION'";
my $rdfDesc = 'rdf:Description';
#
# packet/xmp/rdf headers and trailers
#
my $pktOpen = "<?xpacket begin='\xef\xbb\xbf' id='W5M0MpCehiHzreSzNTczkc9d'?>\n" .
              '<?adobe-xap-filters esc="CR"?>' . "\n";
my $xmpOpen = "<x:xmpmeta xmlns:x='$nsURI{x}' $x_toolkit>\n";
my $rdfOpen = "<rdf:RDF xmlns:rdf='$nsURI{rdf}' xmlns:iX='$nsURI{iX}'>\n";
my $rdfClose = "</rdf:RDF>\n";
my $xmpClose = "</x:xmpmeta>\n";
my $pktClose =  "<?xpacket end='w'?>";

# generate "PropertyPath" for tags in main XMP table when this file is loaded
{
    my $ns;
    my $table = Image::ExifTool::GetTagTable('Image::ExifTool::XMP::Main');
    SetPropertyPath($table, \%writableXMP, []);
}

# add inverse conversion routines for entries in main table
{
    my $table = Image::ExifTool::GetTagTable('Image::ExifTool::XMP::Main');
    my $tag;
    $table->{CHECK_PROC} = \&CheckXMP; # add our write check routine
    foreach $tag (Image::ExifTool::TagTableKeys($table)) {
        my @tagInfoList = Image::ExifTool::GetTagInfoList($table, $tag) or next;
        my $tagInfo;
        foreach $tagInfo (@tagInfoList) {
            my $format = $$tagInfo{Writable};
            next unless $format and $format eq 'date';
            # add dummy conversion for dates (for now...)
            $$tagInfo{PrintConvInv} = '$val' unless $$tagInfo{PrintConvInv};
            $$tagInfo{ValueConvInv} = '$val' unless $$tagInfo{ValueConvInv};
        }
    }
}

#------------------------------------------------------------------------------
# check XMP values for validity and format accordingly
# Inputs: 0) ExifTool object reference, 1) tagInfo hash reference,
#         2) raw value reference
# Returns: error string or undef (and may change value) on success
sub CheckXMP($$$)
{
    my ($exifTool, $tagInfo, $valPtr) = @_;
    my $format = $tagInfo->{Writable};
    # if no format specified, value is a simple string
    return undef unless $format;
    if ($format eq 'rational') {
        # make sure the value is a valid floating point number
        unless ($$valPtr =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) {
            return 'Not a floating point number';
        }
        $$valPtr = join('/', Image::ExifTool::Rationalize($$valPtr));
    } elsif ($format eq 'integer') {
        # make sure the value is integer
        return 'Not an integer' unless $$valPtr =~ /^[+-]?\d+$/;
        $$valPtr = int($$valPtr);
    } elsif ($format eq 'date') {
        if ($$valPtr =~ /(\d{4}):(\d{2}):(\d{2}) (\d{2}:\d{2}:\d{2})(.*)/) {
            my ($y, $m, $d, $t, $tz) = ($1, $2, $3, $4, $5);
            # use 'Z' for timezone unless otherwise specified
            $tz = 'Z' unless $tz and $tz =~ /([+-]\d{2}:\d{2})/;
            $$valPtr = "$y-$m-${d}T$t$tz";
        } elsif ($$valPtr =~ /^\s*(\d{4}):(\d{2}):(\d{2})\s*$/) {
            # this is just a date (no time)
            $$valPtr = "$1-$2-$3";
        } elsif ($$valPtr =~ /^\s*(\d{2}:\d{2}:\d{2})(.*)\s*$/) {
            # this is just a time
            my ($t, $tz) = ($1, $2);
            $tz = 'Z' unless $tz and $tz =~ /([+-]\d{2}:\d{2})/;
            $$valPtr = "$t$tz";
        } else {
            return "Invalid date or time format (should be YYYY:MM:DD HH:MM:SS[+/-HH:MM])";
        }
    } elsif ($format eq 'lang-alt') {
        # nothing to do
    } elsif ($format eq 'boolean') {
        if (not $$valPtr or $$valPtr =~ /false/i or $$valPtr =~ /^no$/i) {
            $$valPtr = 'False';
        } else {
            $$valPtr = 'True';
        }
    } else {
        return "Unknown XMP format: $format";
    }
    return undef;   # success!
}

#------------------------------------------------------------------------------
# Set PropertyPath in tag information of specified table
# Inputs: 0) tag table reference, 1) reference to namespace hash
#         2) reference to array of property names (starting after rdf:Description)
sub SetPropertyPath($$$)
{
    local $_;
    my ($table, $nsHash, $propList) = @_;
    my ($prop, $tag, $ns);
    foreach $ns (keys %$nsHash) {
        my $group1;
        if (@$propList) {
            ($group1 = $$propList[0]) =~ s/:.*//;
        } else {
            $group1 = $ns;
        }
        my $tagList = $$nsHash{$ns};
        foreach (@$tagList) {
            my $tag = $_;
            my $nsHash2;
            # handle the contained properties
            ($tag, $nsHash2) = @$tag if ref $tag eq 'ARRAY';
            my $prop = "$ns:$tag";
            push @$propList, $prop;     # add to list of properties
            $tag = GetXMPTagName($propList);
            my $tagInfo;
            my @tagInfoList = Image::ExifTool::GetTagInfoList($table,$tag);
            if (@tagInfoList == 1) {
                $tagInfo = $tagInfoList[0];
            } else {
                foreach (@tagInfoList) {
                    next unless $_->{Namespace};
                    next unless $ns eq $_->{Namespace};
                    $tagInfo = $_;
                    last;
                }
            }
            unless ($tagInfo) {
                warn("Can't find info for XMP tag $tag\n");
                pop @$propList;
                next;
            }
            # translate necessary namespaces
            $group1 = $niceNamespace{$group1} if $niceNamespace{$group1};
            $tagInfo->{Groups}->{1} = 'XMP-' . $group1;   # set group1 name
            # the 'List' entry in XMP table gives the specific type of
            # list, and is one of Bag, Seq, Alt or 1.  If '1', this is just
            # a property in a list of structures, so a list property has
            # already been generated.
            my $listType = $$tagInfo{List};
            # lang-alt lists are handled specially, signified by Writable='lang-alt'
            # (they aren't true lists since we currently only allow setting of
            # the default language.)
            if ($$tagInfo{Writable} and $$tagInfo{Writable} eq 'lang-alt') {
                $listType = 'Alt';
            }
            # add required properties if this is a list
            if ($listType) {
                if ($listType eq '1') {
                    undef $listType;    # '1' is used for elements of structures in lists
                } else {
                    push @$propList, "rdf:$listType", 'rdf:li 000';
                }
            }
            # set property path for this tag
            $$tagInfo{PropertyPath} = join('/',@$propList);
            # recurse into the sub-property
            if ($nsHash2) {
                SetPropertyPath($table, $nsHash2, $propList);
            }
            $#$propList -= 2 if $listType;  # pop off list properties
            --$#$propList;  # pop off this property
        }
    }
}

#------------------------------------------------------------------------------
# Capture shorthand XMP properties
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table
#         2) reference to array of XMP property path (last is current property)
#         3) reference to hash of property attributes
#         4) true to set error on unrecognized attributes
sub CaptureShorthand($$$$;$)
{
    my ($exifTool, $tagTablePtr, $propList, $attrs, $setError) = @_;
    my $attr;
    my @attrList = keys %$attrs;
    foreach $attr (@attrList) {
        if ($attr =~ /^xmlns:(.*)/) {
            # remember all namespaces (except x and iX which we open ourselves)
            my $ns = $1;
            my $nsUsed = $exifTool->{XMP_NS};
            unless ($ns eq 'x' or $ns eq 'iX' or defined $$nsUsed{$ns}) {
                $$nsUsed{$ns} = $$attrs{$attr};
            }
        } elsif (not $recognizedAttrs{$attr}) {
            # check for RDF shorthand format
            my ($ns,$name);
            if ($attr =~ /(.*):(.*)/) {
                $ns = $1;
                $name = $2;
            } else {
                my $prop = $$propList[$#$propList];
                $ns = $1 if $prop =~ /(.*):/;   # take namespace from enclosing property
                $name = $attr;
            }
            if ($ns and $writableXMP{$ns}) {
                # save this shorthand property
                push @$propList, "$ns:$name";
                CaptureXMP($exifTool, $tagTablePtr, $propList, $$attrs{$attr});
                pop @$propList;
                # remove this attribute from list since we handled it
                delete $$attrs{$attr};
            } elsif ($setError) {
                $exifTool->{XMP_ERROR} = "Can't yet handle XMP attribute '$attr'";
            }
        }
    }
}

#------------------------------------------------------------------------------
# Save XMP property name/value for rewriting
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table
#         2) reference to array of XMP property path (last is current property)
#         3) property value, 4) optional reference to hash of property attributes
sub CaptureXMP($$$$;$)
{
    my ($exifTool, $tagTablePtr, $propList, $val, $attrs) = @_;
    $attrs or $attrs = { };

    if (defined $val) {
        return unless @$propList > 2;
        if ($$propList[0] =~ /^x:x(a|m)pmeta$/ and
            $$propList[1] eq 'rdf:RDF' and
            $$propList[2] eq $rdfDesc)
        {
            # capture any shorthand properties in the attribute list
            CaptureShorthand($exifTool, $tagTablePtr, $propList, $attrs);
            # no properties to save yet if this is just the description
            return unless @$propList > 3;
            # save information about this property
            my $capture = $exifTool->{XMP_CAPTURE};
            my $path = join('/', @$propList[3..$#$propList]);
            if (defined $$capture{$path}) {
                $exifTool->{XMP_ERROR} = "Duplicate XMP property: $path";
            } else {
                $$capture{$path} = [$val, $attrs];
            }
        } else {
            $exifTool->{XMP_ERROR} = 'Improperly enclosed XMP property: ' . join('/',@$propList);
        }
    } else {
        # this property has sub-properties, so just handle the attributes
        # (set an error on any unrecognized attributes here, because they will be lost)
        CaptureShorthand($exifTool, $tagTablePtr, $propList, $attrs, 1);
    }
}

#------------------------------------------------------------------------------
# Convert path to namespace used in file (this is a pain, but the XMP
# spec only suggests 'preferred' namespace prefixes...)
# Inputs: 0) ExifTool object reference, 1) property path
# Returns: conforming property path
sub ConformPathToNamespace($$)
{
    my ($exifTool, $path) = @_;
    my @propList = split('/',$path);
    my ($prop, $newKey);
    my $nsUsed = $exifTool->{XMP_NS};
    foreach $prop (@propList) {
        my ($ns, $tag) = $prop =~ /(.+?):(.*)/;
        next if $$nsUsed{$ns};
        my $uri = $nsURI{$ns};
        unless ($uri) {
            warn "No URI for namepace prefix $ns!\n";
            next;
        }
        my $ns2;
        foreach $ns2 (keys %$nsUsed) {
            next unless $$nsUsed{$ns2} eq $uri;
            # use the existing namespace prefix instead of ours
            $prop = "$ns2:$tag";
            last;
        }
    }
    return join('/',@propList);
}

#------------------------------------------------------------------------------
# Write XMP information
# Inputs: 0) ExifTool object reference, 1) tag table reference,
#         2) source dirInfo reference
# Returns: new XMP data (may be empty if no XMP data) or undef on error
# Notes: Increments ExifTool CHANGED flag for each tag changed
sub WriteXMP($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    $tagTablePtr or return undef;
    my $dataPt = $dirInfo->{DataPt};
    my $dirStart = $dirInfo->{DirStart} || 0;
    my (%capture, %nsUsed, $xmpErr);
    my $changed = 0;
    my $listIndex = '500';    # list index for newly added items
    my $verbose = $exifTool->Options('Verbose');
#
# extract existing XMP information into %capture hash
#
    # define hash in ExifTool object to capture XMP information (also causes
    # CaptureXMP() instead of FoundXMP() to be called from ParseXMPElement())
    #
    # The %capture hash is keyed on the complete property path beginning after
    # rdf:RDF/rdf:Description/.  The values are array references with the
    # following entries: 0) value, 1) attribute hash reference.
    $exifTool->{XMP_CAPTURE} = \%capture;
    $exifTool->{XMP_NS} = \%nsUsed;

    if ($dataPt) {
        delete $exifTool->{XMP_ERROR};
        # extract all existing XMP information (to the XMP_CAPTURE hash)
        my $success = ProcessXMP($exifTool, $tagTablePtr, $dirInfo);
        # don't continue if there is nothing to parse or if we had a parsing error
        unless ($success and not $exifTool->{XMP_ERROR}) {
            if ($exifTool->{XMP_ERROR}) {
                $exifTool->Warn($exifTool->{XMP_ERROR});
            } else {
                $exifTool->Warn('Error parsing XMP');
            }
            unless ($success and $exifTool->Options('IgnoreMinorErrors')) {
                delete $exifTool->{XMP_CAPTURE};
                return undef;
            }
        }
        delete $exifTool->{XMP_ERROR};
    } else {
        my $emptyData = '';
        $dataPt = \$emptyData;
    }
#
# add, delete or change information as specified
#
    # get hash of all information we want to change
    my @tagInfoList = $exifTool->GetNewTagInfoList($tagTablePtr);
    Image::ExifTool::GenerateTagIDs($tagTablePtr);   # make sure IDs are generated
    my $tagInfo;
    foreach $tagInfo (@tagInfoList) {
        my $tag = $tagInfo->{TagID};
        my $path = $$tagInfo{PropertyPath};
        unless ($path) {
            $exifTool->Warn("Can't write XMP:$tag (namespace unknown)");
            next;
        }
        # change our property path namespace prefixes to conform
        # to the ones used in this file
        $path = ConformPathToNamespace($exifTool, $path);
        # find existing property
        my $capList = $capture{$path};
        my $newValueHash = $exifTool->GetNewValueHash($tagInfo);
        my @newValues = Image::ExifTool::GetNewValues($newValueHash);
        my %attrs;
        # delete existing entry if necessary
        if ($capList) {
            # take attributes from old values if they exist
            %attrs = %{$capList->[1]};
            my $overwrite = Image::ExifTool::IsOverwriting($newValueHash);
            if ($overwrite) {
                my ($delPath, @matchingPaths);
                # check to see if this is an indexed list item
                if ($path =~ / /) {
                    my $pathPattern;
                    ($pathPattern = $path) =~ s/ 000/ \\d\{3\}/g;
                    @matchingPaths = sort grep(/^$pathPattern$/, keys %capture);
                } else {
                    push @matchingPaths, $path;
                }
                foreach $path (@matchingPaths) {
                    my ($val, $attrs) = @{$capture{$path}};
                    if ($overwrite < 0) {
                        # only overwrite specific values
                        next unless Image::ExifTool::IsOverwriting($newValueHash, $val);
                    }
                    $verbose > 1 and print "    - XMP:$$tagInfo{Name} = '$val'\n";
                    # save attributes and path from this deleted property
                    # so we can replace it exactly
                    %attrs = %$attrs;
                    $delPath = $path;
                    delete $capture{$path};
                    ++$changed;
                }
                next unless $delPath or $$tagInfo{List};
                if ($delPath) {
                    $path = $delPath;
                } else {
                    # don't change tag if we couldn't delete old copy unless this is a list
                    next unless $$tagInfo{List};
                    # add to end of list (give it a large list index)
                    $path =~ m/ \d{3}/g or warn "Internal error: no list index!\n", next;
                    substr($path, pos($path)-3, 3) = $listIndex++;
                }
            }
        }
        next unless @newValues; # done if no new values specified
        # don't add new tag if it didn't exist before unless specified
        next unless $capList or Image::ExifTool::IsCreating($newValueHash);

        # set default language attribute for lang-alt lists
        # (currently on support changing the default language)
        if ($$tagInfo{Writable} and $$tagInfo{Writable} eq 'lang-alt') {
            $attrs{'xml:lang'} = 'x-default';
        }
        for (;;) {
            my $newValue = EscapeHTML(shift @newValues);
            $capture{$path} = [ $newValue, \%attrs ];
            $verbose > 1 and print "    + XMP:$$tagInfo{Name} = '$newValue'\n";
            ++$changed;
            last unless @newValues;
            $path =~ m/ \d{3}/g or warn "Internal error: no list index!\n", next;
            substr($path, pos($path)-3, 3) = $listIndex++;
            $capture{$path} and warn "Too many entries in XMP list!\n", next;
        }
    }
    # remove the ExifTool members we created
    delete $exifTool->{XMP_CAPTURE};
    delete $exifTool->{XMP_NS};

    # return now if we didn't change anything
    return undef unless $changed;
#
# write out the new XMP information
#
    # start writing the XMP data
    my $newData = $pktOpen . $xmpOpen . $rdfOpen;

    # generate a (pseudo) unique ID
    my $n;
    my $time = time();
    unless ($seeded) {
        my $seed = $time ^ ($$ + ($$ << 15));
        srand($seed);
        $seeded = 1;
    }
    # some system-dependent strings to futher randomize the ID
    my @strs = ( sprintf("%x  ",$time), scalar($exifTool),
                 scalar($dirInfo), scalar(\%nsUsed) );
    my $str = join('', map {substr($_, -6, 4)} @strs);
    my $uniqueID = '';
    for ($n=0; $n<16; ++$n) {
        $uniqueID .= '-' if $n>2 and $n<12 and not ($n&0x01);
        $uniqueID .= sprintf("%.2x", int(rand(256) + unpack("x$n C",$str)) & 0xff);
    }

    # initialize current property path list
    my @curPropList;
    my (%nsCur, $path, $prop);

    foreach $path (sort keys %capture) {
        my @propList = split('/',$path); # get property list
        # must open/close rdf:Description too
        unshift @propList, $rdfDesc;
        # make sure we have defined all necessary namespaces
        my (%nsNew, $newDesc);
        foreach $prop (@propList) {
            $prop =~ /(.*):/ or next;
            $1 eq 'rdf' and next;   # rdf namespace already defined
            my $nsNew = $nsUsed{$1};
            unless ($nsNew) {
                $nsNew = $nsURI{$1}; # we must have added a namespace
                unless ($nsNew) {
                    $xmpErr = "Undefined XMP namespace: $1";
                    next;
                }
            }
            $nsNew{$1} = $nsNew;
            # need a new description if any new namespaces
            $newDesc = 1 unless $nsCur{$1};
        }
        my $closeTo = 0;
        unless ($newDesc) {
            # find first property where the current path differs from the new path
            for ($closeTo=0; $closeTo<@curPropList; ++$closeTo) {
                last unless $closeTo < @propList;
                last unless $propList[$closeTo] eq $curPropList[$closeTo];
            }
        }
        # close out properties down to the common base path
        while (@curPropList > $closeTo) {
            ($prop = pop @curPropList) =~ s/ .*//;
            $newData .= (' ' x scalar(@curPropList)) . " </$prop>\n";
        }
        if ($newDesc) {
            # open the new description
            $prop = $rdfDesc;
            %nsCur = %nsNew;            # save current namespaces
            $newData .= "\n <$prop about='uuid:$uniqueID'";
            foreach (sort keys %nsCur) {
                $newData .= "\n  xmlns:$_='$nsCur{$_}'";
            }
            $newData .= ">\n";
            push @curPropList, $prop;
        }
        # loop over all values for this new property
        my $capList = $capture{$path};
        my ($val, $attrs) = @$capList;
        $debug and print "$path = $val\n";
        # open new properties
        my $attr;
        for ($n=@curPropList; $n<$#propList; ++$n) {
            $prop = $propList[$n];
            push @curPropList, $prop;
            # remove list index if it exists
            $prop =~ s/ .*//;
            $attr = '';
            if ($prop ne $rdfDesc and $propList[$n+1] !~ /^rdf:/) {
                # need parseType='Resource' to avoid new 'rdf:Description'
                $attr = " rdf:parseType='Resource'";
            }
            $newData .= (' ' x scalar(@curPropList)) . "<$prop$attr>\n";
        }
        my $prop2 = pop @propList;   # get new property name
        $prop2 =~ s/ .*//;  # remove list index if it exists
        $newData .= (' ' x scalar(@curPropList)) . " <$prop2";
        # print out attributes
        foreach $attr (sort keys %$attrs) {
            my $attrVal = $$attrs{$attr};
            my $quot = ($attrVal =~ /'/) ? "'" : '"';
            $newData .= " $attr=$quot$attrVal$quot";
        }
        $newData .= ">$val</$prop2>\n";
    }
    # close off any open elements
    while ($prop = pop @curPropList) {
        $prop =~ s/ .*//;   # remove list index if it exists
        $newData .= (' ' x scalar(@curPropList)) . " </$prop>\n";
    }
    $newData .= $rdfClose . $xmpClose;
    # (the XMP standard recommends writing 2k-4k of white space before the
    # packet trailer, with a newline every 100 characters)
    $newData .= ((' ' x 100) . "\n") x 24 unless $exifTool->Options('Compact');
    $newData .= $pktClose;
#
# clean up and return our data
#
    # remove the ExifTool members we created
    delete $exifTool->{XMP_CAPTURE};
    delete $exifTool->{XMP_NS};

    # return empty data if no properties exist
    $newData = '' unless %capture;

    if ($xmpErr) {
        $exifTool->Warn($xmpErr);
        return undef;
    }
    $exifTool->{CHANGED} += $changed;
    $debug > 1 and $newData and print $newData,"\n";
    return $newData;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WriteXMP.pl - Routines for writing XMP metadata

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::XMP.

=head1 DESCRIPTION

This file contains routines to write XMP metadata.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
