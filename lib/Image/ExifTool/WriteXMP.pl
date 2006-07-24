#------------------------------------------------------------------------------
# File:         WriteXMP.pl
#
# Description:  Write XMP meta information
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
use Image::ExifTool qw(:DataAccess :Utils);

sub CheckXMP($$$);
sub SetPropertyPath($$;$$);
sub CaptureXMP($$$;$);

my $debug = 0;

# XMP structures (each structure is similar to a tag table so we can
# recurse through them in SetPropertyPath() as if they were tag tables)
my %xmpStruct = (
    ResourceRef => {
        NAMESPACE => 'stRef',
        InstanceID      => { },
        DocumentID      => { },
        VersionID       => { },
        RenditionClass  => { },
        RenditionParams => { },
        Manager         => { },
        ManagerVariant  => { },
        ManageTo        => { },
        ManageUI        => { },
    },
    ResourceEvent => {
        NAMESPACE => 'stEvt',
        action          => { },
        instanceID      => { },
        parameters      => { },
        softwareAgent   => { },
        when            => { },
    },
    JobRef => {
        NAMESPACE => 'stJob',
        name        => { },
        id          => { },
        url         => { },
    },
    Version => {
        NAMESPACE => 'stVer',
        comments    => { },
        event       => { Struct => 'ResourceEvent' },
        modifyDate  => { },
        modifier    => { },
        version     => { },
    },
    Thumbnail => {
        NAMESPACE => 'xapGImg',
        height      => { },
        width       => { },
       'format'     => { },
        image       => { },
    },
    IdentifierScheme => {
        NAMESPACE => 'xmpidq',
        Scheme      => { }, # qualifier for xmp:Identifier only
    },
    Dimensions => {
        NAMESPACE => 'stDim',
        w           => { },
        h           => { },
        unit        => { },
    },
    Colorant => {
        NAMESPACE => 'xapG',
        swatchName  => { },
        mode        => { },
        type        => { },
        cyan        => { },
        magenta     => { },
        yellow      => { },
        black       => { },
        red         => { },
        green       => { },
        blue        => { },
        L           => { },
        A           => { },
        B           => { },
    },
    Font => {
        NAMESPACE => 'stFnt',
        fontName    => { },
        fontFamily  => { },
        fontFace    => { },
        fontType    => { },
        versionString => { },
        composite   => { },
        fontFileName=> { },
        childFontFiles=> { List => 'Seq' },
    },
    # the following stuctures are different:  They don't have
    # their own namespaces -- instead they use the parent namespace
    Flash => {
        NAMESPACE => 'exif',
        Fired       => { },
        Return      => { },
        Mode        => { },
        Function    => { },
        RedEyeMode  => { },
    },
    OECF => {
        NAMESPACE => 'exif',
        Columns     => { },
        Rows        => { },
        Names       => { },
        Values      => { },
    },
    CFAPattern => {
        NAMESPACE => 'exif',
        Columns     => { },
        Rows        => { },
        Values      => { },
    },
    DeviceSettings => {
        NAMESPACE => 'exif',
        Columns     => { },
        Rows        => { },
        Settings    => { },
    },
    # Iptc4xmpCore structures
    ContactInfo => {
        NAMESPACE => 'Iptc4xmpCore',
        CiAdrCity   => { },
        CiAdrCtry   => { },
        CiAdrExtadr => { },
        CiAdrPcode  => { },
        CiAdrRegion => { },
        CiEmailWork => { },
        CiTelWork   => { },
        CiUrlWork   => { },
    },
    # Dynamic Media structures
    BeatSpliceStretch => {
        NAMESPACE => 'xmpDM',
        useFileBeatsMarker  => { },
        riseInDecibel       => { },
        riseInTimeDuration  => { },
    },
    Marker => {
        NAMESPACE => 'xmpDM',
        startTime   => { },
        duration    => { },
        comment     => { },
        name        => { },
        location    => { },
        target      => { },
        type        => { },
    },
    Media => {
        NAMESPACE => 'xmpDM',
        path        => { },
        track       => { },
        startTime   => { },
        duration    => { },
        managed     => { },
        webStatement=> { },
    },
    ProjectLink => {
        NAMESPACE => 'xmpDM',
        type        => { },
        path        => { },
    },
    ResampleStretch => {
        NAMESPACE => 'xmpDM',
        quality     => { },
    },
    Time => {
        NAMESPACE => 'xmpDM',
        value       => { },
        scale       => { },
    },
    Timecode => {
        NAMESPACE => 'xmpDM',
        timeValue   => { },
        timeFormat  => { },
    },
    TimeScaleStretch => {
        NAMESPACE => 'xmpDM',
        quality     => { },
        frameSize   => { },
        frameOverlappingPercentage => { },
    },
);

# Lookup to translate our namespace prefixes into URI's.  This list need
# not be complete, but it must contain an entry for each namespace prefix
# (NAMESPACE) for writable tags in the XMP tables or the table above
my %nsURI = (
    aux       => 'http://ns.adobe.com/exif/1.0/aux/',
    cc        => 'http://web.resource.org/cc/',
    crs       => 'http://ns.adobe.com/camera-raw-settings/1.0/',
    dc        => 'http://purl.org/dc/elements/1.1/',
    exif      => 'http://ns.adobe.com/exif/1.0/',
    iX        => 'http://ns.adobe.com/iX/1.0/',
    pdf       => 'http://ns.adobe.com/pdf/1.3/',
    pdfx      => 'http://ns.adobe.com/pdfx/1.3/',
    photoshop => 'http://ns.adobe.com/photoshop/1.0/',
    rdf       => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    stDim     => 'http://ns.adobe.com/xap/1.0/sType/Dimensions#',
    stEvt     => 'http://ns.adobe.com/xap/1.0/sType/ResourceEvent#',
    stFnt     => 'http:ns.adobe.com/xap/1.0/sType/Font#',
    stJob     => 'http://ns.adobe.com/xap/1.0/sType/Job#',
    stRef     => 'http://ns.adobe.com/xap/1.0/sType/ResourceRef#',
    stVer     => 'http://ns.adobe.com/xap/1.0/sType/Version#',
    tiff      => 'http://ns.adobe.com/tiff/1.0/',
   'x'        => 'adobe:ns:meta/',
    xapG      => 'http://ns/adobe.com/xap/1.0/g/',
    xapGImg   => 'http://ns/adobe.com/xap/1.0/g/img/',
    xmp       => 'http://ns.adobe.com/xap/1.0/',
    xmpBJ     => 'http://ns.adobe.com/xap/1.0/bj/',
    xmpDM     => 'http://ns.adobe.com/xmp/1.0/DynamicMedia/',
    xmpMM     => 'http://ns.adobe.com/xap/1.0/mm/',
    xmpRights => 'http://ns.adobe.com/xap/1.0/rights/',
    xmpTPg    => 'http://ns.adobe.com/xap/1.0/t/pg/',
    xmpidq    => 'http://ns/adobe.com/xmp/Identifier/qual/1.0',
    Iptc4xmpCore => 'http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/',
    xmpPLUS   => 'http://ns.adobe.com/xap/1.0/PLUS/',
    dex       => 'http://ns.optimasc.com/dex/1.0/',
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
my $pktOpen = "<?xpacket begin='\xef\xbb\xbf' id='W5M0MpCehiHzreSzNTczkc9d'?>\n";
my $xmlOpen = "\xef\xbb\xbf<?xml version='1.0' encoding='UTF-8'?>\n";
my $xmpOpen = "<x:xmpmeta xmlns:x='$nsURI{x}' $x_toolkit>\n";
my $rdfOpen = "<rdf:RDF xmlns:rdf='$nsURI{rdf}'>\n";
my $rdfClose = "</rdf:RDF>\n";
my $xmpClose = "</x:xmpmeta>\n";
my $pktClose =  "<?xpacket end='w'?>";

# Update XMP tag tables when this library is loaded:
# - generate all TagID's (required when writing)
# - generate PropertyPath for structure elements
# - add necessary inverse conversion routines
{
    my $mainTable = GetTagTable('Image::ExifTool::XMP::Main');
    GenerateTagIDs($mainTable);
    my $mainTag;
    foreach $mainTag (keys %$mainTable) {
        my $mainInfo = $mainTable->{$mainTag};
        next unless ref $mainInfo eq 'HASH' and $mainInfo->{SubDirectory};
        my $table = GetTagTable($mainInfo->{SubDirectory}->{TagTable});
        # add new namespace if NAMESPACE is ns/uri pair
        if (ref $$table{NAMESPACE} eq 'ARRAY') {
            my $ns = $table->{NAMESPACE}->[0];
            $nsURI{$ns} = $table->{NAMESPACE}->[1];
            $$table{NAMESPACE} = $ns;
        }
        $$table{WRITE_PROC} = \&WriteXMP;   # set WRITE_PROC for all tables
        GenerateTagIDs($table);
        my $tag;
        $table->{CHECK_PROC} = \&CheckXMP; # add our write check routine
        foreach $tag (TagTableKeys($table)) {
            my $tagInfo = $$table{$tag};
            next unless ref $tagInfo eq 'HASH';
            # must set PropertyPath now for all tags that are Struct elements
            # (normal tags will get set later if they are actually written)
            SetPropertyPath($table, $tag) if $$tagInfo{Struct};
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
    return undef unless $format and $format ne 'string';
    if ($format eq 'rational' or $format eq 'real') {
        # make sure the value is a valid floating point number
        Image::ExifTool::IsFloat($$valPtr) or return 'Not a floating point number';
        if ($format eq 'rational') {
            $$valPtr = join('/', Image::ExifTool::Rationalize($$valPtr));
        }
    } elsif ($format eq 'integer') {
        # make sure the value is integer
        if (Image::ExifTool::IsInt($$valPtr)) {
            # no conversion required (converting to 'int' would remove leading '+')
        } elsif (Image::ExifTool::IsHex($$valPtr)) {
            $$valPtr = hex($$valPtr);
        } else {
            return 'Not an integer';
        }
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
    } elsif ($format eq '1') {
        # this is the entire XMP data block
        return undef if $$valPtr =~ /^\0*<\0*\?\0*x\0*p\0*a\0*c\0*k\0*e\0*t/;
        return 'Invalid XMP data' unless $$valPtr =~ /^<x:xmpmeta/;
        # add required xpacket header/trailer
        $$valPtr = $pktOpen . $$valPtr . $pktClose;
    } else {
        return "Unknown XMP format: $format";
    }
    return undef;   # success!
}

#------------------------------------------------------------------------------
# Get PropertyPath for specified tagInfo
# Inputs: 0) tagInfo reference
# Returns: PropertyPath string
sub GetPropertyPath($)
{
    my $tagInfo = shift;
    unless ($$tagInfo{PropertyPath}) {
        SetPropertyPath($$tagInfo{Table}, $$tagInfo{TagID});
    }
    return $$tagInfo{PropertyPath};
}

#------------------------------------------------------------------------------
# Set PropertyPath for specified tag (also for any structure elements)
# Inputs: 0) tagTable reference, 1) tagID, 2) structure reference (or undef),
#         3) property list up to this point (or undef), 4) true if tag is a list
sub SetPropertyPath($$;$$)
{
    my ($tagTablePtr, $tagID, $structPtr, $propList) = @_;
    my $table = $structPtr || $tagTablePtr;
    my $tagInfo = $$table{$tagID};
    my $ns = $$table{NAMESPACE};
    # don't override existing main table entry if already set by a Struct
    return if not $structPtr and $$tagInfo{PropertyPath};
    $ns or warn("No namespace for $tagID\n"), return;
    my (@propList, $listType);
    $propList and @propList = @$propList;
    push @propList, "$ns:$tagID";
    # lang-alt lists are handled specially, signified by Writable='lang-alt'
    # (they aren't true lists since we currently only allow setting of
    # the default language.)
    if ($$tagInfo{Writable} and $$tagInfo{Writable} eq 'lang-alt') {
        $listType = 'Alt';
    } else {
        $listType = $$tagInfo{List};
    }
    # add required properties if this is a list
    push @propList, "rdf:$listType", 'rdf:li 000' if $listType and $listType ne '1';
    # set PropertyPath for all elements of this structure if necessary
    if ($$tagInfo{Struct}) {
        my $struct = $xmpStruct{$$tagInfo{Struct}};
        $struct or warn("No XMP $$tagInfo{Struct} structure!\n"), return;
        my $tag;
        foreach $tag (keys %$struct) {
            next if $tag eq 'NAMESPACE';
            SetPropertyPath($tagTablePtr, $tag, $struct, \@propList);
        }
    }
    # use tagInfo for combined tag name if this was a Struct
    if ($structPtr) {
        my $tagName = GetXMPTagID(\@propList);
        $$tagTablePtr{$tagName} or warn("Tag $tagName not found!\n"), return;
        $tagInfo = $$tagTablePtr{$tagName};
        # must check again for List's at this level
        if ($$tagInfo{Writable} and $$tagInfo{Writable} eq 'lang-alt') {
            $listType = 'Alt';
        } else {
            $listType = $$tagInfo{List};
        }
        push @propList, "rdf:$listType", 'rdf:li 000' if $listType and $listType ne '1';
    }
    # set property path for tagInfo in main table
    $$tagInfo{PropertyPath} = join '/', @propList;
}

#------------------------------------------------------------------------------
# Capture shorthand XMP properties
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table
#         2) reference to array of XMP property path (last is current property)
#         3) reference to hash of property attributes
#         4) true to set error on unrecognized attributes
# Returns: number of shorthand properties captured
sub CaptureShorthand($$$;$)
{
    my ($exifTool, $propList, $attrs, $setError) = @_;
    my $attr;
    my @attrList = keys %$attrs;
    my $count = 0;
    foreach $attr (@attrList) {
        if ($attr =~ /^xmlns:(.*)/) {
            # remember all namespaces (except x which we open ourselves)
            my $ns = $1;
            my $nsUsed = $exifTool->{XMP_NS};
            unless ($ns eq 'x' or $ns eq 'iX' or defined $$nsUsed{$ns}) {
                $$nsUsed{$ns} = $$attrs{$attr};
            }
        } elsif ($recognizedAttrs{$attr}) {
            # save UUID to use same ID when writing
            if ($attr eq 'about') {
                if (not $exifTool->{XMP_UUID}) {
                    $exifTool->{XMP_UUID} = $$attrs{about};
                } elsif ($exifTool->{XMP_UUID} ne $$attrs{about}) {
                    $exifTool->Error("Multiple XMP UUID's not handled", 1);
                }
            }
        } else {
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
            if ($ns and not $ignoreNamespace{$ns}) {
                # save this shorthand property
                push @$propList, "$ns:$name";
                CaptureXMP($exifTool, $propList, $$attrs{$attr});
                pop @$propList;
                # remove this attribute from list since we handled it
                delete $$attrs{$attr};
                ++$count;
            } elsif ($setError) {
                $exifTool->{XMP_ERROR} = "Can't handle XMP attribute '$attr'";
            }
        }
    }
    return $count;
}

#------------------------------------------------------------------------------
# Save XMP property name/value for rewriting
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table
#         2) reference to array of XMP property path (last is current property)
#         3) property value, 4) optional reference to hash of property attributes
sub CaptureXMP($$$;$)
{
    my ($exifTool, $propList, $val, $attrs) = @_;
    $attrs or $attrs = { };

    if (defined $val) {
        return unless @$propList > 2;
        if ($$propList[0] =~ /^x:x(a|m)pmeta$/ and
            $$propList[1] eq 'rdf:RDF' and
            $$propList[2] eq $rdfDesc)
        {
            # capture any shorthand properties in the attribute list
            my $shorthand = CaptureShorthand($exifTool, $propList, $attrs);
            # no properties to save yet if this is just the description
            return unless @$propList > 3;
            # save information about this property
            my $capture = $exifTool->{XMP_CAPTURE};
            my $path = join('/', @$propList[3..$#$propList]);
            if (defined $$capture{$path}) {
                $exifTool->{XMP_ERROR} = "Duplicate XMP property: $path";
            } elsif (length $val or not $shorthand) {
                $$capture{$path} = [$val, $attrs];
            }
        } else {
            $exifTool->{XMP_ERROR} = 'Improperly enclosed XMP property: ' . join('/',@$propList);
        }
    } else {
        # this property has sub-properties, so just handle the attributes
        # (set an error on any unrecognized attributes here, because they will be lost)
        CaptureShorthand($exifTool, $propList, $attrs, 1);
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
# Inputs: 0) ExifTool object reference, 1) source dirInfo reference,
#         2) [optional] tag table reference
# Returns: with tag table: new XMP data (may be empty if no XMP data) or undef on error
#          without tag table: 1 on success, 0 if not valid XMP file, -1 on write error
# Notes: May set dirInfo InPlace flag to rewrite with specified DirLen
sub WriteXMP($$;$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my (%capture, %nsUsed, $xmpErr, $uuid);
    my $changed = 0;
    my $xmpFile = (not $tagTablePtr);   # this is an XMP data file if no $tagTablePtr
    my $preferred = $xmpFile;   # write XMP as preferred if this is an XMP file
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

    if ($dataPt or $xmpFile) {
        delete $exifTool->{XMP_ERROR};
        delete $exifTool->{XMP_UUID};
        # extract all existing XMP information (to the XMP_CAPTURE hash)
        my $success = ProcessXMP($exifTool, $dirInfo, $tagTablePtr);
        # don't continue if there is nothing to parse or if we had a parsing error
        unless ($success and not $exifTool->{XMP_ERROR}) {
            my $err = $exifTool->{XMP_ERROR} || 'Error parsing XMP';
            # may ignore this error only if we were successful
            if ($xmpFile) {
                my $raf = $$dirInfo{RAF};
                # allow empty XMP data so we can create something from nothing
                if ($success or not $raf->Seek(0,2) or $raf->Tell()) {
                    if ($exifTool->Error($err, $success)) {
                        delete $exifTool->{XMP_CAPTURE};
                        return 0;
                    }
                }
            } else {
                if ($exifTool->Warn($err, $success)) {
                    delete $exifTool->{XMP_CAPTURE};
                    return undef;
                }
            }
        }
        $uuid = $exifTool->{XMP_UUID} || '';
        delete $exifTool->{XMP_ERROR};
        delete $exifTool->{XMP_UUID};
    } else {
        $uuid = '';
    }
#
# add, delete or change information as specified
#
    # get hash of all information we want to change
    my @tagInfoList = $exifTool->GetNewTagInfoList();
    my $tagInfo;
    foreach $tagInfo (@tagInfoList) {
        next unless $exifTool->GetGroup($tagInfo, 0) eq 'XMP';
        my $tag = $tagInfo->{TagID};
        my $path = GetPropertyPath($tagInfo);
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
                    $exifTool->VPrint(1, "    - XMP:$$tagInfo{Name} = '$val'\n");
                    # save attributes and path from this deleted property
                    # so we can replace it exactly
                    %attrs = %$attrs;
                    $delPath = $path unless $delPath;
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
                    $path =~ m/ (\d{3})/g or warn "Internal error: no list index!\n", next;
                    my $listIndex = $1;
                    my $pos = pos($path) - 3;
                    for (;;) {
                        substr($path, $pos, 3) = ++$listIndex;
                        last unless $capture{$path};
                    }
                }
            } elsif ($path =~ m/ (\d{3})/g) {
                # add to end of list
                my $listIndex = $1;
                my $pos = pos($path) - 3;
                for (;;) {
                    substr($path, $pos, 3) = ++$listIndex;
                    last unless $capture{$path};
                }
            }
        }
        # get list of new values (done if no new values specified)
        my @newValues = Image::ExifTool::GetNewValues($newValueHash) or next;
        # don't add new tag if it didn't exist before unless specified
        # (or unless this is an XMP data file and we aren't avoiding this tag)
        next unless $capList or Image::ExifTool::IsCreating($newValueHash) or
            ($preferred and not $$tagInfo{Avoid});

        # set default language attribute for lang-alt lists
        # (currently on support changing the default language)
        if ($$tagInfo{Writable} and $$tagInfo{Writable} eq 'lang-alt') {
            $attrs{'xml:lang'} = 'x-default';
        }
        for (;;) {
            my $newValue = EscapeHTML(shift @newValues);
            $capture{$path} = [ $newValue, \%attrs ];
            $exifTool->VPrint(1, "    + XMP:$$tagInfo{Name} = '$newValue'\n");
            ++$changed;
            last unless @newValues;
            $path =~ m/ (\d{3})/g or warn("Internal error: no list index!\n"), next;
            my $listIndex = $1;
            my $pos = pos($path) - 3;
            for (;;) {
                substr($path, $pos, 3) = ++$listIndex;
                last unless $capture{$path};
            }
            $capture{$path} and warn("Too many entries in XMP list!\n"), next;
        }
    }
    # remove the ExifTool members we created
    delete $exifTool->{XMP_CAPTURE};
    delete $exifTool->{XMP_NS};

    # return now if we didn't change anything
    unless ($changed) {
        return undef unless $xmpFile;   # just rewrite original XMP
        # get DataPt again because it may have been set by ProcessXMP
        $dataPt = $$dirInfo{DataPt};
        unless (defined $dataPt) {
            $exifTool->Error("Nothing to write");
            return 1;
        }
        return 1 if Write($$dirInfo{OutFile}, $$dataPt);
        return -1;
    }
#
# write out the new XMP information
#
    # start writing the XMP data
    my $newData = '';
    $newData .= $pktOpen unless $$exifTool{XMP_NO_XPACKET};
    $newData .= $xmlOpen if $$exifTool{XMP_IS_XML};
    $newData .= $xmpOpen . $rdfOpen;

    # initialize current property path list
    my @curPropList;
    my (%nsCur, $path, $prop, $n);

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
            $newData .= "\n <$prop about='$uuid'";
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
            my $quot = ($attrVal =~ /'/) ? '"' : "'";
            $newData .= " $attr=$quot$attrVal$quot";
        }
        $newData .= ">$val</$prop2>\n";
    }
    # close off any open elements
    while ($prop = pop @curPropList) {
        $prop =~ s/ .*//;   # remove list index if it exists
        $newData .= (' ' x scalar(@curPropList)) . " </$prop>\n";
    }
#
# clean up, close out the XMP, and return our data
#
    # remove the ExifTool members we created
    delete $exifTool->{XMP_CAPTURE};
    delete $exifTool->{XMP_NS};

    $newData .= $rdfClose . $xmpClose;

    # (the XMP standard recommends writing 2k-4k of white space before the
    # packet trailer, with a newline every 100 characters)
    unless ($$exifTool{XMP_NO_XPACKET}) {
        my $pad = (' ' x 100) . "\n";
        if ($$dirInfo{InPlace}) {
            # pad to specified DirLen
            my $dirLen = $$dirInfo{DirLen} || length $$dataPt;
            my $len = length($newData) + length($pktClose);
            if ($len > $dirLen) {
                $exifTool->Warn('Not enough room to edit XMP in place');
                return undef;
            }
            my $num = int(($dirLen - $len) / length($pad));
            if ($num) {
                $newData .= $pad x $num;
                $len += length($pad) * $num;
            }
            $len < $dirLen and $newData .= (' ' x ($dirLen - $len - 1)) . "\n";
        } elsif (not $exifTool->Options('Compact')) {
            $newData .= $pad x 24;
        }
        $newData .= $pktClose;
    }
    # return empty data if no properties exist
    $newData = '' unless %capture or $$dirInfo{InPlace};

    if ($xmpErr) {
        if ($xmpFile) {
            $exifTool->Error($xmpErr);
            return -1;
        }
        $exifTool->Warn($xmpErr);
        return undef;
    }
    $exifTool->{CHANGED} += $changed;
    $debug > 1 and $newData and print $newData,"\n";
    return $newData unless $xmpFile;
    return 1 if Write($$dirInfo{OutFile}, $newData);
    return -1;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WriteXMP.pl - Write XMP meta information

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::XMP.

=head1 DESCRIPTION

This file contains routines to write XMP metadata.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::XMP(3pm)|Image::ExifTool::XMP>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
