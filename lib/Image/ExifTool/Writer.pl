#------------------------------------------------------------------------------
# File:         Writer.pl
#
# Description:  ExifTool write routines
#
# Notes:        Also contains some less used ExifTool functions
#
# URL:          http://owl.phy.queensu.ca/~phil/exiftool/
#
# Revisions:    12/16/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool;

use strict;

use Image::ExifTool::TagLookup qw(FindTagInfo);

sub AssembleRational($$@);

my $loadedAllTables;    # flag indicating we loaded all tables
my $evalWarning;        # eval warning message

# the following is a road map of where we write each directory
# in the different types of files.
my %dirMap = (
    JPEG => {
        IFD0         => 'APP1',
        IFD1         => 'APP1',
        XMP          => 'APP1',
        ICC_Profile  => 'APP2',
        PreviewImage => 'APP5',
        Photoshop    => 'APP13',
        ExifIFD      => 'IFD0',
        GPS          => 'IFD0',
        SubIFD       => 'IFD0',
        GlobParamIFD => 'IFD0',
        PrintIM      => 'IFD0',
        IPTC         => 'Photoshop',
        InteropIFD   => 'ExifIFD',
        MakerNotes   => 'ExifIFD',
        Comment      => 'COM',
    },
    TIFF => {
        IFD0         => 'TIFF',
        IFD1         => 'TIFF',
        XMP          => 'IFD0',
        ICC_Profile  => 'IFD0',
        ExifIFD      => 'IFD0',
        GPS          => 'IFD0',
        SubIFD       => 'IFD0',
        GlobParamIFD => 'IFD0',
        PrintIM      => 'IFD0',
        IPTC         => 'IFD0',
        InteropIFD   => 'ExifIFD',
        MakerNotes   => 'ExifIFD',
    },
);
# names of valid EXIF directories:
my %exifDirs = (
    ifd0         => 'IFD0',
    ifd1         => 'IFD1',
    exififd      => 'ExifIFD',
    subifd       => 'SubIFD',
    globparamifd => 'GlobParamIFD',
    interopifd   => 'InteropIFD',
    makernotes   => 'MakerNotes',
);
# min/max values for integer formats
my %intRange = (
    'int8u'  => [0, 0xff],
    'int8s'  => [-0x80, 0x7f],
    'int16u' => [0, 0xffff],
    'int16s' => [-0x8000, 0x7fff],
    'int32u' => [0, 0xffffffff],
    'int32s' => [-0x80000000, 0x7fffffff],
);
my $maxSegmentLen = 0xfffd; # maximum length of data in a JPEG segment


#------------------------------------------------------------------------------
# Set tag value
# Inputs: 0) ExifTool object reference
#         1) tag key, tag name or undef to reset all previous SetNewValue() calls
#         2) new value, or undef to delete tag
#         3-N) Options:
#           Type => PrintConv, ValueConv or Raw - specifies value type
#           AddValue => 0 or 1 - add to list of existing values instead of overwriting
#           DelValue => 0 or 1 - delete this existing value value from a list
#           Group => EXIF, IPTC or XMP - tag group (case insensitive)
#           Replace => 0, 1 or 2 - overwrite previous new values (2=reset)
# Returns: number of tags set (plus error string in list context)
# Notes: For tag lists (like Keywords), call repeatedly with the same tag name for
#        each value in the list.  Internally, the new information is stored in
#        the following members of the $self->{NEW_VALUE}->{$tagInfo} hash:
#           TagInfo - tag info ref
#           DelValue - list ref for values to delete
#           Value - list ref for values to add
#           IsCreating - must be set for the tag to be added.  otherwise just
#                      changed if it already exists
#           WriteGroup - group name where information is being written
#           Next - pointer to next newValueHash (if more than one)
sub SetNewValue($;$$%)
{
    local $_;
    my ($self, $tag, $value, %options) = @_;
    my ($err, $tagInfo);
    my $verbose = $self->Options('Verbose');

    unless (defined $tag) {
        # remove any existing set values
        delete $self->{NEW_VALUE};
        $verbose > 1 and print "Cleared new values\n";
        return 1;
    }
    $tag =~ s/ .*//;    # convert from tag key to tag name if necessary
    my @matchingTags = FindTagInfo($tag);
    unless (@matchingTags) {
        $err = "Tag '$tag' does not exist";
        if (wantarray) {
            return (0, $err);
        } else {
            warn "$err\n";
            return 0;
        }
    }
    # get group name that we're looking for
    my $foundMatch = 0;
    my ($wantGroup, $ifdName);
    if ($options{Group}) {
        $wantGroup = $options{Group};
        $ifdName = $exifDirs{lc($wantGroup)};
    }
    # determine the groups for all tags found, and the tag with
    # the highest priority group
    my (@tagInfoList, %writeGroup, %preferred, %tagPriority, $avoid);
    my $highestPriority = -1;
    foreach $tagInfo (@matchingTags) {
        $tag = $tagInfo->{Name};    # set tag so warnings will use proper case
        my ($writeGroup, $priority);
        if ($wantGroup) {
            # only set tag in specified group
            $writeGroup = $self->GetGroup($tagInfo, 0);
            unless ($writeGroup =~ /^$wantGroup$/i) {
                next unless $writeGroup eq 'EXIF' and $ifdName;
                $writeGroup = $ifdName;  # write to the specified IFD
            }
            $priority = 1000;   # highest priority since group was specified
        }
        ++$foundMatch;
        # must do a dummy call to the write proc to autoload write package
        # before checking Writable flag
        my $table = $tagInfo->{Table};
        my $writeProc = $table->{WRITE_PROC};
        next unless $writeProc and &$writeProc();
        my $writable = $tagInfo->{Writable};
        next unless $writable or ($table->{WRITABLE} and not defined $writable);
        next if $tagInfo->{Protected} and not $options{Protected};
        # set specific write group (if we didn't already)
        unless ($writeGroup and $writeGroup ne 'EXIF') {
            $writeGroup = $tagInfo->{WriteGroup};   # use default write group
            # use group 0 name if no WriteGroup specified
            my $group0 = $self->GetGroup($tagInfo, 0);
            $writeGroup or $writeGroup = $group0;
            # get priority for this group
            unless ($priority) {
                $priority = $self->{WRITE_PRIORITY}->{lc($writeGroup)};
                unless ($priority) {
                    $priority = $self->{WRITE_PRIORITY}->{lc($group0)} || 0;
                }
            }
        }
        $tagPriority{$tagInfo} = $priority;
        if ($priority > $highestPriority) {
            $highestPriority = $priority;
            %preferred = ( $tagInfo => 1 );
            $avoid = 0;
            ++$avoid if $$tagInfo{Avoid};
        } elsif ($priority == $highestPriority) {
            # create all tags with highest priority
            $preferred{$tagInfo} = 1;
            ++$avoid if $$tagInfo{Avoid};
        }
        push @tagInfoList, $tagInfo;
        $writeGroup{$tagInfo} = $writeGroup;
    }
    # don't create tags with priority 0 if group priorities are set
    if ($highestPriority == 0 and %{$self->{WRITE_PRIORITY}}) {
        undef %preferred;
    }
    # avoid creating tags with 'Avoid' flag set if there are other alternatives
    if ($avoid and %preferred) {
        if ($avoid < scalar(keys %preferred)) {
            # just remove the 'Avoid' tags since there are other preferred tags
            foreach $tagInfo (@tagInfoList) {
                delete $preferred{$tagInfo} if $$tagInfo{Avoid};
            }
        } elsif ($highestPriority < 1000) {
            # look for another priority tag to create instead
            my $nextHighest = 0;
            my @nextBestTags;
            foreach $tagInfo (@tagInfoList) {
                my $priority = $tagPriority{$tagInfo} or next;
                next if $priority == $highestPriority;
                next if $priority < $nextHighest;
                next if $$tagInfo{Avoid} or $$tagInfo{Permanent};
                next if $writeGroup{$tagInfo} eq 'MakerNotes';
                if ($nextHighest < $priority) {
                    $nextHighest = $priority;
                    undef @nextBestTags;
                }
                push @nextBestTags, $tagInfo;
            }
            if (@nextBestTags) {
                # change our preferred tags to the next best tags
                undef %preferred;
                foreach $tagInfo (@nextBestTags) {
                    $preferred{$tagInfo} = 1;
                }
            }
        }
    }
    my $numSet = 0;
    my $prioritySet;
    my @requireTags;
    # sort tag info list in reverse order of priority (higest number last)
    # so we get the highest priority error message in the end
    @tagInfoList = sort { $tagPriority{$a} <=> $tagPriority{$b} } @tagInfoList;
    # loop through all valid tags to find the one(s) to write
    SetTagLoop: foreach $tagInfo (@tagInfoList) {
        my $writeGroup = $writeGroup{$tagInfo};
        my $permanent = $$tagInfo{Permanent};
        $writeGroup eq 'MakerNotes' and $permanent = 1 unless defined $permanent;
        $tag = $tagInfo->{Name};    # get proper case for tag name
        # convert the value
        my $val = $value;
        # can't delete permanent tags, so set value to empty string instead
        $val = '' if not defined $val and $permanent;
        my $type = $options{Type};
        $type or $type = $self->Options('PrintConv') ? 'PrintConv' : 'ValueConv';
        while (defined $val) {
            my $conv = $tagInfo->{$type};
            my $convInv = $tagInfo->{"${type}Inv"};
            if ($convInv) {
                # capture eval warnings too
                local $SIG{__WARN__} = sub { $evalWarning = $_[0]; };
                undef $evalWarning;
                #### eval PrintConvInv/ValueConvInv ($val)
                $val = eval $convInv;
                if ($@ or $evalWarning) {
                    $@ and $evalWarning = $@;
                    chomp $evalWarning;
                    $evalWarning =~ s/ at \(eval .*//s;
                    $err = "$evalWarning in $writeGroup:$tag (in ${type}Inv)";
                    $verbose > 2 and print "$err\n";
                    undef $val;
                    last;
                } elsif (not defined $val) {
                    $err = "Error converting value for $writeGroup:$tag (in ${type}Inv)";
                    $verbose > 2 and print "$err\n";
                    last;
                }
            } elsif ($conv) {
                if (ref $conv eq 'HASH') {
                    if ($val =~ /^Unknown\s*\((.+)\)$/i) {
                        $val = $1;    # was unknown
                        if ($val =~ /^0x([\da-fA-F]+)$/) {
                            $val = hex($val);   # convert hex value
                        }
                    } else {
                        my @patterns = ("^\Q$val\E\$", "^(?i)\Q$val\E\$",
                                        "^(?i)\Q$val\E","(?i)\Q$val\E");
                        my ($pattern, $found, $matches);
                        Pattern: foreach $pattern (@patterns) {
                            $matches = scalar grep /$pattern/, values(%$conv);
                            next unless $matches;
                            # multiple matches are bad unless they were exact
                            last if $matches > 1 and $pattern ne $patterns[0];
                            foreach (sort keys %$conv) {
                                if ($$conv{$_} =~ /$pattern/) {
                                    $val = $_;
                                    $found = 1;
                                    last Pattern;
                                }
                            }
                            last;
                        }
                        unless ($found) {
                            $err = "Can't convert $writeGroup:$tag ";
                            $verbose > 2 and print "$err\n";
                            if ($matches > 1) {
                                $err .= "(matches more than one $type)";
                            } else {
                                $err .= "(not in $type)";
                            }
                            undef $val;
                            last;
                        }
                    }
                } else {
                    $err = "Can't convert value for $writeGroup:$tag (no ${type}Inv)";
                    $verbose > 2 and print "$err\n";
                    undef $val;
                    last;
                }
            }
            # cycle through PrintConv, ValueConv
            if ($type eq 'PrintConv') {
                $type = 'ValueConv';
            } else {
                # do the CHECK_PROC to validate the value if it exists
                my $table = $tagInfo->{Table};
                if ($table and $table->{CHECK_PROC}) {
                    my $checkProc = $table->{CHECK_PROC};
                    my $err2 = &$checkProc($self, $tagInfo, \$val);
                    if ($err2) {
                        $err = "$err2 for $writeGroup:$tag";
                        $verbose > 2 and print "$err\n";
                        undef $val; # value was invalid
                    }
                } else {
                    warn "No check proc for $writeGroup:$tag\n";
                }
                last;
            }
        }
        if (not defined $val and defined $value) {
            # if value conversion failed, we must still add a NEW_VALUE
            # entry for this tag it it was a DelValue
            next unless $options{DelValue};
            $val = 'xxx never delete xxx';
        }
        $self->{NEW_VALUE} or $self->{NEW_VALUE} = { };
        if ($options{Replace}) {
            $self->GetNewValueHash($tagInfo, $writeGroup, 'delete');
            next if $options{Replace} == 2;
        }

        # set value in NEW_VALUE hash
        if (defined $val) {
            my $newValueHash = $self->GetNewValueHash($tagInfo, $writeGroup, 'create');
            if ($options{DelValue} or $options{AddValue}) {
                if ($options{DelValue}) {
                    # don't create if we are replacing a specific value
                    $newValueHash->{IsCreating} = 0 unless $val eq '';
                    # add delete value to list
                    push @{$newValueHash->{DelValue}}, $val;
                    if ($verbose > 1) {
                        my $verb = $permanent ? 'Replacing' : 'Deleting';
                        my $fromList = $tagInfo->{List} ? ' from list' : '';
                        print "$verb $writeGroup:$tag$fromList if value is '$val'\n";
                    }
                } elsif ($options{AddValue} and not $tagInfo->{List}) {
                    $err = "Can't add $writeGroup:$tag (not a List type)";
                    $verbose > 2 and print "$err\n";
                    next;
                }
                # flag any AddValue or DelValue by creating the DelValue list
                $newValueHash->{DelValue} or $newValueHash->{DelValue} = [ ];
            }
            # set priority flag to add only the high priority info
            # (will only create the priority tag if it doesn't exist,
            #  others get changed only if they already exist)
            if ($preferred{$tagInfo}) {
                if ($permanent) {
                    # don't create permanent tag but define IsCreating
                    # so we know that it is the preferred tag
                    $newValueHash->{IsCreating} = 0;
                } elsif (not ($newValueHash->{DelValue} and @{$newValueHash->{DelValue}}) or
                         # also create tag if any DelValue value is empty ('')
                         grep(/^$/,@{$newValueHash->{DelValue}}))
                {
                    $newValueHash->{IsCreating} = 1;
                }
            }
            unless ($options{DelValue}) {
                $newValueHash->{Value} or $newValueHash->{Value} = [ ];
                if ($tagInfo->{List}) {
                    # we can write a list of entries
                    push @{$newValueHash->{Value}}, $val;
                } else {
                    # not a List tag -- overwrite existing value
                    $newValueHash->{Value}->[0] = $val;
                }
                if ($verbose > 1) {
                    my $ifExists = $newValueHash->{IsCreating} ? '' : ' if tag already exists';
                    if ($options{AddValue}) {
                        print "Adding to $writeGroup:$tag$ifExists\n";
                    } else {
                        print "Writing $writeGroup:$tag$ifExists\n";
                    }
                }
            }
        } elsif ($permanent) {
            $err = "Can't delete $tag";
            $verbose > 1 and print "$err\n";
            next;
        } elsif ($options{AddValue} or $options{DelValue}) {
            $verbose > 1 and print "Adding/Deleting nothing does nothing\n";
        } else {
            # create empty new value hash entry to delete this tag
            $self->GetNewValueHash($tagInfo, $writeGroup, 'delete');
            $self->GetNewValueHash($tagInfo, $writeGroup, 'create');
            $verbose > 1 and print "Deleting $writeGroup:$tag\n";
        }
        ++$numSet;
        $prioritySet = 1 if $preferred{$tagInfo};
        # set markers in required tags
        if ($$tagInfo{Require}) {
            foreach (keys %{$$tagInfo{Require}}) {
                push @requireTags, $tagInfo->{Require}->{$_};
            }
        }
    }
    # print warning if we couldn't set our priority tag
    if ($err and ((not $numSet or not $prioritySet) or $verbose)) {
        warn "$err\n" unless wantarray;
    } elsif (not $numSet) {
        if ($foundMatch) {
            $err = "Sorry, $tag is not writable";
        } else {
            $err = "Tag '$wantGroup:$tag' does not exist";
        }
        warn "$err\n" unless wantarray;
    }
    # set markers to create all required tags too
    if (@requireTags) {
        # set marker to 'feed' value later
        $value = 0xfeedfeed if defined $value;
        foreach $tag (@requireTags) {
            $self->SetNewValue($tag, $value, Protected=>1);
        }
    }
    if (wantarray) {
        return ($numSet, $err);
    } else {
        return $numSet;
    }
}

#------------------------------------------------------------------------------
# set new values from information in specified file
# Inputs: 0) ExifTool object reference, 1) source file name or reference, etc
# Returns: Hash of information set successfully (includes Warning or Error messages)
sub SetNewValuesFromFile($$)
{
    my ($self, $srcFile) = @_;
    # read set all tags from specified file
    my $srcExifTool = new Image::ExifTool;
    my $opts = {MakerNotes=>1, Binary=>1, Duplicates=>1, List=>1};
    $opts->{IgnoreMinorErrors} = $self->Options('IgnoreMinorErrors');
    my $info = $srcExifTool->ImageInfo($srcFile, $opts);
    $self->{MAKER_NOTE_POS} = $srcExifTool->{MAKER_NOTE_POS};
    # sort tags in reverse order so we get priority tag last
    my @tags = reverse sort keys %$info;
    my $tag;
    foreach $tag (@tags) {
        # don't try to set Warning's or Error's
        next if $tag =~ /^Warning\b/ or $tag =~ /^Error\b/;
        my ($val, @values);
        if (ref $info->{$tag} eq 'ARRAY') {
            @values = @{$info->{$tag}};
        } elsif (ref $info->{$tag} eq 'SCALAR') {
            @values = ( ${$info->{$tag}} );
        } else {
            @values = ( $info->{$tag} );
        }
        my $replace = 1;
        foreach $val (@values) {
            my @rtnVals = $self->SetNewValue($tag, $val, 'Replace', $replace);
            unless ($rtnVals[0]) {
                # delete this tag since we couldn't set it
                delete $info->{$tag};
                last;
            }
            $replace = 0;
        }
    }
    return $info;
}

#------------------------------------------------------------------------------
# Get new value(s) for tag
# Inputs: 0) ExifTool object reference, 1) tag key, tag name, or tagInfo hash ref
#         2) optional pointer to return new value hash reference (not part of public API)
#    or   0) new value hash reference (not part of public API)
# Returns: List of new Raw values (list may be empty if tag is being deleted)
sub GetNewValues($;$$)
{
    local $_;
    my $newValueHash;
    if (ref $_[0] eq 'HASH') {
        $newValueHash = shift;
    } else {
        my ($self, $tagInfo, $newValueHashPt) = @_;
        if ($self->{NEW_VALUE}) {
            unless (ref $tagInfo) {
                my @tagInfoList = FindTagInfo($tagInfo);
                # choose the one that we are creating
                foreach $tagInfo (@tagInfoList) {
                    next unless $newValueHash = $self->GetNewValueHash($tagInfo);
                    last if defined $newValueHash->{IsCreating};
                }
            } else {
                $newValueHash = $self->GetNewValueHash($tagInfo);
            }
        }
        # return new value hash if requested
        $newValueHashPt and $$newValueHashPt = $newValueHash;
    }
    if ($newValueHash and $newValueHash->{Value}) {
        # return our value(s)
        if (wantarray) {
            return @{$newValueHash->{Value}};
        } else {
            return $newValueHash->{Value}->[0];
        }
    }
    return () if wantarray;  # return empty list
    return undef;
}

#------------------------------------------------------------------------------
# set priority for group where new values are written
# Inputs: 0) ExifTool object reference,
#         1-N) group names (reset to default if no groups specified)
sub SetNewGroups($;@)
{
    local $_;
    my ($self, @groups) = @_;
    @groups or @groups = ('EXIF','GPS','IPTC','XMP','MakerNotes');
    my $count = @groups;
    my %priority;
    foreach (@groups) {
        $priority{lc($_)} = $count--;
    }
    $priority{file} = 10;       # 'File' group is always written (Comment)
    $priority{composite} = 10;  # 'Composite' group is always written
    # set write priority (higher # is higher priority)
    $self->{WRITE_PRIORITY} = \%priority;
    $self->{WRITE_GROUPS} = \@groups;
}

#------------------------------------------------------------------------------
# get priority group list for new values
# Inputs: 0) ExifTool object reference
# Returns: List of group names
sub GetNewGroups($)
{
    my $self = shift;
    return @{$self->{WRITE_GROUPS}};
}

#------------------------------------------------------------------------------
# Write information back to file
# Inputs: 0) ExifTool object reference,
#         1) input filename, file reference, or scalar reference
#         2) output filename, file reference, or scalar reference
# Returns: 1=file written OK, 2=file written but no changes made, 0=file write error
sub WriteInfo($$$)
{
    local $_;
    my ($self, $infile, $outfile) = @_;
    my ($fileType, @fileTypeList);
    my ($inRef, $outRef, $outPos);
    my $oldRaf = $self->{RAF};
    my $rtnVal = 1;

    # initialize member variables
    $self->Init();

    # set up input file
    if (ref $infile) {
        $inRef = $infile;
        # make sure we are at the start of the file
        seek($inRef, 0, 0) if ref($inRef) eq 'GLOB';
    } else {
        unless (open(EXIFTOOL_FILE2,$infile)) {
            $self->Warn("Error opening file $infile");
            return 0;
        }
        $self->{OPTIONS}->{Verbose} and print "Rewriting $infile...\n";
        $inRef = \*EXIFTOOL_FILE2;
        $fileType = GetFileType($infile);
    }
    if ($fileType) {
        @fileTypeList = ($fileType);
    } else {
        @fileTypeList = @fileTypes;
    }
    # set up output file
    if (ref $outfile) {
        $outRef = $outfile;
        if (ref $outRef eq 'GLOB') {
            binmode($outRef);
            $outPos = tell($outRef);
        } else {
            # initialize our output buffer if necessary
            defined $$outRef or $$outRef = '';
            $outPos = length($$outRef);
        }
    } else {
        if (-e $outfile) {
            $self->Warn("File already exists: $outfile");
            $rtnVal = 0;
        } elsif (open(EXIFTOOL_OUTFILE, ">$outfile")) {
            $outRef = \*EXIFTOOL_OUTFILE;
            binmode($outRef);
            $outPos = 0;
        } else {
            $self->Warn("Error creating file: $outfile");
            $rtnVal = 0;
        }
    }
    if ($rtnVal) {
        # create random access file object
        # (note: disable buffering for a normal file -- $infile ne '-')
        my $isRandom = (ref $infile or $infile eq '-') ? 0 : 1;
        my $raf = new File::RandomAccess($inRef, $isRandom);
     #   $raf->Debug();
        my $inPos = $raf->Tell();
        $raf->BinMode();
        $self->{RAF} = $raf;
        for (;;) {
            my $type = shift @fileTypeList;
            # save file type in member variable
            $self->{FILE_TYPE} = $fileType;
            # determine which directories we must write for this file type
            $self->InitWriteDirs($type);
            if ($type eq 'JPEG') {
                $rtnVal = $self->WriteJPEG($outRef);
            } elsif ($type eq 'TIFF') {
                $rtnVal = $self->TiffInfo($type, $raf, 0, $outRef);
            } elsif ($type eq 'GIF') {
                $rtnVal = $self->GifInfo($outRef);
            } elsif ($type eq 'CRW') {
                # must be sure we have loaded CanonRaw before we can call CrwInfo()
                GetTagTable('Image::ExifTool::CanonRaw::Main');
                $rtnVal = Image::ExifTool::CanonRaw::WriteCRW($self, $outRef);
            } else {
                $rtnVal = 0;
            }
            # all done unless we got the wrong type
            last if $rtnVal;
            last unless @fileTypeList;
            # seek back to original position in files for next try
            unless ($raf->Seek($inPos, 0)) {
                $self->Warn('Error seeking in file');
                last;
            }
            if (ref $outRef eq 'GLOB') {
                seek($outRef, 0, $outPos);
            } else {
                $$outRef = substr($$outRef, 0, $outPos);
            }
        }
        # print file format errors
        unless ($rtnVal) {
            if ($fileType and $fileType =~ /^(JPEG|GIF|TIFF|CRW)$/) {
                unless ($self->{PRINT_CONV}->{Error}) {
                    $self->Error("Format error in file");
                }
            } elsif ($fileType) {
                $self->Error("ExifTool does not yet support writing of $fileType files");
            } else {
                $self->Error('ExifTool does not support writing of this type of file');
            }
        }
       # $raf->Close(); # only used to force debug output
    }
    # close input file file if we opened it
    close($inRef) if $inRef and $inRef ne $infile;

    # did we create the output file?
    if ($outRef and $outRef ne $outfile) {
        # close file and set $rtnVal to -1 if there was an error
        $rtnVal and $rtnVal = -1 unless close($outRef);
        # erase the output file unless we were successful
        $rtnVal <= 0 and unlink $outfile;
    }
    # if $rtnVal<0 there was a write error
    if ($rtnVal < 0) {
        $self->Warn('Error writing output file');
        $rtnVal = 0;    # return 0 on failure
    } elsif ($rtnVal > 0) {
        ++$rtnVal unless $self->{CHANGED};
    }
    # set things back to the way they were
    delete $self->{CHANGED};
    $self->{RAF} = $oldRaf;

    return $rtnVal;
}

#------------------------------------------------------------------------------
# Get list of all available tags
# Returns: tag list (sorted alphabetically)
sub GetAllTags()
{
    local $_;
    my %allTags;

    LoadAllTables();    # first load all our tables

    my @tableNames = ( keys %allTables );

    # loop through all tables and save tag names to %allTags hash
    while (@tableNames) {
        my $table = GetTagTable(pop @tableNames);
        my $tagID;
        foreach $tagID (TagTableKeys($table)) {
            my @infoArray = GetTagInfoList($table,$tagID);
            my $tagInfo;
            foreach $tagInfo (@infoArray) {
                my $tag = $$tagInfo{Name} || die "no name for tag!\n";
                $allTags{$tag} = 1;
            }
        }
    }
    return sort keys %allTags;
}

#------------------------------------------------------------------------------
# Get list of all writable tags
# Returns: tag list (sorted alphbetically)
sub GetWritableTags()
{
    local $_;
    my %writableTags;
    LoadAllTables();

    my @tableNames = keys %allTables;
    while (@tableNames) {
        my $tableName = pop @tableNames;
        my $table = GetTagTable($tableName);
        # attempt to load Write tables if autoloaded
        my @path = split(/::/,$tableName);
        if (@path > 3) {
            my $i = $#path - 1;
            $path[$i] = "Write$path[$i]";   # add 'Write' before class name
            my $module = join('::',@path[0..($#path-1)]);
            eval "require $module"; # (fails silently if nothing loaded)
        }
        my $tagID;
        foreach $tagID (TagTableKeys($table)) {
            my @infoArray = GetTagInfoList($table,$tagID);
            my $tagInfo;
            foreach $tagInfo (@infoArray) {
                my $tag = $$tagInfo{Name} || die "no name for tag!\n";
                next unless $$table{WRITABLE} or $$tagInfo{Writable};
                $writableTags{$tag} = 1;
            }
        }
    }
    return sort keys %writableTags;
}

#------------------------------------------------------------------------------
# Get list of all group names
# Inputs: 1) Group family number
# Returns: List of group names (sorted alphabetically)
sub GetAllGroups($)
{
    local $_;
    my $family = shift || 0;

    LoadAllTables();    # first load all our tables

    my @tableNames = ( keys %allTables );

    # loop through all tag tables and get all group names
    my %allGroups;
    while (@tableNames) {
        my $table = GetTagTable(pop @tableNames);
        my $defaultGroup;
        $defaultGroup = $table->{GROUPS}->{$family} if $table->{GROUPS};
        $allGroups{$defaultGroup} = 1 if defined $defaultGroup;
        foreach (TagTableKeys($table)) {
            my @infoArray = GetTagInfoList($table,$_);
            my ($tagInfo, $groups, $group);
            foreach $tagInfo (@infoArray) {
                if ($groups = $$tagInfo{Groups} and $group = $$groups{$family}) {
                    $allGroups{$group} = 1;
                }
            }
        }
    }
    return sort keys %allGroups;
}

#==============================================================================
# Functions below this are not part of the public API

#------------------------------------------------------------------------------
# Return true if we are deleting or overwriting the specified tag
# Inputs: 0) new value hash reference
#         2) optional tag value if deleting specific values
# Returns: >0 - tag should be deleted
#          =0 - the tag should be preserved
#          <0 - not sure, we need the value to know
sub IsOverwriting($;$)
{
    my ($newValueHash, $value) = @_;
    return 0 unless $newValueHash;
    # overwrite regardless if no DelValues specified
    return 1 unless $newValueHash->{DelValue};
    # never overwrite if DelValue list exists but is empty
    return 0 unless @{$newValueHash->{DelValue}};
    # return "don't know" if we don't have a value to test
    return -1 unless defined $value;
    # return a positive number if value matches a DelValue
    return scalar (grep /^$value$/, @{$newValueHash->{DelValue}});
}

#------------------------------------------------------------------------------
# Return true if we are creating the specified tag even if it didn't exist before
# Inputs: 0) new value hash reference
# Returns: true if we should add the tag
sub IsCreating($)
{
    return $_[0]->{IsCreating};
}

#------------------------------------------------------------------------------
# Get write group for specified tag
# Inputs: 0) new value hash reference
# Returns: Write group name
sub GetWriteGroup($)
{
    return $_[0]->{WriteGroup};
}

#------------------------------------------------------------------------------
# Get new value hash for specified tagInfo/writeGroup
# Inputs: 0) ExifTool object reference, 1) reference to tag info hash
#         2) Write group name, 3) Options: 'delete' or 'create'
# Returns: new value hash reference for specified write group
#          (or first new value hash in linked list if write group not specified)
sub GetNewValueHash($$;$$)
{
    my ($exifTool, $tagInfo, $writeGroup, $opts) = @_;
    $writeGroup = '' unless defined $writeGroup;
    $opts = '' unless defined $opts;
    my $newValueHash = $exifTool->{NEW_VALUE}->{$tagInfo};
    if (not defined $newValueHash) {
        if ($opts eq 'create') {
            $newValueHash = $exifTool->{NEW_VALUE}->{$tagInfo} = {
                TagInfo => $tagInfo,
                WriteGroup => $writeGroup,
            };
        }
    } elsif ($writeGroup and $newValueHash->{WriteGroup} ne $writeGroup) {
        # loop through all hashes in this linked list, looking for our writegroup
        for (;;) {
            my $lastHash = $newValueHash;
            $newValueHash = $lastHash->{Next};
            if (not defined $newValueHash) {
                if ($opts eq 'create') {
                    # didn't find match in list, so create a new entry
                    $newValueHash = {
                        TagInfo => $tagInfo,
                        WriteGroup => $writeGroup,
                    };
                    # insert in linked list
                    $lastHash->{Next} = $newValueHash;
                } else {
                    undef $newValueHash;
                }
                last;
            }
            last if $newValueHash->{WriteGroup} eq $writeGroup;
        }
    }
    if (defined $newValueHash and $opts eq 'delete') {
        my $firstHash = $exifTool->{NEW_VALUE}->{$tagInfo};
        if ($newValueHash eq $firstHash) {
            # remove first entry from linked list
            if ($newValueHash->{Next}) {
                $exifTool->{NEW_VALUE}->{$tagInfo} = $newValueHash->{Next};
            } else {
                delete $exifTool->{NEW_VALUE}->{$tagInfo};
            }
        } else {
            # find the list element pointing to this hash
            $firstHash = $firstHash->{Next} while $firstHash->{Next} ne $newValueHash;
            # remove from linked list
            $firstHash->{Next} = $newValueHash->{Next};
        }
        undef $newValueHash;
    }
    return $newValueHash;
}

#------------------------------------------------------------------------------
# Load all tag tables
sub LoadAllTables()
{
    unless ($loadedAllTables) {
        # load all of our non-referenced tables (Exif table first)
        GetTagTable('Image::ExifTool::Exif::Main');
        GetTagTable('Image::ExifTool::CanonRaw::Main');
        GetTagTable('Image::ExifTool::Photoshop::Main');
        GetTagTable('Image::ExifTool::GeoTiff::Main');
        GetTagTable('Image::ExifTool::Jpeg2000::Main');
        GetTagTable('Image::ExifTool::extraTags');
        GetTagTable('Image::ExifTool::compositeTags');
        # recursively load all tables referenced by the current tables
        my @tableNames = ( keys %allTables );
        while (@tableNames) {
            my $table = GetTagTable(pop @tableNames);
            # recursively scan through tables in subdirectories
            foreach (TagTableKeys($table)) {
                my @infoArray = GetTagInfoList($table,$_);
                my $tagInfo;
                foreach $tagInfo (@infoArray) {
                    my $subdir = $$tagInfo{SubDirectory} or next;
                    my $tableName = $$subdir{TagTable} or next;
                    next if $allTables{$tableName}; # next if table already loaded
                    push @tableNames, $tableName;   # must scan this one too
                }
            }
        }
        $loadedAllTables = 1;
    }
}

#------------------------------------------------------------------------------
# Get list of tagInfo hashes for all new data
# Inputs: 0) ExifTool object reference, 1) optional tag table pointer
# Returns: list of tagInfo hashes
sub GetNewTagInfoList($;$)
{
    my ($self, $tagTablePtr) = @_;
    my @tagInfoList;
    if ($self->{NEW_VALUE}) {
        my $hashKey;
        foreach $hashKey (keys %{$self->{NEW_VALUE}}) {
            my $tagInfo = $self->{NEW_VALUE}->{$hashKey}->{TagInfo};
            next if $tagTablePtr and $tagTablePtr ne $tagInfo->{Table};
            push @tagInfoList, $tagInfo;
        }
    }
    return @tagInfoList;
}

#------------------------------------------------------------------------------
# Get hash of tagInfo references keyed on tagID for a specific table
# Inputs: 0) ExifTool object reference, 1) tag table pointer
# Returns: hash reference
sub GetNewTagInfoHash($$)
{
    my ($self, $tagTablePtr) = @_;
    my %tagInfoHash;
    if ($self->{NEW_VALUE}) {
        my $hashKey;
        GenerateTagIDs($tagTablePtr);  # make sure IDs are generated
        foreach $hashKey (keys %{$self->{NEW_VALUE}}) {
            my $tagInfo = $self->{NEW_VALUE}->{$hashKey}->{TagInfo};
            next if $tagTablePtr and $tagTablePtr ne $tagInfo->{Table};
            $tagInfoHash{$$tagInfo{TagID}} = $tagInfo;
        }
    }
    return \%tagInfoHash;
}

#------------------------------------------------------------------------------
# Get a tagInfo/tagID hash for subdirectories we need to add
# Inputs: 0) ExifTool object reference, 1) parent tag table reference
#         2) parent directory name (taken from GROUP0 of tag table if not defined)
# Returns: Reference to Hash of subdirectory tagInfo references keyed by tagID
#          (plus Reference to edit directory hash in list context)
sub GetAddDirHash($$;$)
{
    my ($self, $tagTablePtr, $parent) = @_;
    $parent or $parent = $tagTablePtr->{GROUPS}->{0};
    my $tagID;
    my %addDirHash;
    my %editDirHash;
    my $addDirs = $self->{ADD_DIRS};
    my $editDirs = $self->{EDIT_DIRS};
    foreach $tagID (TagTableKeys($tagTablePtr)) {
        my @infoArray = GetTagInfoList($tagTablePtr,$tagID);
        my $tagInfo;
        foreach $tagInfo (@infoArray) {
            next unless $$tagInfo{SubDirectory};
            # get name for this sub directory
            # (take directory name from SubDirectory DirName if it exists,
            #  otherwise Group0 name of SubDirectory TagTable or tag Group1 name)
            my $dirName = $tagInfo->{SubDirectory}->{DirName};
            unless ($dirName) {
                my $subTable = Image::ExifTool::GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                if ($subTable) {
                    $dirName = $subTable->{GROUPS}->{0};
                } else {
                    $dirName = $tagInfo->{Groups}->{1};
                }
                # set directory name for next time
                $tagInfo->{SubDirectory}->{DirName} = $dirName;
            }
            # save this directory information if we are writing it
            if ($$editDirs{$dirName} and $$editDirs{$dirName} eq $parent) {
                $editDirHash{$tagID} = $tagInfo;
                $addDirHash{$tagID} = $tagInfo if $$addDirs{$dirName};
            }
        }
    }
    if (wantarray) {
        return (\%addDirHash, \%editDirHash);
    } else {
        return \%addDirHash;
    }
}

#------------------------------------------------------------------------------
# initialize ADD_DIRS and EDIT_DIRS hashes for all directories that need
# need to be created or will have tags changed in them
# Inputs: 0) ExifTool object reference, 1) File type string
sub InitWriteDirs($$)
{
    my ($self, $fileType) = @_;
    my $editDirs = $self->{EDIT_DIRS} = { };
    my $addDirs = $self->{ADD_DIRS} = { };
    my $fileDirs = $dirMap{$fileType} or return;
    my @tagInfoList = $self->GetNewTagInfoList();
    my $tagInfo;
    for $tagInfo (@tagInfoList) {
        my $newValueHash = $self->GetNewValueHash($tagInfo);
        for (;;) {
            # are we creating this tag? (otherwise just deleting or editing it)
            my $isCreating = $newValueHash->{IsCreating};
            # tag belongs to directory specified by WriteGroup, or by
            # the Group0 name if WriteGroup not defined
            my $dirName = $newValueHash->{WriteGroup};
            while ($dirName) {
                my $parent = $$fileDirs{$dirName};
                $$editDirs{$dirName} = $parent;
                $$addDirs{$dirName} = $parent if $isCreating;
                $dirName = $parent;     # go up one level
            }
            last unless $newValueHash->{Next};
            # cycle through all hashes in linked list
            $newValueHash = $newValueHash->{Next};
        }
    }
    if ($self->{OPTIONS}->{Verbose}) {
        print "  Editing tags in: ";
        foreach (sort keys %$editDirs) { print "$_ "; }
        print "\n";
        return unless $self->{OPTIONS}->{Verbose} > 1;
        print "  Creating tags in: ";
        foreach (sort keys %$addDirs) { print "$_ "; }
        print "\n";
    }
}

#------------------------------------------------------------------------------
# Write tags from specified tag table
# Inputs: 0) ExifTool object reference
#         1) tag table reference
#         2) optional source directory information reference
#         3) optional reference to writing procedure
# Returns: New directory data or undefined on error
sub WriteTagTable($$;$$)
{
    my ($self, $tagTablePtr, $dirInfo, $writeProc) = @_;

    $tagTablePtr or return undef;
    my $verbose = $self->{OPTIONS}->{Verbose};
    # use default proc from tag table if no proc specified
    $writeProc or $writeProc = $$tagTablePtr{WRITE_PROC} or return undef;
    # set directory name from default group0 name if not done already
    $dirInfo->{DirName} or $dirInfo->{DirName} = $tagTablePtr->{GROUPS}->{0};
    # be sure the tag ID's are generated, because the write proc will need them
    GenerateTagIDs($tagTablePtr);
    my $oldDir = $self->{DIR_NAME};
    if ($verbose and (not defined $oldDir or $oldDir ne $dirInfo->{DirName})) {
        print '  ', ($dirInfo->{DataPt} ? 'Rewriting' : 'Creating'), " $$dirInfo{DirName}\n";
    }
    $self->{DIR_NAME} = $dirInfo->{DirName};
    my $newData = &$writeProc($self, $tagTablePtr, $dirInfo);
    $self->{DIR_NAME} = $oldDir;
    if ($verbose and defined $newData and not length $newData) {
        print "  Deleting $$dirInfo{DirName}\n";
    }
    return $newData;
}

#------------------------------------------------------------------------------
# Uncommon (and bulky) utility routines to for reading binary data values
# Inputs: 0) data reference, 1) offset into data
sub Get64s($$)
{
    my ($dataPt, $pos) = @_;
    my ($a, $b);
    # must preserve sign bit of high-order word
    if (GetByteOrder() eq 'II') {
        $a = Get32s($dataPt, $pos + 4);
        $b = Get32u($dataPt, $pos);
    } else {
        $a = Get32s($dataPt, $pos);
        $b = Get32u($dataPt, $pos + 4);
    }
    return $a * 4294967296.0 + $b;
}
sub Get64u($$)
{
    my ($dataPt, $pos) = @_;
    my ($a, $b);
    # high word comes second for Intel byte ordering
    if (GetByteOrder() eq 'II') {
        $a = Get32u($dataPt, $pos + 4);
        $b = Get32u($dataPt, $pos);
    } else {
        $a = Get32u($dataPt, $pos);
        $b = Get32u($dataPt, $pos + 4);
    }
    return $a * 4294967296.0 + $b;
}

#------------------------------------------------------------------------------
# Dump data in hex and ASCII to console
# Inputs: 0) data reference, 1) length or undef, 2-N) Options:
# Options: Start => offset to start of data (default=0)
#          Addr => address to print for data start (default=Start)
#          Width => width of printout (bytes, default=16)
#          Prefix => prefix to print at start of line (default='')
#          MaxLen => maximum length to dump
sub HexDump($;$%)
{
    my $dataPt = shift;
    my $len    = shift;
    my %opts   = @_;
    my $start  = $opts{Start}  || 0;
    my $addr   = $opts{Addr}   || $start;
    my $wid    = $opts{Width}  || 16;
    my $prefix = $opts{Prefix} || '';
    my $maxLen = $opts{MaxLen};
    my $datLen = length($$dataPt) - $start;
    my $more;

    if (not defined $len) {
        $len = $datLen;
    } elsif ($len > $datLen) {
        print "$prefix    Warning: Attempted dump outside data\n";
        print "$prefix    ($len bytes specified, but only $datLen available)\n";
        $len = $datLen;
    }
    if ($maxLen and $len > $maxLen) {
        # print one line less to allow for $more line below
        $maxLen = int(($maxLen - 1) / $wid) * $wid;
        $more = $len - $maxLen;
        $len = $maxLen;
    }
    my $format = sprintf("%%-%ds", $wid * 3);
    my $i;
    for ($i=0; $i<$len; $i+=$wid) {
        $wid > $len-$i and $wid = $len-$i;
        printf "$prefix%8.4x: ", $addr+$i;
        my $dat = substr($$dataPt, $i+$start, $wid);
        printf $format, join(' ',unpack("H*",$dat) =~ /../g);
        $dat =~ tr /\x00-\x1f\x7f-\xff/./;
        print "[$dat]\n";
    }
    $more and printf "$prefix    [snip $more bytes]\n";
}

#------------------------------------------------------------------------------
# Print verbose tag information
# Inputs: 0) ExifTool object reference, 1) tag ID
#         2) tag info reference (or undef)
#         3-N) extra parms:
# Parms: Index => Index of tag in menu (starting at 0)
#        Value => Tag value
#        DataPt => reference to value data block
#        Size => length of value data within block
#        Format => value format string
#        Count => number of values
#        Extra => Extra Verbose=2 information to put after tag number
#        Table => Reference to tag table
#        --> plus any of these HexDump() options: Start, Addr, Width
sub VerboseInfo($$$%)
{
    my ($self, $tagID, $tagInfo, %parms) = @_;
    my $verbose = $self->{OPTIONS}->{Verbose};
    my ($tag, $tagDesc, $line, $hexID);

    # generate hex number if tagID is numerical
    $tagID =~ /^\d+$/ and $hexID = sprintf("0x%.4x", $tagID) if defined $tagID;
    # get tag name
    if ($tagInfo and $$tagInfo{Name}) {
        $tag = $$tagInfo{Name};
    } else {
        my $prefix;
        $prefix = $parms{Table}->{TAG_PREFIX} if $parms{Table};
        $prefix = 'Unknown' unless $prefix;
        $tag = $prefix . '_' . ($hexID ? $hexID : $tagID);
    }
    my $dataPt = $parms{DataPt};
    my $size = $parms{Size};
    $size or ($dataPt and $size = length $$dataPt);
    my $indent = $self->{INDENT};

    # Level 1: print tag/value information
    $line = $indent;
    my $index = $parms{Index};
    if (defined $index) {
        $line .= $index . ') ';
        $line .= ' ' if $index < 10;
        $indent .= '    '; # indent everything else to align with tag name
    }
    $line .= $tag;
    if ($tagInfo and $$tagInfo{SubDirectory}) {
        $line .= ' (SubDirectory) -->';
    } elsif (defined $parms{Value}) {
        $line .= ' = ' . $self->Printable($parms{Value});
    } elsif ($dataPt) {
        my $start = $parms{Start} || 0;
        $line .= ' = ' . $self->Printable(substr($$dataPt,$start,$size));
    }
    print "$line\n";

    # Level 2: print detailed information about the tag
    if ($verbose > 1 and defined $tagID) {
        $line = $indent;
        $line .= '- Tag ' . ($hexID ? $hexID : "'$tagID'");
        $line .= $parms{Extra} if defined $parms{Extra};
        my $format = $parms{Format};
        if ($format or $size) {
            $line .= ' (';
            if ($size) {
                $line .= "$size bytes";
                $line .= ', ' if $format;
            }
            if ($format) {
                $line .= $format;
                $line .= '['.$parms{Count}.']' if $parms{Count};
            }
            $line .= ')';
        }
        $line .= ':' if $verbose > 2 and $parms{DataPt};
        print "$line\n";
    }

    # Level 3: do hex dump of value
    if ($verbose > 2 and $parms{DataPt}) {
        $parms{Prefix} = $indent;
        # limit dump length unless verbose > 3
        $parms{MaxLen} = 96 unless $verbose > 3;
        HexDump($dataPt, $size, %parms);
    }
}

#------------------------------------------------------------------------------
# Print verbose directory information
# Inputs: 0) ExifTool object reference, 1) directory name
#         2) number of entries in directory (or 0 if unknown)
#         3) optional size of directory in bytes
sub VerboseDir($$;$)
{
    my ($self, $name, $entries, $size) = @_;
    my $indent = substr($self->{INDENT}, 0, -2);
    my $str;
    if ($entries) {
        $str = " with $entries entries";
    } elsif ($size) {
        $str = ", $size bytes";
    } else {
        $str = '';
    }
    print "$indent+ [$name directory$str]\n";
}

#------------------------------------------------------------------------------
# assemble a continuing fraction into a rational value
# Inputs: 0) numerator, 1) denominator
#         2-N) list of fraction denominators, deepest first
sub AssembleRational($$@)
{
    @_ < 3 and return @_;
    my ($num, $denom, $frac) = splice(@_, 0, 3);
    return AssembleRational($frac*$num+$denom, $num, @_);
}
    
#------------------------------------------------------------------------------
# convert a floating point number into a rational
# Inputs: 0) floating point number, 1) optional maximum value (defaults to 0x7fffffff)
# Returns: numberator, denominator (in list context)
# Notes: these routines were a bit tricky, but fun to write!
sub Rationalize($;$)
{
    my ($val, $maxInt) = @_;
    # Note: Just testing "if $val" doesn't work because '0.0' is true!  (ugghh!)
    return (0, 1) if $val == 0;
    my $sign = $val < 0 ? ($val = -$val, -1) : 1;
    my ($num, $denom, @fracs);
    my $frac = $val;
    $maxInt or $maxInt = 0x7fffffff;
    for (;;) {
        my ($n, $d) = AssembleRational(int($frac + 0.5), 1, @fracs);
        if ($n > $maxInt or $d > $maxInt) {
            last if defined $num;
            return ($sign, $maxInt) if $val < 1;
            return ($sign * $maxInt, 1);
        }
        ($num, $denom) = ($n, $d);      # save last good values
        my $err = ($n/$d-$val) / $val;  # get error of this rational
        last if abs($err) < 1e-8;       # all done if error is small
        my $int = int($frac);
        unshift @fracs, $int;
        last unless $frac -= $int;
        $frac = 1 / $frac;
    }
    return ($num * $sign, $denom);
}

#------------------------------------------------------------------------------
# Utility routines to for writing binary data values
sub Set16s($;$$)
{
    my $val = shift;
    $val < 0 and $val += 0x10000;
    return Set16u($val, @_);
}
sub Set32s($;$$)
{
    my $val = shift;
    $val < 0 and $val += 0xffffffff, ++$val;
    return Set32u($val, @_);
}
sub SetRational32u($;$$) {
    my ($numer,$denom) = Rationalize($_[0],0xffffffff);
    my $val = Set32u($numer) . Set32u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational32s($;$$) {
    my ($numer,$denom) = Rationalize($_[0]);
    my $val = Set32s($numer) . Set32u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational16u($;$$) {
    my ($numer,$denom) = Rationalize($_[0],0xffff);
    my $val = Set16u($numer) . Set16u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational16s($;$$) {
    my ($numer,$denom) = Rationalize($_[0],0xffff);
    my $val = Set16s($numer) . Set16u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetFloat($;$$) {
    return SwapBytes(pack('f',$_[0]), 4);
}
#------------------------------------------------------------------------------
# hash lookups for writing binary data values
my %writeValueProc = (
    int8s => \&Set8s,
    int8u => \&Set8u,
    int16s => \&Set16s,
    int16u => \&Set16u,
    int32s => \&Set32s,
    int32u => \&Set32u,
    rational16s => \&SetRational16s,
    rational16u => \&SetRational16u,
    rational32s => \&SetRational32s,
    rational32u => \&SetRational32u,
    float => \&SetFloat,
);
#------------------------------------------------------------------------------
# write binary data value (with current byte ordering)
# Inputs: 0) value, 1) format string
#         2) optional number of values (1 or string length if not specified)
#         3) optional data reference, 4) value offset
# Returns: packed value (and sets value in data) or undef on error
sub WriteValue($$;$$$$)
{
    my ($val, $format, $count, $dataPt, $offset) = @_;
    my $proc = $writeValueProc{$format};
    my $packed;

    if ($proc) {
        my @vals = split(' ',$val);
        $count or $count = 1;   # assume 1 if count not specified
        $packed = '';
        while ($count--) {
            $val = shift @vals;
            #warn...
            return undef unless defined $val;
            # validate numerical formats
            if ($format =~ /^int/) {
                return undef unless Image::ExifTool::IsInt($val);
            } else {
                return undef unless Image::ExifTool::IsFloat($val);
            }
            $packed .= &$proc($val);
        }
    } elsif ($format eq 'string' or $format eq 'undef') {
        $format eq 'string' and $val .= "\0";   # null-terminate strings
        if (defined $count) {
            my $diff = $count - length($val);
            if ($diff) {
                #warn "wrong string length!\n";
                # adjust length of string to match specified count
                if ($diff < 0) {
                    if ($format eq 'string') {
                        return undef unless $count;
                        $val = substr($val, 0, $count - 1) . "\0";
                    } else {
                        $val = substr($val, 0, $count);
                    }
                } else {
                    $val .= "\0" x $diff;
                }
            }
        } else {
            $count = length($val);
        }
        $dataPt and substr($$dataPt, $offset, $count) = $val;
        return $val;
    } else {
        warn "Can't currently write format $format";
        return undef;
    }
    $dataPt and substr($$dataPt, $offset, length($packed)) = $packed;
    return $packed;
}

#------------------------------------------------------------------------------
# write to file or memory
# Inputs: 0) file or scalar reference, 1-N) list of stuff to write
# Returns: true on success
sub Write($@)
{
    my $outfile = shift;
    if (ref $outfile eq 'GLOB') {
        return print $outfile @_;
    } elsif (ref $outfile eq 'SCALAR') {
        $$outfile .= join('', @_);
        return 1;
    }
    return 0;
}

#------------------------------------------------------------------------------
# Write segment, splitting up into multiple segments if necessary
# Inputs: 0) file or scalar reference, 1) segment marker
#         2) segment header, 3) segment data
# Returns: number of segments written, or 0 on error
sub WriteMultiSegment($$$$)
{
    my $outfile = shift;
    my $marker = shift;
    my $header = shift;
    my $hdr = "\xff" . chr($marker);
    my $count = 0;
    my $len = length($_[0]);
    my $maxLen = $maxSegmentLen - length($header);
    my $n;
    # write data, splitting into multiple segments if necessary
    # (each segment gets its own header)
    for ($n=0; $n<$len; $n+=$maxLen) {
        my $size = $len - $n;
        $size > $maxLen and $size = $maxLen;
        my $buff = substr($_[0],$n,$size);
        $size += length($header);
        # write the new segment with appropriate header
        my $segHdr = $hdr . pack('n', $size + 2);
        Write($outfile, $segHdr, $header, $buff) or return 0;
        ++$count;
    }
    return $count;
}

#------------------------------------------------------------------------------
# WriteJPEG : Write JPEG image
# Inputs: 0) ExifTool object reference, 1) output file or scalar reference
# Returns: 1 on success, 0 if this wasn't a valid JPEG file, or -1 if
#          an output file was specified and a write error occurred
sub WriteJPEG($$)
{
    my ($self, $outfile) = @_;
    my ($ch,$s,$length);
    my $verbose = $self->{OPTIONS}->{Verbose};
    my $raf = $self->{RAF};
    my $rtnVal = 0;
    my %doneDir;
    my ($err, %dumpParms);

    # check to be sure this is a valid JPG file
    return 0 unless $raf->Read($s,2) == 2 and $s eq "\xff\xd8";
    $dumpParms{MaxLen} = 128 unless $verbose > 3;

    Write($outfile, $s) or $err = 1;
    # figure out what segments we need to write for the tags we have set
    my $addDirs = $self->{ADD_DIRS};
    my $editDirs = $self->{EDIT_DIRS};

    # set input record separator to 0xff (the JPEG marker) to make reading quicker
    my $oldsep = $/;
    $/ = "\xff";

    my ($nextJunk, $nextMarker, $nextSegDataPt, $nextSegPos, $combinedSegData);
    # read through each segment in the JPEG file
    Marker: for (;;) {

        # set marker and data pointer for current segment
        my $marker = $nextMarker;
        my $segDataPt = $nextSegDataPt;
        my $segPos = $nextSegPos;
        # write out any junk that comes before current segment
        if (defined $nextJunk) {
            Write($outfile, $nextJunk) or $err = 1 if length $nextJunk;
            undef $nextJunk;
        }
        undef $nextMarker;
        undef $nextSegDataPt;
#
# read ahead to the next segment unless we have reached SOS
#
        unless ($marker and $marker == 0xda) {
            # read up to next marker (JPEG markers begin with 0xff)
            $raf->ReadLine($nextJunk) or last;
            # JPEG markers can be padded with unlimited 0xff's
            for (;;) {
                $raf->Read($ch, 1) or last Marker;
                $nextMarker = ord($ch);
                last unless $nextMarker == 0xff;
            }
            # remove the 0xff but keep the rest of the junk up to this point
            chomp($nextJunk);
            # read the next segment
            my $nextBuff;
            # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
            if (($nextMarker & 0xf0) == 0xc0 and
                ($nextMarker == 0xc0 or $nextMarker & 0x03))
            {
                last unless $raf->Read($nextBuff, 7) == 7;
                $nextSegDataPt = \$nextBuff;
            # read data for all markers except 0xda (SOS) and stand-alone
            # markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
            } elsif ($nextMarker!=0xda and $nextMarker!=0x00 and $nextMarker!=0x01 and
                    ($nextMarker<0xd0 or $nextMarker>0xd7))
            {
                # read record length word
                last unless $raf->Read($s, 2) == 2;
                my $len = unpack('n',$s);   # get data length
                last unless defined($len) and $len >= 2;
                $nextSegPos = $raf->Tell();
                $len -= 2;  # subtract size of length word
                last unless $raf->Read($nextBuff, $len) == $len;
                $nextSegDataPt = \$nextBuff;    # set pointer to our next data
            }
            # read second segment too if this was the first
            next unless defined $marker;
        }
        # set some useful variables for the current segment
        my $hdr = "\xff" . chr($marker);    # header for this segment
        my $markerName = JpegMarkerName($marker);
#
# create all segments that must come before this marker
# (nothing comes before SOI)
#
        while ($markerName ne 'SOI') {
            # likewise, we don't create anything before APP0 or APP1
            last if $markerName eq 'APP0' or $markerName eq 'APP1';
            # peek ahead and see if someone put a segment before the
            # JFIF APP0 or EXIF APP1 segment (contrary to the EXIF specs)
            if (defined $nextMarker) {
                my $nextName = JpegMarkerName($nextMarker);
                if ($nextName eq 'APP0' or $nextName eq 'APP1') {
                    $verbose and $self->Warn("JPEG $markerName found before $nextName");
                    last;
                }
            }
            # EXIF information must come immediately after APP0
            if ((exists $$addDirs{IFD0} and not $doneDir{IFD0}) or
                (exists $$addDirs{IFD1} and not $doneDir{IFD1}))
            {
                $doneDir{IFD0} = $doneDir{IFD1} = 1;
                $verbose and print "Creating APP1:\n";
                # write new EXIF data
                my $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
                SetByteOrder('MM');     # use good byte ordering ;)
                my %dirInfo = (
                    NewDataPos => 8,    # new data will come after TIFF header
                    Parent   => $markerName,
                    DirName  => 'IFD0',
                    Multi => 1,
                );
                my $buff = $self->WriteTagTable($tagTablePtr, \%dirInfo);
                if (defined $buff and length $buff) {
                    my $tiffHdr = 'MM' . Set16u(42) . Set32u(8); # standard TIFF header
                    my $size = length($buff) + length($tiffHdr) + length($exifAPP1hdr);
                    if ($size <= $maxSegmentLen) {
                        # write the new segment with appropriate header
                        my $app1hdr = "\xff\xe1" . pack('n', $size + 2);
                        Write($outfile, $app1hdr, $exifAPP1hdr, $tiffHdr, $buff) or $err = 1;
                    } else {
                        $self->Warn("EXIF APP1 segment too large! ($size bytes)");
                    }
                }
            }
            # put all the rest after all of the APP segments
            last if $markerName =~ /^APP/;
            # Photoshop APP13 segment next
            if (exists $$addDirs{Photoshop} and not $doneDir{Photoshop}) {
                $doneDir{Photoshop} = 1;
                $verbose and print "Creating APP13:\n";
                # write new Photoshop APP13 record to memory
                my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                my %dirInfo = (
                    Parent   => $markerName,
                );
                my $buff = $self->WriteTagTable($tagTablePtr, \%dirInfo);
                if (defined $buff and length $buff) {
                    my $num = WriteMultiSegment($outfile, 0xed, $psAPP13hdr, $buff);
                    $num or $err = 1;
                    ++$self->{CHANGED};
                }
            }
            # then XMP APP1 segment
            if (exists $$addDirs{XMP} and not $doneDir{XMP}) {
                $doneDir{XMP} = 1;
                $verbose and print "Creating APP1:\n";
                # write new XMP data
                my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                my %dirInfo = (
                    Parent   => $markerName,
                );
                my $buff = $self->WriteTagTable($tagTablePtr, \%dirInfo);
                if (defined $buff and length $buff) {
                    my $size = length($buff) + length($xmpAPP1hdr);
                    if ($size <= $maxSegmentLen) {
                        # write the new segment with appropriate header
                        my $app1hdr = "\xff\xe1" . pack('n', $size + 2);
                        Write($outfile, $app1hdr, $xmpAPP1hdr, $buff) or $err = 1;
                    } else {
                        $self->Warn("XMP APP1 segment too large! ($size bytes)");
                    }
                }
            }
            # then PreviewImage
            if (exists $$addDirs{APP5} and not $doneDir{APP5}) {
                $doneDir{APP5} = 1;
                # get new preview image
                my $buff = $self->GetNewValues('PreviewImage');
                if (defined $buff and length $buff) {
                    $verbose and print "Creating APP5:\n";
                    $verbose > 1 and print "    + PreviewImage\n";
                    my $num = WriteMultiSegment($outfile, 0xe5, $myAPP5hdr, $buff);
                    $num or $err = 1;
                    ++$self->{CHANGED};
                } else {
                    $self->Warn('PreviewImage not found!');
                }
            }
            # finally, COM segment
            while (exists $$editDirs{COM} and not $doneDir{COM}) {
                $doneDir{COM} = 1;
                my $tagInfo = $Image::ExifTool::extraTags{Comment};
                my $oldComment = $markerName eq 'COM' ? $$segDataPt : '';
                $oldComment =~ s/\0.*//;
                $markerName eq 'COM' and ($oldComment = $$segDataPt) =~ s/\0.*//;
                my $newValueHash = $self->GetNewValueHash($tagInfo);
                unless (IsOverwriting($newValueHash)) {
                    delete $$editDirs{COM}; # we aren't editing COM after all
                    last;
                }
                $verbose and print "Creating COM:\n";
                # write out the comments now:
                # need room for the comment, plus null terminator, plus size word (2 bytes)
                # and the total size must be less than 0xffff to fit in one record
                # so split up longer comments into multiple records
                my $newComment = GetNewValues($newValueHash);
                if (defined $newComment and length($newComment)) {
                    $verbose > 1 and print "    + Comment = '$newComment'\n";
                    my $len = length($newComment);
                    my $n;
                    for ($n=0; $n<$len; $n+=$maxSegmentLen-1) {
                        my $size = $len - $n;
                        $size >= $maxSegmentLen and $size = $maxSegmentLen - 1;
                        my $comHdr = "\xff\xfe" . pack('n', $size + 3);
                        my $str = substr($newComment,$n,$size);
                        Write($outfile, $comHdr, $str, "\0") or $err = 1;
                    }
                    ++$self->{CHANGED};
                }
                last;
            }
            last;   # didn't want to loop anyway
        }
#
# rewrite existing segments
#
        # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
        if (($marker & 0xf0) == 0xc0 and ($marker == 0xc0 or $marker & 0x03)) {
            $verbose and print "JPEG $markerName:\n";
            Write($outfile, $hdr, $$segDataPt) or $err = 1;
            next;
        } elsif ($marker == 0xda) {             # SOS
            $verbose and print "JPEG SOS (end of parsing)\n";
            # nothing interesting to parse after start of scan (SOS)
            # so just copy over the rest of the file
            Write($outfile, $hdr) or $err = 1;
            my $buff;
            while ($raf->Read($buff, 65536)) {
                Write($outfile, $buff) or $err = 1;
            }
            # success unless we had a file write error
            $rtnVal = 1;
            last;   # all done parsing file
        } elsif ($marker==0x00 or $marker==0x01 or ($marker>=0xd0 and $marker<=0xd7)) {
            $verbose and $marker and print "JPEG $markerName:\n";
            # handle stand-alone markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
            Write($outfile, $hdr) or $err = 1;
            next;
        }
        #
        # NOTE: A 'next' statement after this point will cause $$segDataPt
        #       not to be written if there is an output file, so in this case
        #       the $self->{CHANGED} flags must be updated
        #
        $length = length($$segDataPt);
        if ($verbose) {
            print "JPEG $markerName ($length bytes):\n";
            if ($verbose > 2 and $markerName =~ /^APP/) {
                HexDump($segDataPt, undef, %dumpParms);
            }
        }
        # set flag indicating we have done this segment
        $doneDir{$markerName} = 1;
        # rewrite this segment only if we are changing a tag which
        # is contained in its directory
        while (exists $$editDirs{$markerName}) {
            if ($marker == 0xe1) {              # APP1 (EXIF, XMP)
                # check for EXIF data
                if ($$segDataPt =~ /^$exifAPP1hdr/) {
                    if ($doneDir{IFD0}) {
                        # this file doesn't conform to the EXIF standard
                        $self->Error("JPEG segments are out of sequence");
                        # return format error since it would be bad to have
                        # duplicate EXIF segments in the file
                        return 0;
                    }
                    $doneDir{IFD0} = $doneDir{IFD1} = 1;
                    last unless $$editDirs{IFD0} or $$editDirs{IFD1};
                    # save the EXIF data block into a common variable
                    $self->{EXIF_DATA} = substr($$segDataPt, 6);
                    # write new EXIF data to memory
                    $$segDataPt = $exifAPP1hdr; # start with EXIF APP1 header
                    # rewrite as if this were a TIFF file in memory
                    # (EXIF information is in standard TIFF format)
                    my $result = $self->TiffInfo($markerName,undef,$segPos+6,$segDataPt);
                    unless ($result or $self->Options('IgnoreMinorErrors')) {
                        last Marker;    # abort if our EXIF had problems
                    }
                    # delete segment if IFD contains no entries
                    unless (length($$segDataPt) > length($exifAPP1hdr)) {
                        $verbose and print "Deleting APP1\n";
                        next Marker;
                    }
                # check for XMP data
                } elsif ($$segDataPt =~ /^$xmpAPP1hdr/) {
                    $doneDir{XMP} = 1;
                    last unless $$editDirs{XMP};
                    my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                    my %dirInfo = (
                        Base     => 0,
                        DataPt   => $segDataPt,
                        DataLen  => $length,
                        DirStart => length $xmpAPP1hdr,
                        DirLen   => $length - length($xmpAPP1hdr),
                        Nesting  => 0,
                        Parent   => $markerName,
                    );
                    my $newData = $self->WriteTagTable($tagTablePtr, \%dirInfo);
                    if (defined $newData) {
                        undef $$segDataPt;  # free the old buffer
                        # add header to new segment unless empty
                        $newData = $xmpAPP1hdr . $newData if length $newData;
                        $segDataPt = \$newData;
                    }
                    unless (length $$segDataPt) {
                        $verbose and print "Deleting APP1\n";
                        next Marker;
                    }
                }
            } elsif ($marker == 0xe2) {         # APP2 (ICC Profile)
                if ($$segDataPt =~ /ICC_PROFILE\0/) {
                    $doneDir{ICC_PROFILE} = 1;
                    # must concatinate blocks of profile
                    my $block_num = ord(substr($$segDataPt, 12, 1));
                    my $blocks_tot = ord(substr($$segDataPt, 13, 1));
                    $combinedSegData = '' if $block_num == 1;
                    if (defined $combinedSegData) {
                        $combinedSegData .= substr($$segDataPt, 14);
                        if ($block_num == $blocks_tot) {
                            my $tagTablePtr = GetTagTable('Image::ExifTool::ICC_Profile::Main');
                            my %dirInfo = (
                                DataPt   => \$combinedSegData,
                                DataLen  => length($combinedSegData),
                                DirStart => 0,
                                DirLen   => length($combinedSegData),
                                Nesting  => 0,
                                Parent   => $markerName,
                            );
                            # we don't support writing ICC_Profile (yet)
                            # $newData = $self->WriteTagTable($tagTablePtr, \%dirInfo);
                            undef $combinedSegData;
                        }
                    }
                }
            } elsif ($marker == 0xed) {         # APP13 (Photoshop)
                if ($$segDataPt =~ /^$psAPP13hdr/) {
                    # add this data to the combined data if it exists
                    if (defined $combinedSegData) {
                        $combinedSegData .= substr($$segDataPt,length($psAPP13hdr));
                        $segDataPt = \$combinedSegData;
                        $length = length $combinedSegData;  # update length
                    }
                    # peek ahead to see if the next segment is photoshop data too
                    if ($nextMarker == 0xed and $$nextSegDataPt =~ /^$psAPP13hdr/) {
                        # initialize combined data if necessary
                        $combinedSegData = $$segDataPt unless defined $combinedSegData;
                        next Marker;    # get the next segment to combine
                    }
                    $doneDir{Photoshop} = 1;
                    # process Photoshop APP13 record
                    my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                    my %dirInfo = (
                        DataPt   => $segDataPt,
                        DataLen  => $length,
                        DirStart => 14,     # directory starts after identifier
                        DirLen   => $length-14,
                        Nesting  => 0,
                        Parent   => $markerName,
                    );
                    my $newData = $self->WriteTagTable($tagTablePtr, \%dirInfo);
                    if (defined $newData) {
                        undef $$segDataPt;  # free the old buffer
                        $segDataPt = \$newData;
                    }
                    unless (length $$segDataPt) {
                        $verbose and print "Deleting APP13\n";
                        next Marker;
                    }
                    # write as multi-segment
                    WriteMultiSegment($outfile, $marker, $psAPP13hdr, $$segDataPt) or $err = 1;
                    undef $combinedSegData;
                    undef $$segDataPt;
                    next Marker;
                } elsif ($$segDataPt =~ /^\x1c\x02/) {
                    # this is written in IPTC format by photoshop, but is
                    # all messed up, so we ignore it
                } else {
                    $self->Warn('Unknown APP13 data');
                    $verbose > 2 and HexDump($segDataPt, undef, %dumpParms);
                }
            } elsif ($marker == 0xe5) {         # APP5 (PreviewImage)
                if ($$segDataPt =~ /^$myAPP5hdr/) {
                    $verbose > 1 and print "    - PreviewImage\n";
                    $verbose and print "Deleting APP5\n";
                    ++$self->{CHANGED};         # increment the changed flag
                    undef $segDataPt;   # don't write existing comment
                    # reset done flag since we may want to add preview later
                    delete $doneDir{$markerName};
                }
            } elsif ($marker == 0xfe) {         # COM (JPEG comment)
                $verbose > 2 and HexDump($segDataPt, undef, %dumpParms);
                $verbose > 1 and print "    - Comment = '$$segDataPt'\n";
                $verbose and print "Deleting COM\n";
                ++$self->{CHANGED};         # increment the changed flag
                undef $segDataPt;   # don't write existing comment
            }
            last;   # didn't want to loop anyway
        }
        # write out this segment if $segDataPt is still defined
        if (defined $segDataPt) {
            # write the data for this record (the data could have been
            # modified, so recalculate the length word)
            my $size = length($$segDataPt);
            if ($size > $maxSegmentLen) {
                $self->Error("$markerName segment too large! ($size bytes)");
                $err = 1;
            } else {
                $s = pack('n', length($$segDataPt) + 2);
                Write($outfile, $hdr, $s, $$segDataPt) or $err = 1;
            }
            undef $$segDataPt;  # free the buffer
        }
    }
    $/ = $oldsep;     # restore separator to original value
    # set return value to -1 if we only had a write error
    $rtnVal = -1 if $rtnVal and $err;
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Validate values of extra and composite tags
# Inputs: 0) ExifTool object reference, 1) raw value reference
#         2) tagInfo hash reference
# Returns: error string or undef on success
sub CheckExtraTags($$$)
{
    my ($self, $tagInfo, $valPtr) = @_;
    my $tag = $$tagInfo{Name};
    if ($tag eq 'ThumbnailImage' or $tag eq 'PreviewImage') {
        unless ($$valPtr =~ /^\xff\xd8/ or $self->Options('IgnoreMinorErrors')) {
            return 'Not a valid image';
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# is a number floating point?
# Inputs: 0) value
# Returns: true if it is floating point
sub IsInt($)
{
    return scalar($_[0] =~ /^[+-]?\d+$/);
}

#------------------------------------------------------------------------------
# is a number floating point?
# Inputs: 0) value
# Returns: true if it is floating point
sub IsFloat($)
{
    return scalar($_[0] =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/);
}

#------------------------------------------------------------------------------
# check a value for validity
# Inputs: 0) value reference, 1) format string, 2) optional count
# Returns: error string, or undef on success
# Notes: if a count is specified for a string, it is null-padded to the specified length
sub CheckValue($$;$)
{
    my ($valPtr, $format, $count) = @_;
    my (@vals, $n);

    if ($format eq 'string') {
        return undef unless $count;
        my $len = length($$valPtr);
        $len >= $count and return 'String too long';
        if ($len < $count) {
            $$valPtr .= "\0" x ($count - $len);
        }
        return undef;
    }
    if ($count and $count > 1) {
        @vals = split(' ',$$valPtr);
    } else {
        $count = 1;
        @vals = ( $$valPtr );
    }
    my $val;
    for ($n=0; $n<$count; ++$n) {
        $val = shift @vals;
        defined $val or return "Not enough values specified ($count required)";
        if ($format =~ /^int/) {
            # make sure the value is integer
            return 'Not an integer' unless IsInt($val);
            my ($min, $max) = @{$intRange{$format}};
            return "Value below $format minimum" if $val < $min;
            return "Value above $format maximum" if $val > $max;
        } elsif ($format =~ /^rational/ or $format eq 'float' or $format eq 'double') {
            # make sure the value is a valid floating point number
            return 'Not a floating point number' unless IsFloat($val);
            if ($format =~ /^rational\d+u$/ and $val < 0) {
                return 'Must be a positive number';
            }
        }
    }
    return undef;   # success!
}

#------------------------------------------------------------------------------
# check new value for binary data block
# Inputs: 0) ExifTool object reference, 1) tagInfo hash reference,
#         2) raw value reference
# Returns: error string or undef (and may modify value) on success
sub CheckBinaryData($$$)
{
    my ($self, $tagInfo, $valPtr) = @_;
    my $format = $$tagInfo{Format};
    unless ($format) {
        my $table = $$tagInfo{Table};
        if ($table and $$table{FORMAT}) {
            $format = $$table{FORMAT};
        } else {
            # use default 'int8u' unless specified
            $format = 'int8u';
        }
    }
    my $count;
    if ($format =~ /(.*)\[(.*)\]/) {
        $format = $1;
        $count = $2;
        # can't evaluate $count now because we don't know $size yet
        undef $count if $count =~ /\$size/;
    }
    return CheckValue($valPtr, $format, $count);
}

#------------------------------------------------------------------------------
# write to binary data block
# Inputs: 0) ExifTool object reference, 1) tag table reference,
#         2) source dirInfo reference
# Returns: Binary data block or undefined on error
sub WriteBinaryData($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package

    # get default format ('int8u' unless specified)
    my $defaultFormat = $$tagTablePtr{FORMAT} || 'int8u';
    my $increment = $$tagTablePtr{INCREMENT} || FormatSize($defaultFormat);
    unless ($increment) {
        warn "Unknown format $defaultFormat\n";
        return undef;
    }
    my $dataPt = $dirInfo->{DataPt};
    my $dirStart = $dirInfo->{DirStart} || 0;
    my $dirLen = $dirInfo->{DirLen} || length($$dataPt) - $dirStart;
    my $newData = substr($$dataPt, $dirStart, $dirLen) or return undef;
    my $dirName = $dirInfo->{DirName};
    my $verbose = $exifTool->Options('Verbose');
    my $tagInfo;
    $dataPt = \$newData;
    foreach $tagInfo ($exifTool->GetNewTagInfoList($tagTablePtr)) {
        my $tagID = $tagInfo->{TagID};
        my $count = 1;
        my $format = $$tagInfo{Format};
        if ($format) {
            if ($format =~ /(.*)\[(.*)\]/) {
                $format = $1;
                $count = $2;
                my $size = $dirLen; # used in eval
                # evaluate count to allow count to be based on previous values
                #### eval Format size (%val, $size)
                $count = eval $count;
                $@ and warn($@), next;
            }
        } else {
            $format = $defaultFormat;
        }
        my $entry = $tagID * $increment;        # relative offset of this entry
        my $val = ReadValue($dataPt, $entry, $format, $count, $dirLen-$entry);
        next unless defined $val;
        my $newValueHash = $exifTool->GetNewValueHash($tagInfo);
        next unless IsOverwriting($newValueHash);
        my $newVal = GetNewValues($newValueHash);
        next unless defined $newVal;    # can't delete from a binary table
        my $rtnVal = WriteValue($newVal, $format, $count, $dataPt, $entry);
        if (defined $rtnVal) {
            if ($verbose > 1) {
                print "    - $dirName:$$tagInfo{Name} = '$val'\n";
                print "    + $dirName:$$tagInfo{Name} = '$newVal'\n";
            }
            ++$exifTool->{CHANGED};
        }
    }
    return $newData;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Writer.pl - ExifTool routines for writing meta information

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains ExifTool write routines and other infrequently
used routines.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
