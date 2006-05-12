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

use Image::ExifTool::TagLookup qw(FindTagInfo TagExists);

sub AssembleRational($$@);
sub LastInList($);
sub CreateDirectory($);

my $loadedAllTables;    # flag indicating we loaded all tables
my $evalWarning;        # eval warning message

# the following is a road map of where we write each directory
# in the different types of files.
my %tiffMap = (
    IFD0         => 'TIFF',
    IFD1         => 'IFD0',
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
);
my %jpegMap = (
    JFIF         => 'APP0',
    IFD0         => 'APP1',
    IFD1         => 'IFD0',
    XMP          => 'APP1',
    ICC_Profile  => 'APP2',
    Photoshop    => 'APP13',
    EXIF         => 'IFD0', # to write EXIF as a block
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    IPTC         => 'Photoshop',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
    Comment      => 'COM',
);
my %dirMap = (
    JPEG => \%jpegMap,
    TIFF => \%tiffMap,
);

# groups we are allowed to delete (Note: these names must either
# exist in %dirMap, or be translated in InitWriteDirs())
my @delGroups = qw(
    AFCP EXIF ExifIFD File GlobParamIFD GPS IFD0 IFD1 InteropIFD
    ICC_Profile IPTC MakerNotes PNG MIE Photoshop PrintIM SubIFD XMP
);
# group names to translate for writing
my %translateWriteGroup = (
    EXIF => 'ExifIFD',
    File => 'Comment',
    MIE  => 'MIE',
);
# names of valid EXIF directories:
my %exifDirs = (
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
#         1) tag key, tag name, or '*' (optionally prefixed by group name),
#            or undef to reset all previous SetNewValue() calls
#         2) new value (scalar, scalar ref or list ref), or undef to delete tag
#         3-N) Options:
#           Type => PrintConv, ValueConv or Raw - specifies value type
#           AddValue => true to add to list of existing values instead of overwriting
#           DelValue => true to delete this existing value value from a list
#           Group => family 0 or 1 group name (case insensitive)
#           Replace => 0, 1 or 2 - overwrite previous new values (2=reset)
#           Protected => bitmask to write tags with specified protections
#           Shift => undef, 0, +1 or -1 - shift value if possible
#           NoShortcut => true to prevent looking up shortcut tags
# Returns: number of tags set (plus error string in list context)
# Notes: For tag lists (like Keywords), call repeatedly with the same tag name for
#        each value in the list.  Internally, the new information is stored in
#        the following members of the $self->{NEW_VALUE}->{$tagInfo} hash:
#           TagInfo - tag info ref
#           DelValue - list ref for values to delete
#           Value - list ref for values to add
#           IsCreating - must be set for the tag to be added.  otherwise just
#                        changed if it already exists
#           WriteGroup - group name where information is being written
#           Next - pointer to next newValueHash (if more than one)
#           Shift - shift value
#           Self - ExifTool ref defined only if Shift is set
sub SetNewValue($;$$%)
{
    local $_;
    my ($self, $tag, $value, %options) = @_;
    my ($err, $tagInfo);
    my $verbose = $self->Options('Verbose');
    my $out = $self->Options('TextOut');
    my $protected = $options{Protected} || 0;
    my $numSet = 0;
    unless (defined $tag) {
        # remove any existing set values
        delete $self->{NEW_VALUE};
        delete $self->{DEL_GROUP};
        $verbose > 1 and print $out "Cleared new values\n";
        return 1;
    }
    # allow value to be scalar or list reference
    if (ref $value) {
        if (ref $value eq 'ARRAY') {
            foreach (@$value) {
                my ($n, $e) = SetNewValue($self, $tag, $_, %options);
                $err = $e if $e;
                $numSet += $n;
                delete $options{Replace}; # don't replace earlier values in list
            }
ReturnNow:  return ($numSet, $err) if wantarray;
            $err and warn "$err\n";
            return $numSet;
        } elsif (ref $value eq 'SCALAR') {
            $value = $$value;
        }
    }
    # make sure the Perl UTF-8 flag is OFF for the value if perl 5.6 or greater
    # (otherwise our byte manipulations get corrupted!!)
    if ($] >= 5.006 and defined $value) {
        if (eval 'require Encode; Encode::is_utf8($value)' or $@) {
            $value = pack('C*', unpack('C*', $value));
        }
    }
    # set group name in options if specified
    if ($tag =~ /(.+?):(.+)/) {
        $options{Group} = $1 if $1 ne '*' and lc($1) ne 'all';
        $tag = $2;
    }
#
# get list of tags we want to set
#
    my $wantGroup = $options{Group};
    $tag =~ s/ .*//;    # convert from tag key to tag name if necessary
    my @matchingTags = FindTagInfo($tag);
    until (@matchingTags) {
        if ($tag eq '*' or lc($tag) eq 'all') {
            # set groups to delete
            if (defined $value) {
                $err = "Can't set value for all tags";
            } else {
                my (@del, $grp);
                if ($wantGroup) {
                    @del = grep /^$wantGroup$/i, @delGroups;
                } else {
                    push @del, @delGroups;
                }
                if (@del) {
                    ++$numSet;
                    $self->{DEL_GROUP} or $self->{DEL_GROUP} = { };
                    foreach $grp (@del) {
                        if ($options{Replace} and $options{Replace} > 1) {
                            delete $self->{DEL_GROUP}->{$grp};
                            $verbose > 1 and print $out "Removed group $grp from delete list\n";
                        } else {
                            $self->{DEL_GROUP}->{$grp} = 1;
                            $verbose > 1 and print $out "Deleting all $grp tags\n";
                        }
                    }
                } else {
                    $err = "Not a deletable group: $wantGroup";
                }
            }
        } else {
            my $origTag = $tag;
            if ($tag =~ /^(\w+)-([a-z]{2})_([a-z]{2})$/i) {
                # allow language codes suffix of form "-en_CA" on tag name
                $tag = $1;
                my $langCode = lc($2) . '_' . uc($3);
                my @newMatches = FindTagInfo($tag);
                foreach $tagInfo (@newMatches) {
                    # only allow language codes in tables which support them
                    next unless $$tagInfo{Table};
                    my $langInfoProc = $tagInfo->{Table}->{LANG_INFO} or next;
                    my $langInfo = &$langInfoProc($tagInfo, $langCode);
                    push @matchingTags, $langInfo if $langInfo;
                } 
                last if @matchingTags;
            } else {
                # look for a shortcut or alias
                require Image::ExifTool::Shortcuts;
                my ($match) = grep /^\Q$tag\E$/i, keys %Image::ExifTool::Shortcuts::Main;
                undef $err;
                if ($match and not $options{NoShortcut}) {
                    if (@{$Image::ExifTool::Shortcuts::Main{$match}} == 1) {
                        $tag = $Image::ExifTool::Shortcuts::Main{$match}->[0];
                        @matchingTags = FindTagInfo($tag);
                        last if @matchingTags;
                    } else {
                        $options{NoShortcut} = 1;
                        foreach $tag (@{$Image::ExifTool::Shortcuts::Main{$match}}) {
                            my ($n, $e) = $self->SetNewValue($tag, $value, %options);
                            $numSet += $n;
                            $e and $err = $e;
                        }
                        goto ReturnNow; # all done
                    }
                }
            }
            if (not TagExists($tag)) {
                $err = "Tag '$origTag' does not exist";
            } elsif ($wantGroup) {
                $err = "Sorry, $wantGroup:$origTag doesn't exist or isn't writable";
            } else {
                $err = "Sorry, $origTag is not writable";
            }
        }
        goto ReturnNow; # all done
    }
    # get group name that we're looking for
    my $foundMatch = 0;
    my $ifdName;
    if ($wantGroup) {
        # set $ifdName if this group is a valid IFD or SubIFD name
        if ($wantGroup =~ /^IFD(\d+)$/i) {
            $ifdName = "IFD$1";
        } elsif ($wantGroup =~ /^SubIFD(\d+)$/i) {
            $ifdName = "SubIFD$1";
        } elsif ($wantGroup =~ /^MIE(\d*-?)(\w+)$/i) {
            $ifdName = "MIE$1" . ucfirst(lc($2));
        } else {
            $ifdName = $exifDirs{lc($wantGroup)};
            if ($wantGroup =~ /^XMP\b/i) {
                # must load XMP table to set group1 names
                my $table = GetTagTable('Image::ExifTool::XMP::Main');
                my $writeProc = $table->{WRITE_PROC};
                $writeProc and &$writeProc();
            }
        }
    }
#
# determine the groups for all tags found, and the tag with
# the highest priority group
#
    my (@tagInfoList, %writeGroup, %preferred, %tagPriority, $avoid);
    my $highestPriority = -1;
    foreach $tagInfo (@matchingTags) {
        $tag = $tagInfo->{Name};    # set tag so warnings will use proper case
        my ($writeGroup, $priority);
        if ($wantGroup) {
            my $lcWant = lc($wantGroup);
            # only set tag in specified group
            $writeGroup = $self->GetGroup($tagInfo, 0);
            unless (lc($writeGroup) eq $lcWant) {
                if ($writeGroup eq 'EXIF' or $writeGroup eq 'MIE') {
                    next unless $ifdName;
                    $writeGroup = $ifdName;  # write to the specified IFD
                } else {
                    # allow group1 name to be specified
                    my $grp1 = $self->GetGroup($tagInfo, 0);
                    unless ($grp1 and lc($grp1) eq $lcWant) {
                        # must also check group1 name directly in case it is different
                        $grp1 = $tagInfo->{Groups}->{1};
                        next unless $grp1 and lc($grp1) eq $lcWant;
                    }
                }
            }
            $priority = 1000;   # highest priority since group was specified
        }
        ++$foundMatch;
        # must do a dummy call to the write proc to autoload write package
        # before checking Writable flag
        my $table = $tagInfo->{Table};
        my $writeProc = $table->{WRITE_PROC};
        # load parent table if this was a user-defined table
        if ($table->{PARENT}) {
            my $parent = GetTagTable($table->{PARENT});
            $writeProc = $parent->{WRITE_PROC} unless $writeProc;
        }
        next unless $writeProc and &$writeProc();
        # must still check writable flags in case of UserDefined tags
        my $writable = $tagInfo->{Writable};
        next unless $writable or ($table->{WRITABLE} and
            not defined $writable and not $$tagInfo{SubDirectory});
        # don't write tag if protected
        next if $tagInfo->{Protected} and not ($tagInfo->{Protected} & $protected);
        # set specific write group (if we didn't already)
        unless ($writeGroup and not $translateWriteGroup{$writeGroup}) {
            $writeGroup = $tagInfo->{WriteGroup} || $tagInfo->{Table}->{WRITE_GROUP};   # use default write group
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
#
# generate new value hash for each tag
#
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
        my $wgrp1;
        if ($writeGroup eq 'MakerNotes' or $writeGroup eq 'XMP') {
            $wgrp1 = $self->GetGroup($tagInfo, 1);
        } else {
            $wgrp1 = $writeGroup;
        }
        $tag = $tagInfo->{Name};    # get proper case for tag name
        my $shift = $options{Shift};
        if (defined $shift) {
            if ($tagInfo->{Shift}) {
                unless ($shift) {
                    # set shift according to AddValue/DelValue
                    $shift = 1 if $options{AddValue};
                    $shift = -1 if $options{DelValue};
                }
            } elsif ($shift) {
                $err = "$wgrp1:$tag is not shiftable";
                $verbose > 2 and print $out "$err\n";
                next;
            }
        }
        # convert the value
        my $val = $value;
        # can't delete permanent tags, so set value to empty string instead
        $val = '' if not defined $val and $permanent;
        my $type;
        if ($shift) {
            # add '+' or '-' prefix to indicate shift direction
            $val = ($shift > 0 ? '+' : '-') . $val;
            # check the shift for validity
            require 'Image/ExifTool/Shift.pl';
            my $err2 = CheckShift($tagInfo->{Shift}, $val);
            if ($err2) {
                $err = "$err2 for $wgrp1:$tag";
                $verbose > 2 and print $out "$err\n";
                next;
            }
        } else {
            $type = $options{Type};
            $type or $type = $self->Options('PrintConv') ? 'PrintConv' : 'ValueConv';
        }
        while (defined $val and not $shift) {
            my $conv = $tagInfo->{$type};
            my $convInv = $tagInfo->{"${type}Inv"};
            if ($convInv) {
                # capture eval warnings too
                local $SIG{'__WARN__'} = sub { $evalWarning = $_[0]; };
                undef $evalWarning;
                if (ref($convInv) eq 'CODE') {
                    $val = &$convInv($val, $self);
                } else {
                    #### eval PrintConvInv/ValueConvInv ($val, $self)
                    $val = eval $convInv;
                    $@ and $evalWarning = $@;
                }
                if ($evalWarning) {
                    chomp $evalWarning;
                    $evalWarning =~ s/ at \(eval .*//s;
                    $err = "$evalWarning in $wgrp1:$tag (${type}Inv)";
                    $verbose > 2 and print $out "$err\n";
                    undef $val;
                    last;
                } elsif (not defined $val) {
                    $err = "Error converting value for $wgrp1:$tag (${type}Inv)";
                    $verbose > 2 and print $out "$err\n";
                    last;
                }
            } elsif ($conv) {
                if (ref $conv eq 'HASH') {
                    my $multi;
                    if ($$conv{BITMASK}) {
                        my $lookupBits = $$conv{BITMASK};
                        my ($val2, $err2) = EncodeBits($val, $lookupBits);
                        if ($err2) {
                            $err = "Can't encode $wgrp1:$tag ($err2)";
                            $verbose > 2 and print $out "$err\n";
                            undef $val;
                            last;
                        } elsif (defined $val2) {
                            $val = $val2;
                        } else {
                            delete $$conv{BITMASK};
                            ($val, $multi) = ReverseLookup($val, $conv);
                            $$conv{BITMASK} = $lookupBits;
                        }
                    } else {
                        ($val, $multi) = ReverseLookup($val, $conv);
                    }
                    unless (defined $val) {
                        $err = "Can't convert $wgrp1:$tag (" .
                               ($multi ? 'matches more than one' : 'not in') . " $type)";
                        $verbose > 2 and print $out "$err\n";
                        last;
                    }
                } else {
                    $err = "Can't convert value for $wgrp1:$tag (no ${type}Inv)";
                    $verbose > 2 and print $out "$err\n";
                    undef $val;
                    last;
                }
            }
            # cycle through PrintConv, ValueConv
            if ($type eq 'PrintConv') {
                $type = 'ValueConv';
            } else {
                # validate the value with WriteCheck and CHECK_PROC if they exist
                my $err2;
                if ($tagInfo->{WriteCheck}) {
                    #### eval WriteCheck ($self, $tagInfo, $val)
                    $err2 = eval $tagInfo->{WriteCheck};
                    $@ and warn($@), $err2 = 'Error evaluating WriteCheck';
                }
                unless ($err2) {
                    my $table = $tagInfo->{Table};
                    if ($table and $table->{CHECK_PROC}) {
                        my $checkProc = $table->{CHECK_PROC};
                        $err2 = &$checkProc($self, $tagInfo, \$val);
                    }
                }
                if ($err2) {
                    $err = "$err2 for $wgrp1:$tag";
                    $verbose > 2 and print $out "$err\n";
                    undef $val; # value was invalid
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
            # delete the previous new value
            $self->GetNewValueHash($tagInfo, $writeGroup, 'delete');
            # also delete related tag previous new values
            if ($$tagInfo{WriteAlso}) {
                my $wtag;
                foreach $wtag (keys %{$$tagInfo{WriteAlso}}) {
                    my ($n,$e) = $self->SetNewValue($wtag, undef, Replace=>2);
                    $numSet += $n;
                }
            }
            $options{Replace} == 2 and ++$numSet, next;
        }

        # set value in NEW_VALUE hash
        if (defined $val) {
            if ($options{AddValue} and not ($shift or $tagInfo->{List})) {
                $err = "Can't add $wgrp1:$tag (not a List type)";
                $verbose > 2 and print $out "$err\n";
                next;
            }
            # we are editing this tag, so create a NEW_VALUE hash entry
            my $newValueHash = $self->GetNewValueHash($tagInfo, $writeGroup, 'create');
            if ($options{DelValue} or $options{AddValue} or $shift) {
                # flag any AddValue or DelValue by creating the DelValue list
                $newValueHash->{DelValue} or $newValueHash->{DelValue} = [ ];
                if ($shift) {
                    # add shift value to list
                    $newValueHash->{Shift} = $val;
                    $newValueHash->{Self} = $self;
                } elsif ($options{DelValue}) {
                    # don't create if we are replacing a specific value
                    $newValueHash->{IsCreating} = 0 unless $val eq '';
                    # add delete value to list
                    push @{$newValueHash->{DelValue}}, $val;
                    if ($verbose > 1) {
                        my $verb = $permanent ? 'Replacing' : 'Deleting';
                        my $fromList = $tagInfo->{List} ? ' from list' : '';
                        print $out "$verb $wgrp1:$tag$fromList if value is '$val'\n";
                    }
                }
            }
            # set priority flag to add only the high priority info
            # (will only create the priority tag if it doesn't exist,
            #  others get changed only if they already exist)
            if ($preferred{$tagInfo} or $tagInfo->{Table}->{PREFERRED}) {
                if ($permanent or $shift) {
                    # don't create permanent or Shift-ed tag but define IsCreating
                    # so we know that it is the preferred tag
                    $newValueHash->{IsCreating} = 0;
                } elsif (not ($newValueHash->{DelValue} and @{$newValueHash->{DelValue}}) or
                         # also create tag if any DelValue value is empty ('')
                         grep(/^$/,@{$newValueHash->{DelValue}}))
                {
                    $newValueHash->{IsCreating} = 1;
                }
            }
            if ($shift or not $options{DelValue}) {
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
                    if ($shift) {
                        print $out "Shifting $wgrp1:$tag$ifExists\n";
                    } elsif ($options{AddValue}) {
                        print $out "Adding to $wgrp1:$tag$ifExists\n";
                    } else {
                        print $out "Writing $wgrp1:$tag$ifExists\n";
                    }
                }
            }
        } elsif ($permanent) {
            $err = "Can't delete $tag";
            $verbose > 1 and print $out "$err\n";
            next;
        } elsif ($options{AddValue} or $options{DelValue}) {
            $verbose > 1 and print $out "Adding/Deleting nothing does nothing\n";
            next;
        } else {
            # create empty new value hash entry to delete this tag
            $self->GetNewValueHash($tagInfo, $writeGroup, 'delete');
            $self->GetNewValueHash($tagInfo, $writeGroup, 'create');
            $verbose > 1 and print $out "Deleting $wgrp1:$tag\n";
        }
        ++$numSet;
        $prioritySet = 1 if $preferred{$tagInfo};
        # set markers in required tags
        if ($$tagInfo{Require}) {
            foreach (keys %{$$tagInfo{Require}}) {
                push @requireTags, $tagInfo->{Require}->{$_};
            }
        }
        # also write related tags
        my $writeAlso = $$tagInfo{WriteAlso};
        if ($writeAlso) {
            my $wtag;
            foreach $wtag (keys %$writeAlso) {
                #### eval WriteAlso ($val)
                my $v = eval $writeAlso->{$wtag};
                $@ and warn($@), next;
                my ($n,$e) = $self->SetNewValue($wtag, $v, Type => 'ValueConv');
                $numSet += $n;
            }
        }
    }
    # print warning if we couldn't set our priority tag
    if ($err and not $prioritySet) {
        warn "$err\n" unless wantarray or $verbose > 2;
    } elsif (not $numSet) {
        if ($foundMatch) {
            my $pre = $wantGroup ? "$wantGroup:" : '';
            $err = "Sorry, $pre$tag is not writable";
        } else {
            $err = "Tag '$wantGroup:$tag' does not exist";
        }
        warn "$err\n" unless wantarray;
    } elsif ($err and not $verbose) {
        undef $err;
    }
    # set markers to create all required tags too
    if (@requireTags) {
        # set marker to 'feed' value later
        $value = 0xfeedfeed if defined $value;
        foreach $tag (@requireTags) {
            $self->SetNewValue($tag, $value, Protected=>0x02);
        }
    }
    return ($numSet, $err) if wantarray;
    return $numSet;
}

#------------------------------------------------------------------------------
# set new values from information in specified file
# Inputs: 0) ExifTool object reference, 1) source file name or reference, etc
#         2) List of tags to set (or all if none specified)
# Returns: Hash of information set successfully (includes Warning or Error messages)
# Notes: Tag names may contain group prefix and/or leading '-' to exclude from copy,
#        and the tag name '*' may be used to represent all tags in a group.
#        Also, a tag name may end with '>DSTTAG' to copy the information to a
#        different tag, or a tag with a specified group.  (Also allow 'DSTTAG<TAG'.)
sub SetNewValuesFromFile($$;@)
{
    my ($self, $srcFile, @setTags) = @_;

    # expand shortcuts
    @setTags and ExpandShortcuts(\@setTags);
    # get all tags from source file (including MakerNotes block)
    my $srcExifTool = new Image::ExifTool;
    my $opts = {MakerNotes=>1, Binary=>1, Duplicates=>1, List=>1};
    $opts->{IgnoreMinorErrors} = $self->Options('IgnoreMinorErrors');
    $opts->{PrintConv} = $self->Options('PrintConv');
    $opts->{DateFormat} = $self->Options('DateFormat');
    $opts->{StrictDate} = 1;
    my $info = $srcExifTool->ImageInfo($srcFile, $opts);
    return $info if $info->{Error} and $info->{Error} eq 'Error opening file';

    # sort tags in reverse order so we get priority tag last
    my @tags = reverse sort keys %$info;
    my $tag;
#
# simply transfer all tags from source image if no tags specified
#
    unless (@setTags) {
        # transfer maker note information to this object
        $self->{MAKER_NOTE_FIXUP} = $srcExifTool->{MAKER_NOTE_FIXUP};
        $self->{MAKER_NOTE_BYTE_ORDER} = $srcExifTool->{MAKER_NOTE_BYTE_ORDER};
        foreach $tag (@tags) {
            # don't try to set Warning's or Error's
            next if $tag =~ /^Warning\b/ or $tag =~ /^Error\b/;
            # set value for this tag
            my ($n, $e) = $self->SetNewValue($tag, $info->{$tag}, Replace => 1);
            # delete this tag if we could't set it
            $n or delete $info->{$tag};
        }
        return $info;
    }
#
# transfer specified tags in the proper order
#
    # 1) loop through input list of tags to set, and build @setList
    my (@setList, $set, %setMatches);
    foreach (@setTags) {
        $tag = lc($_);  # change tag name to all lower case
        $tag =~ s/\ball\b/\*/g;     # replace 'all' with '*' in tag/group names
        my ($grp, $dst, $dstGrp, $dstTag);
        # handle redirection to another tag
        if ($tag =~ /(.+?)\s*(>|<)\s*(.+)/) {
            $dstGrp = '';
            ($tag, $dstTag) = ($2 eq '>') ? ($1, $3) : ($3, $1);
            ($dstGrp, $dstTag) = ($1, $2) if $dstTag =~ /(.+?):(.+)/;
        }
        my $isExclude = ($tag =~ s/^-//) ? 1 : 0;
        if ($tag =~ /(.+?):(.+)/) {
            ($grp, $tag) = ($1, $2);
        } else {
            $grp = '';  # flag for don't care about group
        }
        # redirect, exclude or set this tag (Note: $grp is '' if we don't care)
        if ($dstTag) {
            # redirect this tag
            $isExclude and return { Error => "Can't redirect excluded tag" };
            if ($tag eq '*' and $dstTag ne '*') {
                return { Error => "Can't redirect from all tags to one tag" };
            }
            # set destination group the same as source if necessary
            $dstGrp = $grp if $dstGrp eq '*' and $grp;
            # write to specified destination group/tag
            $dst = [ $dstGrp, $dstTag ];
        } elsif ($isExclude) {
            # implicitly assume '*' if first entry is an exclusion
            unshift @setList, [ '*', '*', [ '', '*' ] ] unless @setList;
            # exclude this tag by leaving $dst undefined
        } else {
            # copy to same group/tag
            $dst = [ $grp, $tag ];
        }
        $grp or $grp = '*';     # use '*' for any group
        # save in reverse order so we don't set tags before an exclude
        unshift @setList, [ $grp, $tag, $dst ];
    }
    # 2) initialize lists of matching tags for each condition
    foreach $set (@setList) {
        $$set[2] and $setMatches{$$set[2]} = [ ];
    }
    # 3) loop through all tags in source image and save tags matching each condition
    my %rtnInfo;
    foreach $tag (@tags) {
        # don't try to set Warning's or Error's
        if ($tag =~ /^Warning\b/ or $tag =~ /^Error\b/) {
            $rtnInfo{$tag} = $info->{$tag};
            next;
        }
        my @dstList;
        # only set specified tags
        my $lcTag = lc(GetTagName($tag));
        my ($grp0, $grp1);
        foreach $set (@setList) {
            # check first for matching tag
            next unless $$set[1] eq $lcTag or $$set[1] eq '*';
            # then check for matching group
            unless ($$set[0] eq '*') {
                # get lower case group names if not done already
                unless ($grp0) {
                    $grp0 = lc($srcExifTool->GetGroup($tag, 0));
                    $grp1 = lc($srcExifTool->GetGroup($tag, 1));
                }
                next unless $$set[0] eq $grp0 or $$set[0] eq $grp1;
            }
            last unless $$set[2];   # all done if we hit an exclude
            # add to the list of tags matching this condition
            push @{$setMatches{$set}}, $tag;
        }
    }
    # 4) loop through each condition in original order, setting new tag values
    foreach $set (reverse @setList) {
        foreach $tag (@{$setMatches{$set}}) {
            my (@values, %opts, $val);
            # get all values for this tag
            if (ref $info->{$tag} eq 'ARRAY') {
                @values = @{$info->{$tag}};
            } elsif (ref $info->{$tag} eq 'SCALAR') {
                @values = ( ${$info->{$tag}} );
            } else {
                @values = ( $info->{$tag} );
            }
            my ($dstGrp, $dstTag) = @{$$set[2]};
            if ($dstGrp) {
                $dstGrp = $srcExifTool->GetGroup($tag, 1) if $dstGrp eq '*';
                $opts{Group} = $dstGrp;
            }
            # transfer maker note information if setting this tag
            if ($srcExifTool->{TAG_INFO}->{$tag}->{MakerNotes}) {
                $self->{MAKER_NOTE_FIXUP} = $srcExifTool->{MAKER_NOTE_FIXUP};
                $self->{MAKER_NOTE_BYTE_ORDER} = $srcExifTool->{MAKER_NOTE_BYTE_ORDER};
            }
            $dstTag = $tag if $dstTag eq '*';
            # allow protected tags to be copied if specified explicitly
            $opts{Protected} = 1 unless $$set[1] eq '*';    
            $opts{Replace} = 1;     # replace the first value found
            # set all values for this tag
            foreach $val (@values) {
                my @rtnVals = $self->SetNewValue($dstTag, $val, %opts);
                last unless $rtnVals[0];
                $rtnInfo{$tag} = $info->{$tag}; # tag was set successfully
                $opts{Replace} = 0;
            }
        }
    }
    return \%rtnInfo;   # return information that we set
}

#------------------------------------------------------------------------------
# Get new value(s) for tag
# Inputs: 0) ExifTool object reference, 1) tag key, tag name, or tagInfo hash ref
#         2) optional pointer to return new value hash reference (not part of public API)
#    or   0) new value hash reference (not part of public API)
# Returns: List of new Raw values (list may be empty if tag is being deleted)
# Notes: Preferentially returns new value from Extra table if writable Extra tag exists
sub GetNewValues($;$$)
{
    local $_;
    my $newValueHash;
    if (ref $_[0] eq 'HASH') {
        $newValueHash = shift;
    } else {
        my ($self, $tag, $newValueHashPt) = @_;
        if ($self->{NEW_VALUE}) {
            my $tagInfo;
            if (ref $tag) {
                $newValueHash = $self->GetNewValueHash($tag);
            } elsif (defined($tagInfo = $Image::ExifTool::Extra{$tag}) and
                     $$tagInfo{Writable})
            {
                $newValueHash = $self->GetNewValueHash($tagInfo);
            } else {
                my @tagInfoList = FindTagInfo($tag);
                # choose the one that we are creating
                foreach $tagInfo (@tagInfoList) {
                    my $nvh = $self->GetNewValueHash($tagInfo) or next;
                    $newValueHash = $nvh;
                    last if defined $newValueHash->{IsCreating};
                }
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
# Return the total number of new values set
# Inputs: 0) ExifTool object reference
# Returns: Scalar context) Number of new values that have been set
#          List context) Number of new values, number of "quick" values
# ("quick" values are those which don't require rewriting the file to change)
sub CountNewValues($)
{
    my $self = shift;
    my $newVal = $self->{NEW_VALUE};
    my $num = 0;
    $num += scalar keys %$newVal if $newVal;
    $num += scalar keys %{$self->{DEL_GROUP}} if $self->{DEL_GROUP};
    return $num unless wantarray;
    my $quick = 0;
    if ($newVal) {
        my $tag;
        # (Note: all "quick" tags must be found in Extra table)
        foreach $tag (qw{FileName Directory FileModifyDate}) {
            ++$quick if defined $$newVal{$Image::ExifTool::Extra{$tag}};
        }
    }
    return ($num, $quick);
}

#------------------------------------------------------------------------------
# Save new values for subsequent restore
# Inputs: 0) ExifTool object reference
sub SaveNewValues($)
{
    my $self = shift;
    my $newValues = $self->{NEW_VALUE};
    my $key;
    foreach $key (keys %$newValues) {
        my $newValueHash = $$newValues{$key};
        while ($newValueHash) {
            $newValueHash->{Save} = 1;  # set Save flag
            $newValueHash = $newValueHash->{Next};
        }
    }
    # initialize hash for saving overwritten new values
    $self->{SAVE_NEW_VALUE} = { };
}

#------------------------------------------------------------------------------
# Restore new values to last saved state
# Inputs: 0) ExifTool object reference
# Notes: Restores saved new values, but currently doesn't restore them in the
# orginal order, so there may be some minor side-effects when restoring tags
# with overlapping groups. ie) XMP:Identifier, XMP-dc:Identifier
sub RestoreNewValues($)
{
    my $self = shift;
    my $newValues = $self->{NEW_VALUE};
    my $savedValues = $self->{SAVE_NEW_VALUE};
    my $key;
    # 1) remove any new values which don't have the Save flag set
    if ($newValues) {
        my @keys = keys %$newValues;
        foreach $key (@keys) {
            my $lastHash;
            my $newValueHash = $$newValues{$key};
            while ($newValueHash) {
                if ($newValueHash->{Save}) {
                    $lastHash = $newValueHash;
                } else {
                    # remove this entry from the list
                    if ($lastHash) {
                        $lastHash->{Next} = $newValueHash->{Next};
                    } elsif ($newValueHash->{Next}) {
                        $$newValues{$key} = $newValueHash->{Next};
                    } else {
                        delete $$newValues{$key};
                    }
                }
                $newValueHash = $newValueHash->{Next};
            }
        }
    }
    # 2) restore saved new values
    if ($savedValues) {
        $newValues or $newValues = $self->{NEW_VALUE} = { };
        foreach $key (keys %$savedValues) {
            if ($$newValues{$key}) {
                # add saved values to end of list
                my $newValueHash = LastInList($$newValues{$key});
                $newValueHash->{Next} = $$savedValues{$key};
            } else {
                $$newValues{$key} = $$savedValues{$key};
            }
        }
        $self->{SAVE_NEW_VALUE} = { };  # reset saved new values
    }
}

#------------------------------------------------------------------------------
# Set file modification time from FileModifyDate tag
# Inputs: 0) ExifTool object reference, 1) file name or file ref
#         2) modify time (-M) of original file (needed for time shift)
# Returns: 1=time changed OK, 0=nothing done, -1=error setting time
#          (and increments CHANGED flag if time was changed)
sub SetFileModifyDate($$;$)
{
    my ($self, $file, $originalTime) = @_;
    my $newValueHash;
    my $val = $self->GetNewValues('FileModifyDate', \$newValueHash);
    return 0 unless defined $val;
    my $isOverwriting = IsOverwriting($newValueHash);
    return 0 unless $isOverwriting;
    if ($isOverwriting < 0) {  # are we shifting time?
        # use original time of this file if not specified
        $originalTime = -M $file unless defined $originalTime;
        return 0 unless defined $originalTime;
        return 0 unless IsOverwriting($newValueHash, $^T - $originalTime*(24*3600));
        $val = $newValueHash->{Value}->[0]; # get shifted value
    }
    unless (utime($val, $val, $file)) {
        $self->Warn('Error setting FileModifyDate');
        return -1;
    }
    ++$self->{CHANGED};
    $self->VPrint(1, "    + FileModifyDate = '$val'\n");
    return 1;
}

#------------------------------------------------------------------------------
# Change file name and/or directory from FileName and Directory tags
# Inputs: 0) ExifTool object reference, 1) current file name (including path)
#         2) New name (or undef to build from FileName and Directory tags)
# Returns: 1=name changed OK, 0=nothing changed, -1=error changing name
#          (and increments CHANGED flag if filename changed)
# Notes: Will not overwrite existing file.  Creates directories as necessary.
sub SetFileName($$;$)
{
    my ($self, $file, $newName) = @_;
    my ($newValueHash, $doName, $doDir);
    # determine the new file name
    unless (defined $newName) {
        my $filename = $self->GetNewValues('FileName', \$newValueHash);
        $doName = 1 if defined $filename and IsOverwriting($newValueHash, $file);
        my $dir = $self->GetNewValues('Directory', \$newValueHash);
        $doDir = 1 if defined $dir and IsOverwriting($newValueHash, $file);
        return 0 unless $doName or $doDir;  # nothing to do
        if ($doName) {
            $newName = GetNewFileName($file, $filename);
            $newName = GetNewFileName($newName, $dir) if $doDir;
        } else {
            $newName = GetNewFileName($file, $dir);
        }
    }
    if (-e $newName) {
        # don't replace existing file
        $self->Warn("File '$newName' already exists");
        return -1;
    }
    # create directory for new file if necessary
    my $result;
    if (($result = CreateDirectory($newName)) != 0) {
        if ($result < 0) {
            $self->Warn("Error creating directory for '$newName'");
            return -1;
        }
        $self->VPrint(0, "Created directory for '$newName'");
    }
    # attempt to rename the file
    unless (rename $file, $newName) {
        # renaming didn't work, so copy the file instead
        unless (open EXIFTOOL_SFN_IN, $file) {
            $self->Warn("Error opening '$file'");
            return -1;
        }
        unless (open EXIFTOOL_SFN_OUT, ">$newName") {
            close EXIFTOOL_SFN_IN;
            $self->Warn("Error creating '$newName'");
            return -1;
        }
        binmode EXIFTOOL_SFN_IN;
        binmode EXIFTOOL_SFN_OUT;
        my ($buff, $err);
        while (read EXIFTOOL_SFN_IN, $buff, 65536) {
            print EXIFTOOL_SFN_OUT $buff or $err = 1;
        }
        close EXIFTOOL_SFN_OUT or $err = 1;
        close EXIFTOOL_SFN_IN;
        if ($err) {
            unlink $newName;    # erase bad output file
            $self->Warn("Error writing '$newName'");
            return -1;
        }
        # preserve modification time
        my $modTime = $^T - (-M $file) * (24 * 3600);
        my $accTime = $^T - (-A $file) * (24 * 3600);
        utime($accTime, $modTime, $newName);
        # remove the original file
        unlink $file or $self->Warn('Error removing old file');
    }
    ++$self->{CHANGED};
    $self->VPrint(1, "    + FileName = '$newName'\n");
    return 1;
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
#         1) input filename, file ref, or scalar ref (or '' or undef to create from scratch)
#         2) output filename, file ref, or scalar ref (or undef to edit in place)
#         3) optional output file type (required only if input file is not specified
#            and output file is a reference)
# Returns: 1=file written OK, 2=file written but no changes made, 0=file write error
sub WriteInfo($$;$$)
{
    local $_;
    my ($self, $infile, $outfile, $outType) = @_;
    my (@fileTypeList, $fileType, $tiffType);
    my ($inRef, $outRef, $closeIn, $closeOut, $outPos, $outBuff);
    my $oldRaf = $self->{RAF};
    my $rtnVal = 1;

    # initialize member variables
    $self->Init();

    # first, save original file modify date if necessary
    # (do this now in case we are modifying file in place and shifting date)
    my ($newValueHash, $originalTime);
    my $fileModifyDate =  $self->GetNewValues('FileModifyDate', \$newValueHash);
    if (defined $fileModifyDate and IsOverwriting($newValueHash) < 0 and
        defined $infile and ref $infile ne 'SCALAR')
    {
        $originalTime = -M $infile;
    }
#
# do quick in-place change of file dir/name or date if that is all we are doing
#
    if (not defined $outfile and defined $infile) {
        my $newFileName =  $self->GetNewValues('FileName', \$newValueHash);
        my ($numNew, $numQuick) = $self->CountNewValues();
        if ($numNew == $numQuick) {
            $rtnVal = 2;
            if (defined $fileModifyDate and (not ref $infile or UNIVERSAL::isa($infile,'GLOB'))) {
                $self->SetFileModifyDate($infile) > 0 and $rtnVal = 1;
            }
            if (defined $newFileName and not ref $infile) {
                $self->SetFileName($infile) > 0 and $rtnVal = 1;
            }
            return $rtnVal;
        } elsif (defined $newFileName and length $newFileName) {
            # can't simply rename file, so just set the output name if new FileName
            # --> in this case, the old copy is not erased! (maybe it should be)
            if (ref $infile) {
                $outfile = $newFileName;
            } elsif (IsOverwriting($newValueHash, $infile)) {
                $outfile = GetNewFileName($infile, $newFileName);
            }
        }
    }
#
# set up input file
#
    if (ref $infile) {
        $inRef = $infile;
        # make sure we are at the start of the file
        seek($inRef, 0, 0) if UNIVERSAL::isa($inRef,'GLOB');
    } elsif (defined $infile and $infile ne '') {
        if (open(EXIFTOOL_FILE2, defined $outfile ? $infile : "+<$infile")) {
            $fileType = GetFileType($infile);
            $tiffType = GetFileExtension($infile);
            $self->VPrint(0, "Rewriting $infile...\n");
            $inRef = \*EXIFTOOL_FILE2;
            $closeIn = 1;   # we must close the file since we opened it
        } else {
            my $forUpdate = (defined $outfile ? '' : ' for update');
            $self->Error("Error opening file$forUpdate");
            return 0;
        }
    } elsif (not defined $outfile) {
        $self->Error("WriteInfo(): Must specify infile or outfile\n");
        return 0;
    } else {
        # create file from scratch
        $outType = GetFileType($outfile) unless $outType or ref $outfile;
        if (CanCreate($outType)) {
            $fileType = $tiffType = $outType;   # use output file type if no input file
            $infile = "$fileType file";         # make bogus file name
            $self->VPrint(0, "Creating $infile...\n");
            $inRef = \ '';      # set $inRef to reference to empty data
        } elsif ($outType) {
            $self->Error("Can't create $outType files");
            return 0;
        } else {
            $self->Error("Can't create file (unknown type)");
            return 0;
        }
    }
    if ($fileType) {
        @fileTypeList = ( $fileType );
    } else {
        @fileTypeList = @fileTypes;
        $tiffType = 'TIFF';
    }
#
# set up output file
#
    if (ref $outfile) {
        $outRef = $outfile;
        if (UNIVERSAL::isa($outRef,'GLOB')) {
            binmode($outRef);
            $outPos = tell($outRef);
        } else {
            # initialize our output buffer if necessary
            defined $$outRef or $$outRef = '';
            $outPos = length($$outRef);
        }
    } elsif (not defined $outfile) {
        # editing in place, so write to memory first
        $outBuff = '';
        $outRef = \$outBuff;
        $outPos = 0;
    } elsif (-e $outfile) {
        $self->Error("File already exists: $outfile");
        $rtnVal = 0;
    } elsif (open(EXIFTOOL_OUTFILE, ">$outfile")) {
        $outRef = \*EXIFTOOL_OUTFILE;
        $closeOut = 1;  # we must close $outRef
        binmode($outRef);
        $outPos = 0;
    } else {
        $self->Error("Error creating file: $outfile");
        $rtnVal = 0;
    }
#
# write the file
#
    if ($rtnVal) {
        # create random access file object
        my $raf = new File::RandomAccess($inRef);
        # patch for Windows command shell pipe
        $raf->{TESTED} = -1 if not ref $infile and ($infile eq '-' or $infile =~ /\|$/);
       # $raf->Debug() and warn "  RAF debugging enabled!\n";
        my $inPos = $raf->Tell();
        $raf->BinMode();
        $self->{RAF} = $raf;
        my %dirInfo = (
            RAF => $raf,
            OutFile => $outRef,
        );
        for (;;) {
            my $type = shift @fileTypeList;
            # save file type in member variable
            $dirInfo{Parent} = $self->{FILE_TYPE} = $type;
            # determine which directories we must write for this file type
            $self->InitWriteDirs($type);
            if ($type eq 'JPEG') {
                $rtnVal = $self->WriteJPEG(\%dirInfo);
            } elsif ($type eq 'TIFF') {
                # don't allow rewriting of Sony raw images
                if ($tiffType =~ /^(SRF|SR2)$/) {
                    $fileType = $tiffType;
                    undef $rtnVal;
                } else {
                    $dirInfo{Parent} = $tiffType;
                    $rtnVal = $self->ProcessTIFF(\%dirInfo);
                }
            } elsif ($type eq 'GIF') {
                require Image::ExifTool::GIF;
                $rtnVal = Image::ExifTool::GIF::ProcessGIF($self,\%dirInfo);
            } elsif ($type eq 'CRW') {
                require Image::ExifTool::CanonRaw;
                $rtnVal = Image::ExifTool::CanonRaw::WriteCRW($self, \%dirInfo);
            } elsif ($type eq 'MRW') {
                require Image::ExifTool::MinoltaRaw;
                $rtnVal = Image::ExifTool::MinoltaRaw::ProcessMRW($self, \%dirInfo);
            } elsif ($type eq 'PNG') {
                require Image::ExifTool::PNG;
                $rtnVal = Image::ExifTool::PNG::ProcessPNG($self, \%dirInfo);
            } elsif ($type eq 'MIE') {
                require Image::ExifTool::MIE;
                $rtnVal = Image::ExifTool::MIE::ProcessMIE($self, \%dirInfo);
            } elsif ($type eq 'XMP') {
                require Image::ExifTool::XMP;
                $rtnVal = Image::ExifTool::XMP::WriteXMP($self, \%dirInfo);
            } elsif ($type eq 'PPM') {
                require Image::ExifTool::PPM;
                $rtnVal = Image::ExifTool::PPM::ProcessPPM($self, \%dirInfo);
            } elsif ($type eq 'PSD') {
                require Image::ExifTool::Photoshop;
                $rtnVal = Image::ExifTool::Photoshop::ProcessPSD($self, \%dirInfo);
            } elsif ($type eq 'EPS' or $type eq 'PS') {
                require Image::ExifTool::PostScript;
                $rtnVal = Image::ExifTool::PostScript::WritePS($self, \%dirInfo);
            } elsif ($type eq 'ICC') {
                require Image::ExifTool::ICC_Profile;
                $rtnVal = Image::ExifTool::ICC_Profile::WriteICC($self, \%dirInfo);
            } else {
                undef $rtnVal;  # flag that we don't write this type of file
            }
            # all done unless we got the wrong type
            last if $rtnVal;
            last unless @fileTypeList;
            # seek back to original position in files for next try
            unless ($raf->Seek($inPos, 0)) {
                $self->Error('Error seeking in file');
                last;
            }
            if (UNIVERSAL::isa($outRef,'GLOB')) {
                seek($outRef, 0, $outPos);
            } else {
                $$outRef = substr($$outRef, 0, $outPos);
            }
        }
        # print file format errors
        unless ($rtnVal) {
            if ($fileType and defined $rtnVal) {
                $self->{VALUE}->{Error} or $self->Error("Format error in file");
            } elsif ($fileType) {
                $self->Error("ExifTool does not yet support writing of $fileType files");
            } else {
                $self->Error('ExifTool does not support writing of this type of file');
            }
            $rtnVal = 0;
        }
       # $raf->Close(); # only used to force debug output
    }
    # don't return success code if any error occurred
    $rtnVal = 0 if $rtnVal > 0 and $self->{VALUE}->{Error};

    # rewrite original file in place if required
    if (defined $outBuff) {
        if ($rtnVal <= 0 or not $self->{CHANGED}) {
            # nothing changed, so no need to write $outBuff
        } elsif (UNIVERSAL::isa($inRef,'GLOB')) {
                my $len = length($outBuff);
                my $size;
                $rtnVal = -1 unless
                    seek($inRef, 0, 2) and          # seek to the end of file
                    ($size = tell $inRef) >= 0 and  # get the file size
                    seek($inRef, 0, 0) and          # seek back to the start
                    print $inRef $outBuff and       # write the new data
                    ($len >= $size or               # if necessary:
                    eval 'truncate($inRef, $len)'); #  shorten output file
        } else {
            $$inRef = $outBuff;                 # replace original data
        }
        $outBuff = '';  # free memory but leave $outBuff defined
    }
    # close input file if we opened it
    if ($closeIn) {
        # errors on input file are significant if we edited the file in place
        $rtnVal and $rtnVal = -1 unless close($inRef) or not defined $outBuff;
    }
    # close output file if we created it
    if ($closeOut) {
        # close file and set $rtnVal to -1 if there was an error
        $rtnVal and $rtnVal = -1 unless close($outRef);
        # erase the output file if we weren't successful
        $rtnVal > 0 or unlink $outfile;
    }
    # set FileModifyDate if requested (and if possible!)
    if (defined $fileModifyDate and $rtnVal > 0 and
        ($closeOut or ($closeIn and defined $outBuff)))
    {
        $self->SetFileModifyDate($closeOut ? $outfile : $infile, $originalTime);
    }
    # check for write error and set appropriate error message and return value
    if ($rtnVal < 0) {
        $self->Error('Error writing output file');
        $rtnVal = 0;    # return 0 on failure
    } elsif ($rtnVal > 0) {
        ++$rtnVal unless $self->{CHANGED};
    }
    # set things back to the way they were
    $self->{RAF} = $oldRaf;

    return $rtnVal;
}

#------------------------------------------------------------------------------
# Get list of all available tags for specified group
# Inputs: 0) optional group name
# Returns: tag list (sorted alphabetically)
# Notes: Can't get tags for specific IFD
sub GetAllTags(;$)
{
    local $_;
    my $group = shift;
    my (%allTags, $exifTool);

    $group and $exifTool = new Image::ExifTool;
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
                # don't list subdirectories unless they are writable
                next unless $$tagInfo{Writable} or not $$tagInfo{SubDirectory};
                if ($group) {
                    my @groups = $exifTool->GetGroup($tagInfo);
                    next unless grep /^$group$/i, @groups;
                }
                $allTags{$tag} = 1;
            }
        }
    }
    return sort keys %allTags;
}

#------------------------------------------------------------------------------
# Get list of all writable tags
# Inputs: 0) optional group name
# Returns: tag list (sorted alphbetically)
sub GetWritableTags(;$)
{
    local $_;
    my $group = shift;
    my (%writableTags, $exifTool);

    $group and $exifTool = new Image::ExifTool;
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
                my $writable = $$tagInfo{Writable};
                next unless $writable or ($table->{WRITABLE} and
                    not defined $writable and not $$tagInfo{SubDirectory});
                if ($group) {
                    my @groups = $exifTool->GetGroup($tagInfo);
                    next unless grep /^$group$/i, @groups;
                }
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
            if ($groups = $$table{GROUPS} and $group = $$groups{$family}) {
                $allGroups{$group} = 1;
            }
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
# Create directory for specified file
# Inputs: 0) complete file name including path
# Returns: 1 = directory created, 0 = nothing done, -1 = error
sub CreateDirectory($)
{
    local $_;
    my $file = shift;
    my $rtnVal = 0;
    my $dir;
    ($dir = $file) =~ s/[^\/]*$//;  # remove filename from path specification
    if ($dir and not -d $dir) {
        my @parts = split /\//, $dir;
        $dir = '';
        foreach (@parts) {
            $dir .= $_;
            if (length $dir and not -d $dir) {
                # create directory since it doesn't exist
                mkdir($dir, 0777) or return -1;
                $rtnVal = 1;
            }
            $dir .= '/';
        }
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Get new file name
# Inputs: 0) existing name, 1) new name
# Returns: new file path name
sub GetNewFileName($$)
{
    my ($oldName, $newName) = @_;
    my ($dir, $name) = ($oldName =~ m{(.*/)(.*)});
    ($dir, $name) = ('', $oldName) unless defined $dir;
    if ($newName =~ m{/$}) {
        $newName = "$newName$name"; # change dir only
    } elsif ($newName !~ m{/}) {
        $newName = "$dir$newName";  # change name only if newname doesn't specify dir
    }                               # else change dir and name
    return $newName;
}

#------------------------------------------------------------------------------
# Reverse hash lookup
# Inputs: 0) value, 1) hash reference
# Returns: Hash key or undef if not found (plus flag for multiple matches in list context)
sub ReverseLookup($$)
{
    my ($val, $conv) = @_;
    my $multi;
    if ($val =~ /^Unknown\s*\((.+)\)$/i) {
        $val = $1;    # was unknown
        if ($val =~ /^0x([\da-fA-F]+)$/) {
            $val = hex($val);   # convert hex value
        }
    } else {
        my @patterns = (
            "^\Q$val\E\$",      # exact match
            "^(?i)\Q$val\E\$",  # case-insensitive
            "^(?i)\Q$val\E",    # beginning of string
            "(?i)\Q$val\E",     # substring
        );
        my ($pattern, $found, $matches);
        foreach $pattern (@patterns) {
            $matches = scalar grep /$pattern/, values(%$conv);
            next unless $matches;
            # multiple matches are bad unless they were exact
            last if $matches > 1 and $pattern !~ /\$$/;
            foreach (sort keys %$conv) {
                if ($$conv{$_} =~ /$pattern/) {
                    $val = $_;
                    $found = 1;
                    last;
                }
            }
            last;
        }
        unless ($found) {
            undef $val;
            $multi = 1 if $matches > 1;
        }
    }
    if (wantarray) {
        return ($val, $multi);
    } else {
        return $val;
    }
}

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
    # apply time shift if necessary
    if (defined $newValueHash->{Shift}) {
        return -1 unless defined $value;
        my $type = $newValueHash->{TagInfo}->{Shift};
        my $shift = $newValueHash->{Shift};
        require 'Image/ExifTool/Shift.pl';
        my $err = ApplyShift($type, $shift, $value, $newValueHash);
        if ($err) {
            my $tag = $newValueHash->{TagInfo}->{Name};
            $newValueHash->{Self}->Warn("$err when shifting $tag");
            return 0;
        }
        # don't bother overwriting if value is the same
        return 0 if $value eq $newValueHash->{Value}->[0];
        return 1;
    }
    # never overwrite if DelValue list exists but is empty
    return 0 unless @{$newValueHash->{DelValue}};
    # return "don't know" if we don't have a value to test
    return -1 unless defined $value;
    # return 1 if value matches a DelValue
    my $val;
    foreach $val (@{$newValueHash->{DelValue}}) {
        return 1 if $value eq $val;
    }
    return 0;
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
    my ($self, $tagInfo, $writeGroup, $opts) = @_;
    my $saveHash = $self->{SAVE_NEW_VALUE};
    my $newValueHash = $self->{NEW_VALUE}->{$tagInfo};

    my %opts;   # quick lookup for options
    $opts and $opts{$opts} = 1;
    $writeGroup = '' unless defined $writeGroup;

    if ($writeGroup) {
        # find the new value in the list with the specified write group
        while ($newValueHash and $newValueHash->{WriteGroup} ne $writeGroup) {
            $newValueHash = $newValueHash->{Next};
        }
    }
    # remove this entry if deleting, or if creating a new entry and
    # this entry is marked with "Save" flag
    if (defined $newValueHash and ($opts{'delete'} or
        ($opts{'create'} and $saveHash and $newValueHash->{Save})))
    {
        my $firstHash = $self->{NEW_VALUE}->{$tagInfo};
        if ($newValueHash eq $firstHash) {
            # remove first entry from linked list
            if ($newValueHash->{Next}) {
                $self->{NEW_VALUE}->{$tagInfo} = $newValueHash->{Next};
            } else {
                delete $self->{NEW_VALUE}->{$tagInfo};
            }
        } else {
            # find the list element pointing to this hash
            $firstHash = $firstHash->{Next} while $firstHash->{Next} ne $newValueHash;
            # remove from linked list
            $firstHash->{Next} = $newValueHash->{Next};
        }
        # save the existing entry if necessary
        if ($saveHash and $newValueHash->{Save}) {
            # add to linked list of saved new value hashes
            $newValueHash->{Next} = $saveHash->{$tagInfo};
            $saveHash->{$tagInfo} = $newValueHash;
        }
        undef $newValueHash;
    }
    if (not defined $newValueHash and $opts{'create'}) {
        # create a new entry
        $newValueHash = {
            TagInfo => $tagInfo,
            WriteGroup => $writeGroup,
        };
        # add entry to our NEW_VALUE hash
        if ($self->{NEW_VALUE}->{$tagInfo}) {
            # add to end of linked list
            my $lastHash = LastInList($self->{NEW_VALUE}->{$tagInfo});
            $lastHash->{Next} = $newValueHash;
        } else {
            $self->{NEW_VALUE}->{$tagInfo} = $newValueHash;
        }
    }
    return $newValueHash;
}

#------------------------------------------------------------------------------
# Load all tag tables
sub LoadAllTables()
{
    unless ($loadedAllTables) {
        # load all of our non-referenced tables (first our modules)
        my $table;
        foreach $table (@loadAllTables) {
            my $tableName = "Image::ExifTool::$table";
            $tableName .= '::Main' unless $table =~ /:/;
            GetTagTable($tableName);
        }
        # (then our special tables)
        GetTagTable('Image::ExifTool::Extra');
        GetTagTable('Image::ExifTool::Composite');
        # recursively load all tables referenced by the current tables
        my @tableNames = ( keys %allTables );
        while (@tableNames) {
            $table = GetTagTable(pop @tableNames);
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
                # use tag name for directory name and save for next time
                $dirName = $$tagInfo{Name};
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
# Inputs: 0) ExifTool object reference, 1) File type string (or map hash ref)
sub InitWriteDirs($$)
{
    my ($self, $fileType) = @_;
    my $editDirs = $self->{EDIT_DIRS} = { };
    my $addDirs = $self->{ADD_DIRS} = { };
    my $fileDirs = $dirMap{$fileType};
    unless ($fileDirs) {
        return unless ref $fileType eq 'HASH';
        $fileDirs = $fileType;
    }
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
    if ($self->{DEL_GROUP}) {
        # add delete groups to list of edited groups
        foreach (keys %{$self->{DEL_GROUP}}) {
            my $dirName = $_;
            # translate necessary group 0 names
            $dirName = $translateWriteGroup{$dirName} if $translateWriteGroup{$dirName};
            while ($dirName) {
                my $parent = $$fileDirs{$dirName};
                $$editDirs{$dirName} = $parent;
                $dirName = $parent;     # go up one level
            }
        }
    }
    if ($self->{OPTIONS}->{Verbose}) {
        my $out = $self->{OPTIONS}->{TextOut};
        print $out "  Editing tags in: ";
        foreach (sort keys %$editDirs) { print $out "$_ "; }
        print $out "\n";
        return unless $self->{OPTIONS}->{Verbose} > 1;
        print $out "  Creating tags in: ";
        foreach (sort keys %$addDirs) { print $out "$_ "; }
        print $out "\n";
    }
}

#------------------------------------------------------------------------------
# Write an image directory
# Inputs: 0) ExifTool object reference, 1) source directory information reference
#         2) tag table reference, 3) optional reference to writing procedure
# Returns: New directory data or undefined on error
sub WriteDirectory($$$;$)
{
    my ($self, $dirInfo, $tagTablePtr, $writeProc) = @_;

    $tagTablePtr or return undef;
    my $out;
    $out = $self->{OPTIONS}->{TextOut} if $self->{OPTIONS}->{Verbose};
    # set directory name from default group0 name if not done already
    my $dirName = $$dirInfo{DirName};
    my $grp0 = $tagTablePtr->{GROUPS}->{0};
    $dirName or $dirName = $$dirInfo{DirName} = $grp0;
    if ($self->{DEL_GROUP}) {
        my $delGroupPtr = $self->{DEL_GROUP};
        # delete entire directory if specified
        my $grp1 = $dirName;
        if ($$delGroupPtr{$grp0} or $$delGroupPtr{$grp1}) {
            if ($self->{FILE_TYPE} ne 'JPEG' and $self->{FILE_TYPE} ne 'PNG') {
                # restrict delete logic to prevent entire tiff image from being killed
                # (don't allow IFD0 to be deleted, and delete only ExifIFD if EXIF specified)
                if ($grp1 eq 'IFD0') {
                    $$delGroupPtr{IFD0} and $self->Warn("Can't delete IFD0 from $self->{FILE_TYPE} image",1);
                    undef $grp1;
                } elsif ($grp0 eq 'EXIF' and $$delGroupPtr{$grp0}) {
                    undef $grp1 unless $$delGroupPtr{$grp1} or $grp1 eq 'ExifIFD';
                }
            }
            if ($grp1) {
                ++$self->{CHANGED};
                $out and print $out "  Deleting $grp1\n";
                # can no longer validate TIFF_END if deleting an entire IFD
                delete $self->{TIFF_END} if $dirName =~ /IFD/;
                return '';
            }
        }
    }
    # copy or delete new directory as a block if specified
    my $tagInfo = $Image::ExifTool::Extra{$grp0};
    if ($tagInfo and $self->{NEW_VALUE}->{$tagInfo}) {
        my $newVal = GetNewValues($self->{NEW_VALUE}->{$tagInfo});
        if (defined $newVal and length $newVal) {
            $out and print $out "  Writing $grp0 as a block\n";
            ++$self->{CHANGED};
            return $newVal;
        } else {
            $out and print $out "  Deleting $grp0 as a block\n";
            ++$self->{CHANGED};
            return '';
        }
    }
    # use default proc from tag table if no proc specified
    $writeProc or $writeProc = $$tagTablePtr{WRITE_PROC} or return undef;
    # guard against writing the same directory twice
    if (defined $$dirInfo{DataPt} and defined $$dirInfo{DirStart} and defined $$dirInfo{DataPos}) {
        my $addr = $$dirInfo{DirStart} + $$dirInfo{DataPos} + ($$dirInfo{Base}||0);
        if ($self->{PROCESSED}->{$addr}) {
            if ($self->Error("$dirName pointer references previous $self->{PROCESSED}->{$addr} directory", 1)) {
                return undef;
            } else {
                $self->Warn("Deleting duplicate $dirName directory");
                $out and print $out "  Deleting $dirName\n";
                return '';  # delete the duplicate directory
            }
        }
        $self->{PROCESSED}->{$addr} = $dirName;
    }
    # be sure the tag ID's are generated, because the write proc will need them
    GenerateTagIDs($tagTablePtr);
    my $oldDir = $self->{DIR_NAME};
    if ($out and (not defined $oldDir or $oldDir ne $dirName)) {
        my $verb = ($$dirInfo{DataPt} or $$dirInfo{DirLen}) ? 'Rewriting' : 'Creating';
        print $out "  $verb $dirName\n";
    }
    my $saveOrder = GetByteOrder();
    $self->{DIR_NAME} = $dirName;
    my $newData = &$writeProc($self, $dirInfo, $tagTablePtr);
    $self->{DIR_NAME} = $oldDir;
    SetByteOrder($saveOrder);
    print $out "  Deleting $dirName\n" if $out and defined $newData and not length $newData;
    return $newData;
}

#------------------------------------------------------------------------------
# Uncommon utility routines to for reading binary data values
# Inputs: 0) data reference, 1) offset into data
sub Get64s($$)
{
    my ($dataPt, $pos) = @_;
    my $pt = GetByteOrder() eq 'MM' ? 0 : 4;    # get position of high word
    my $hi = Get32s($dataPt, $pos + $pt);       # preserve sign bit of high word
    my $lo = Get32u($dataPt, $pos + 4 - $pt);
    return $hi * 4294967296 + $lo;
}
sub Get64u($$)
{
    my ($dataPt, $pos) = @_;
    my $pt = GetByteOrder() eq 'MM' ? 0 : 4;    # get position of high word
    my $hi = Get32u($dataPt, $pos + $pt);       # (unsigned this time)
    my $lo = Get32u($dataPt, $pos + 4 - $pt);
    return $hi * 4294967296 + $lo;
}
# Decode extended 80-bit float used by Apple SANE and Intel 8087
# (note: different than the IEEE standard 80-bit float)
sub GetExtended($$)
{
    my ($dataPt, $pos) = @_;
    my $pt = GetByteOrder() eq 'MM' ? 0 : 2;    # get position of exponent
    my $exp = Get16u($dataPt, $pos + $pt);
    my $sig = Get64u($dataPt, $pos + 2 - $pt);  # get significand as int64u
    my $sign = $exp & 0x8000 ? -1 : 1;
    $exp = ($exp & 0x7fff) - 16383 - 63; # (-63 to fractionalize significand)
    return $sign * $sig * 2 ** $exp;
}

#------------------------------------------------------------------------------
# Dump data in hex and ASCII to console
# Inputs: 0) data reference, 1) length or undef, 2-N) Options:
# Options: Start => offset to start of data (default=0)
#          Addr => address to print for data start (default=DataPos+Start)
#          DataPos => address of start of data
#          Width => width of printout (bytes, default=16)
#          Prefix => prefix to print at start of line (default='')
#          MaxLen => maximum length to dump
#          Out => output file reference
sub HexDump($;$%)
{
    my $dataPt = shift;
    my $len    = shift;
    my %opts   = @_;
    my $start  = $opts{Start}  || 0;
    my $addr   = $opts{Addr}   || $start + ($opts{DataPos} || 0);
    my $wid    = $opts{Width}  || 16;
    my $prefix = $opts{Prefix} || '';
    my $out    = $opts{Out}    || \*STDOUT;
    my $maxLen = $opts{MaxLen};
    my $datLen = length($$dataPt) - $start;
    my $more;

    if (not defined $len) {
        $len = $datLen;
    } elsif ($len > $datLen) {
        print $out "$prefix    Warning: Attempted dump outside data\n";
        print $out "$prefix    ($len bytes specified, but only $datLen available)\n";
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
        printf $out "$prefix%8.4x: ", $addr+$i;
        my $dat = substr($$dataPt, $i+$start, $wid);
        my $s = join(' ',(unpack('H*',$dat) =~ /../g));
        printf $out $format, $s;
        $dat =~ tr /\x00-\x1f\x7f-\xff/./;
        print $out "[$dat]\n";
    }
    $more and printf $out "$prefix    [snip $more bytes]\n";
}

#------------------------------------------------------------------------------
# Print verbose tag information
# Inputs: 0) ExifTool object reference, 1) tag ID
#         2) tag info reference (or undef)
#         3-N) extra parms:
# Parms: Index => Index of tag in menu (starting at 0)
#        Value => Tag value
#        DataPt => reference to value data block
#        DataPos => location of data block in file
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
    my $out = $self->{OPTIONS}->{TextOut};
    my ($tag, $tagDesc, $line, $hexID);

    # generate hex number if tagID is numerical
    if (defined $tagID) {
        $tagID =~ /^\d+$/ and $hexID = sprintf("0x%.4x", $tagID);
    } else {
        $tagID = 'Unknown';
    }
    # get tag name
    if ($tagInfo and $$tagInfo{Name}) {
        $tag = $$tagInfo{Name};
    } else {
        my $prefix;
        $prefix = $parms{Table}->{TAG_PREFIX} if $parms{Table};
        if ($prefix or $hexID) {
            $prefix = 'Unknown' unless $prefix;
            $tag = $prefix . '_' . ($hexID ? $hexID : $tagID);
        } else {
            $tag = $tagID;
        }
    }
    my $dataPt = $parms{DataPt};
    my $size = $parms{Size};
    $size = length $$dataPt unless defined $size or not $dataPt;
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
    print $out "$line\n";

    # Level 2: print detailed information about the tag
    if ($verbose > 1 and ($parms{Extra} or $parms{Format} or
        $parms{DataPt} or defined $size or $tagID =~ /\//))
    {
        $line = $indent;
        $line .= '- Tag ' . ($hexID ? $hexID : "'$tagID'");
        $line .= $parms{Extra} if defined $parms{Extra};
        my $format = $parms{Format};
        if ($format or defined $size) {
            $line .= ' (';
            if (defined $size) {
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
        print $out "$line\n";
    }

    # Level 3: do hex dump of value
    if ($verbose > 2 and $parms{DataPt}) {
        $parms{Out} = $out;
        $parms{Prefix} = $indent;
        # limit dump length unless verbose > 3
        $parms{MaxLen} = 96 unless $verbose > 3;
        HexDump($dataPt, $size, %parms);
    }
}

#------------------------------------------------------------------------------
# Find last element in linked list
# Inputs: 0) element in list
# Returns: Last element in list
sub LastInList($)
{
    my $element = shift;
    while ($element->{Next}) {
        $element = $element->{Next};
    }
    return $element;
}

#------------------------------------------------------------------------------
# Print verbose directory information
# Inputs: 0) ExifTool object reference, 1) directory name
#         2) number of entries in directory (or 0 if unknown)
#         3) optional size of directory in bytes
sub VerboseDir($$;$$)
{
    my ($self, $name, $entries, $size) = @_;
    my $indent = substr($self->{INDENT}, 0, -2);
    my $out = $self->{OPTIONS}->{TextOut};
    my $str;
    if ($entries) {
        $str = " with $entries entries";
    } elsif ($size) {
        $str = ", $size bytes";
    } else {
        $str = '';
    }
    print $out "$indent+ [$name directory$str]\n";
}

#------------------------------------------------------------------------------
# convert unicode characters to Windows Latin1 (cp1252)
# Inputs: 0) 16-bit unicode character string, 1) unpack format
# Returns: 8-bit Windows Latin1 encoded string
my %unicode2latin = (
    0x20ac => 0x80,  0x0160 => 0x8a,  0x2013 => 0x96,
    0x201a => 0x82,  0x2039 => 0x8b,  0x2014 => 0x97,
    0x0192 => 0x83,  0x0152 => 0x8c,  0x02dc => 0x98,
    0x201e => 0x84,  0x017d => 0x8e,  0x2122 => 0x99,
    0x2026 => 0x85,  0x2018 => 0x91,  0x0161 => 0x9a,
    0x2020 => 0x86,  0x2019 => 0x92,  0x203a => 0x9b,
    0x2021 => 0x87,  0x201c => 0x93,  0x0153 => 0x9c,
    0x02c6 => 0x88,  0x201d => 0x94,  0x017e => 0x9e,
    0x2030 => 0x89,  0x2022 => 0x95,  0x0178 => 0x9f,
);
sub Unicode2Latin($$)
{
    my ($val, $fmt) = @_;
    my @uni = unpack("$fmt*",$val);
    foreach (@uni) {
        $_ = $unicode2latin{$_} || ord('?') if $_ > 0xff;
    }
    # repack as a Latin string
    my $outVal = pack('C*',@uni);
    $outVal =~ s/\0.*//s;    # truncate at null terminator
    return $outVal;
}

#------------------------------------------------------------------------------
# convert Windows Latin1 characters to unicode
# Inputs: 0) 8-bit Windows Latin1 character string (cp1252), 1) unpack format
# Returns: 16-bit unicode character string
my %latin2unicode;
sub Latin2Unicode($$)
{
    # create reverse lookup table if necessary
    unless (%latin2unicode) {
        foreach (keys %unicode2latin) {
            $latin2unicode{$unicode2latin{$_}} = $_;
        }
    }
    my ($val, $fmt) = @_;
    my @latin = unpack('C*',$val);
    foreach (@latin) {
        $_ = $latin2unicode{$_} if $latin2unicode{$_};
    }
    # repack as a 16-bit unicode string (plus null terminator)
    my $outVal = pack("$fmt*",@latin) . "\0\0";
    return $outVal;
}

#------------------------------------------------------------------------------
# convert 16-bit unicode characters to UTF-8
# Inputs: 0) 16-bit unicode character string, 1) short unpack format
# Returns: UTF-8 encoded string
# Notes: Only works for Perl 5.6.1 or later
sub Unicode2UTF8($$)
{
    my ($val, $fmt) = @_;
    my $outVal;
    # repack as a UTF-8 string
    $outVal = pack('C0U*',unpack("$fmt*",$val));
    $outVal =~ s/\0.*//s;    # truncate at null terminator
    return $outVal;
}

#------------------------------------------------------------------------------
# convert UTF-8 encoded string to 16-bit unicode (Perl 5.6.1 or later)
# Input: 0) UTF-8 string, 1) short unpack format
# Returns: 16-bit unicode character string
sub UTF82Unicode($$)
{
    my ($str, $fmt) = @_;
    # repack UTF-8 string as 16-bit integers
    $str = pack("$fmt*",unpack('U0U*',$str)) . "\0\0";
    return $str;
}

#------------------------------------------------------------------------------
# convert 16-bit unicode character string to 8-bit (Latin or UTF-8)
# Inputs: 0) ExifTool object reference, 1) 16-bit unicode string (in specified byte order)
#         2) Optional byte order (current byte order used if not specified)
# Returns: 8-bit character string
my %unpackShort = ( 'II' => 'v', 'MM' => 'n' );
sub Unicode2Byte($$;$) {
    my ($self, $val, $byteOrder) = @_;
    # check for (and remove) byte order mark and set byte order accordingly if it exists
    $val =~ s/^(\xff\xfe|\xfe\xff)// and $byteOrder = ($1 eq "\xff\xfe") ? 'MM' : 'II';
    my $fmt = $unpackShort{$byteOrder || GetByteOrder()};
    # convert to Latin if specified or if no UTF-8 support in this Perl version
    if ($self->Options('Charset') eq 'Latin' or $] < 5.006001) {
        return Unicode2Latin($val, $fmt);
    } else {
        return Unicode2UTF8($val, $fmt);
    }
}

#------------------------------------------------------------------------------
# convert 8-bit character string to 16-bit unicode
# Inputs: 0) ExifTool object reference, 1) Latin or UTF-8 string, 2) optional byte order
# Returns: 16-bit unicode character string (in specified byte order)
sub Byte2Unicode($$;$)
{
    my ($self, $val, $byteOrder) = @_;
    my $fmt = $unpackShort{$byteOrder || GetByteOrder()};
    if ($self->Options('Charset') eq 'Latin' or $] < 5.006001) {
        return Latin2Unicode($val, $fmt);
    } else {
        return UTF82Unicode($val, $fmt);
    }
}

#------------------------------------------------------------------------------
# assemble a continuing fraction into a rational value
# Inputs: 0) numerator, 1) denominator
#         2-N) list of fraction denominators, deepest first
# Returns: numerator, denominator (in list context)
sub AssembleRational($$@)
{
    @_ < 3 and return @_;
    my ($num, $denom, $frac) = splice(@_, 0, 3);
    return AssembleRational($frac*$num+$denom, $num, @_);
}

#------------------------------------------------------------------------------
# convert a floating point number into a rational
# Inputs: 0) floating point number, 1) optional maximum value (defaults to 0x7fffffff)
# Returns: numerator, denominator (in list context)
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
# Inputs: 0) value, 1) data ref, 2) offset
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
sub SetRational64u($;$$) {
    my ($numer,$denom) = Rationalize($_[0],0xffffffff);
    my $val = Set32u($numer) . Set32u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational64s($;$$) {
    my ($numer,$denom) = Rationalize($_[0]);
    my $val = Set32s($numer) . Set32u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational32u($;$$) {
    my ($numer,$denom) = Rationalize($_[0],0xffff);
    my $val = Set16u($numer) . Set16u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational32s($;$$) {
    my ($numer,$denom) = Rationalize($_[0],0xffff);
    my $val = Set16s($numer) . Set16u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetFloat($;$$) {
    my $val = SwapBytes(pack('f',$_[0]), 4);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetDouble($;$$) {
    # swap 32-bit words (ARM quirk) and bytes if necessary
    my $val = SwapBytes(SwapWords(pack('d',$_[0])), 8);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
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
    rational32s => \&SetRational32s,
    rational32u => \&SetRational32u,
    rational64s => \&SetRational64s,
    rational64u => \&SetRational64u,
    float => \&SetFloat,
    double => \&SetDouble,
    ifd => \&Set32u,
);
# verify that we can write floats on this platform
{
    my %writeTest = (
        float =>  [ -3.14159, 'c0490fd0' ],
        double => [ -3.14159, 'c00921f9f01b866e' ],
    );
    my $format;
    my $oldOrder = GetByteOrder();
    SetByteOrder('MM');
    foreach $format (keys %writeTest) {
        my ($val, $hex) = @{$writeTest{$format}};
        # add floating point entries if we can write them
        next if unpack('H*', &{$writeValueProc{$format}}($val)) eq $hex;
        delete $writeValueProc{$format};    # we can't write them
    }
    SetByteOrder($oldOrder);
}

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
        if ($count) {
            $count = @vals if $count < 0;
        } else {
            $count = 1;   # assume 1 if count not specified
        }
        $packed = '';
        while ($count--) {
            $val = shift @vals;
            #warn...
            return undef unless defined $val;
            # validate numerical formats
            if ($format =~ /^int/) {
                return undef unless IsInt($val) or IsHex($val);
            } else {
                return undef unless IsFloat($val);
            }
            $packed .= &$proc($val);
        }
    } elsif ($format eq 'string' or $format eq 'undef') {
        $format eq 'string' and $val .= "\0";   # null-terminate strings
        if ($count and $count > 0) {
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
        warn "Sorry, Can't write $format values on this platform";
        return undef;
    }
    $dataPt and substr($$dataPt, $offset, length($packed)) = $packed;
    return $packed;
}

#------------------------------------------------------------------------------
# Encode bit mask (the inverse of DecodeBits())
# Inputs: 0) value to encode, 1) Reference to hash for encoding
# Returns: bit mask or undef on error (plus error string in list context)
sub EncodeBits($$)
{
    my ($val, $lookup) = @_;
    my $outVal = 0;
    if ($val ne '(none)') {
        my @vals = split /\s*,\s*/, $val;
        foreach $val (@vals) {
            my $bit = ReverseLookup($val, $lookup);
            unless (defined $bit) {
                if ($val =~ /\[(\d+)\]/) { # numerical bit specification
                    $bit = $1;
                } else {
                    # don't return error string unless more than one value
                    return undef unless @vals > 1 and wantarray;
                    return (undef, "no match for '$val'");
                }
            }
            $outVal |= (1 << $bit);
        }
    }
    return $outVal;
}

#------------------------------------------------------------------------------
# get current position in output file
# Inputs: 0) file or scalar reference
# Returns: Current position or -1 on error
sub Tell($)
{
    my $outfile = shift;
    if (UNIVERSAL::isa($outfile,'GLOB')) {
        return tell($outfile);
    } else {
        return length($$outfile);
    }
}

#------------------------------------------------------------------------------
# write to file or memory
# Inputs: 0) file or scalar reference, 1-N) list of stuff to write
# Returns: true on success
sub Write($@)
{
    my $outfile = shift;
    if (UNIVERSAL::isa($outfile,'GLOB')) {
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
#         2) segment header, 3) segment data ref, 4) segment type
# Returns: number of segments written, or 0 on error
sub WriteMultiSegment($$$$;$)
{
    my ($outfile, $marker, $header, $dataPt, $type) = @_;
    $type or $type = '';
    my $len = length($$dataPt);
    my $hdr = "\xff" . chr($marker);
    my $count = 0;
    my $maxLen = $maxSegmentLen - length($header);
    $maxLen -= 2 if $type eq 'ICC'; # leave room for segment counters
    my $num = int(($len + $maxLen - 1) / $maxLen);  # number of segments to write
    my $n;
    # write data, splitting into multiple segments if necessary
    # (each segment gets its own header)
    for ($n=0; $n<$len; $n+=$maxLen) {
        ++$count;
        my $size = $len - $n;
        $size > $maxLen and $size = $maxLen;
        my $buff = substr($$dataPt,$n,$size);
        $size += length($header);
        if ($type eq 'ICC') {
            $buff = pack('CC', $count, $num) . $buff;
            $size += 2;
        }
        # write the new segment with appropriate header
        my $segHdr = $hdr . pack('n', $size + 2);
        Write($outfile, $segHdr, $header, $buff) or return 0;
    }
    return $count;
}

#------------------------------------------------------------------------------
# WriteJPEG : Write JPEG image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid JPEG file, or -1 if
#          an output file was specified and a write error occurred
sub WriteJPEG($$)
{
    my ($self, $dirInfo) = @_;
    my $outfile = $$dirInfo{OutFile};
    my $raf = $$dirInfo{RAF};
    my ($ch,$s,$length);
    my $verbose = $self->{OPTIONS}->{Verbose};
    my $out = $self->{OPTIONS}->{TextOut};
    my $rtnVal = 0;
    my ($err, %doneDir);
    my %dumpParms = ( Out => $out );
    my ($writeBuffer, $oldOutfile); # used to buffer writing until PreviewImage position is known

    # check to be sure this is a valid JPG file
    return 0 unless $raf->Read($s,2) == 2 and $s eq "\xff\xd8";
    $dumpParms{MaxLen} = 128 unless $verbose > 3;

    delete $self->{PREVIEW_INFO};   # reset preview information
    delete $self->{DEL_PREVIEW};    # reset flag to delete preview

    Write($outfile, $s) or $err = 1;
    # figure out what segments we need to write for the tags we have set
    my $addDirs = $self->{ADD_DIRS};
    my $editDirs = $self->{EDIT_DIRS};

    # set input record separator to 0xff (the JPEG marker) to make reading quicker
    my $oldsep = $/;
    $/ = "\xff";
#
# pre-scan image to determine existing segments/directories
#
    my $pos = $raf->Tell();
    my ($marker, @dirOrder, %dirCount);
    Prescan: for (;;) {
        # read up to next marker (JPEG markers begin with 0xff)
        $raf->ReadLine($s) or last;
        # JPEG markers can be padded with unlimited 0xff's
        for (;;) {
            $raf->Read($ch, 1) or last Prescan;
            $marker = ord($ch);
            last unless $marker == 0xff;
        }
        # SOS signifies end of meta information
        if ($marker == 0xda) {
            push(@dirOrder, 'SOS');
            $dirCount{SOS} = 1;
            last;
        }
        my $dirName;
        # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
        if (($marker & 0xf0) == 0xc0 and ($marker == 0xc0 or $marker & 0x03)) {
            last unless $raf->Seek(7, 1);
        # read data for all markers except stand-alone
        # markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
        } elsif ($marker!=0x00 and $marker!=0x01 and ($marker<0xd0 or $marker>0xd7)) {
            # read record length word
            last unless $raf->Read($s, 2) == 2;
            my $len = unpack('n',$s);   # get data length
            last unless defined($len) and $len >= 2;
            $len -= 2;  # subtract size of length word
            if (($marker & 0xf0) == 0xe0) {  # is this an APP segment?
                my $n = $len < 64 ? $len : 64;
                $raf->Read($s, $n) == $n or last;
                $len -= $n;
                if ($marker == 0xe0) {
                    $s =~ /^JFIF\0/        and $dirName = 'JFIF';
                    $s =~ /^JFXX\0\x10/    and $dirName = 'JFXX';
                } elsif ($marker == 0xe1) {
                    $s =~ /^$exifAPP1hdr/  and $dirName = 'IFD0';
                    $s =~ /^$xmpAPP1hdr/   and $dirName = 'XMP';
                } elsif ($marker == 0xe2) {
                    $s =~ /^ICC_PROFILE\0/ and $dirName = 'ICC_Profile';
                } elsif ($marker == 0xed) {
                    $s =~ /^$psAPP13hdr/   and $dirName = 'Photoshop';
                }
                # don't add directory if it already exists
                delete $$addDirs{$dirName} if defined $dirName;
            }
            $raf->Seek($len, 1) or last;
        }
        $dirName or $dirName = JpegMarkerName($marker);
        $dirCount{$dirName} = ($dirCount{$dirName} || 0) + 1;
        push @dirOrder, $dirName;
    }
    $marker == 0xda or $self->Error('Corrupted JPEG image'), return 1;
    $raf->Seek($pos, 0) or $self->Error('Seek error'), return 1;
#
# re-write the image
#    
    my ($combinedSegData, $segPos);
    # read through each segment in the JPEG file
    Marker: for (;;) {

        # read up to next marker (JPEG markers begin with 0xff)
        my $segJunk;
        $raf->ReadLine($segJunk);
        # remove the 0xff but write the rest of the junk up to this point
        chomp($segJunk);
        Write($outfile, $segJunk) if length $segJunk;
        # JPEG markers can be padded with unlimited 0xff's
        for (;;) {
            $raf->Read($ch, 1) or $self->Error('Format error'), return 1;
            $marker = ord($ch);
            last unless $marker == 0xff;
        }
        # read the segment data
        my $segData;
        # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
        if (($marker & 0xf0) == 0xc0 and ($marker == 0xc0 or $marker & 0x03)) {
            last unless $raf->Read($segData, 7) == 7;
        # read data for all markers except stand-alone
        # markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
        } elsif ($marker!=0x00 and $marker!=0x01 and ($marker<0xd0 or $marker>0xd7)) {
            # read record length word
            last unless $raf->Read($s, 2) == 2;
            my $len = unpack('n',$s);   # get data length
            last unless defined($len) and $len >= 2;
            $segPos = $raf->Tell();
            $len -= 2;  # subtract size of length word
            last unless $raf->Read($segData, $len) == $len;
        }
        # initialize variables for this segment
        my $hdr = "\xff" . chr($marker);    # segment header
        my $markerName = JpegMarkerName($marker);
        my $dirName = shift @dirOrder;      # get directory name
#
# create all segments that must come before this one
# (nothing comes before SOI or after SOS)
#
        while ($markerName ne 'SOI') {
            # don't create anything before APP0 or EXIF APP1 (containing IFD0)
            last if $markerName eq 'APP0' or $dirCount{IFD0};
            # EXIF information must come immediately after APP0
            if (exists $$addDirs{IFD0} and not $doneDir{IFD0}) {
                $doneDir{IFD0} = 1;
                $verbose and print $out "Creating APP1:\n";
                # write new EXIF data
                $self->{TIFF_TYPE} = 'APP1';
                my $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
                # use specified byte ordering or ordering from maker notes if set
                my $byteOrder = $self->Options('ByteOrder') || $self->{MAKER_NOTE_BYTE_ORDER} || 'MM';
                unless (SetByteOrder($byteOrder)) {
                    warn "Invalid byte order '$byteOrder'\n";
                    $byteOrder = $self->{MAKER_NOTE_BYTE_ORDER} || 'MM';
                    SetByteOrder($byteOrder);
                }
                my %dirInfo = (
                    NewDataPos => 8,    # new data will come after TIFF header
                    DirName => 'IFD0',
                    Parent  => $markerName,
                    Multi   => 1,
                );
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                if (defined $buff and length $buff) {
                    my $tiffHdr = $byteOrder . Set16u(42) . Set32u(8); # standard TIFF header
                    my $size = length($buff) + length($tiffHdr) + length($exifAPP1hdr);
                    if ($size <= $maxSegmentLen) {
                        # switch to buffered output if required
                        if ($self->{PREVIEW_INFO} and not $oldOutfile) {
                            $writeBuffer = '';
                            $oldOutfile = $outfile;
                            $outfile = \$writeBuffer;
                            # account for segment,EXIF and TIFF headers
                            $self->{PREVIEW_INFO}->{Fixup}->{Start} += 18;
                        }
                        # write the new segment with appropriate header
                        my $app1hdr = "\xff\xe1" . pack('n', $size + 2);
                        Write($outfile,$app1hdr,$exifAPP1hdr,$tiffHdr,$buff) or $err = 1;
                    } else {
                        delete $self->{PREVIEW_INFO};
                        $self->Warn("EXIF APP1 segment too large! ($size bytes)");
                    }
                }
            }
            # Photoshop APP13 segment next
            last if $dirCount{Photoshop};
            if (exists $$addDirs{Photoshop} and not $doneDir{Photoshop}) {
                $doneDir{Photoshop} = 1;
                $verbose and print $out "Creating APP13:\n";
                # write new Photoshop APP13 record to memory
                my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                my %dirInfo = (
                    Parent => $markerName,
                );
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                if (defined $buff and length $buff) {
                    WriteMultiSegment($outfile, 0xed, $psAPP13hdr, \$buff) or $err = 1;
                    ++$self->{CHANGED};
                }
            }
            # then XMP APP1 segment
            last if $dirCount{XMP};
            if (exists $$addDirs{XMP} and not $doneDir{XMP}) {
                $doneDir{XMP} = 1;
                $verbose and print $out "Creating APP1:\n";
                # write new XMP data
                my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                my %dirInfo = (
                    Parent   => $markerName,
                );
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
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
            # then ICC_Profile APP2 segment
            last if $dirCount{ICC_Profile};
            if (exists $$addDirs{ICC_Profile} and not $doneDir{ICC_Profile}) {
                $doneDir{ICC_Profile} = 1;
                next if $self->{DEL_GROUP} and $self->{DEL_GROUP}->{ICC_Profile};
                $verbose and print $out "Creating APP2:\n";
                # write new ICC_Profile data
                my $tagTablePtr = GetTagTable('Image::ExifTool::ICC_Profile::Main');
                my %dirInfo = (
                    Parent   => $markerName,
                );
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                if (defined $buff and length $buff) {
                    WriteMultiSegment($outfile, 0xe2, "ICC_PROFILE\0", \$buff, 'ICC') or $err = 1;
                    ++$self->{CHANGED};
                }
            }
            # finally, COM segment
            last if $dirCount{COM};
            if (exists $$addDirs{COM} and not $doneDir{COM}) {
                $doneDir{COM} = 1;
                next if $self->{DEL_GROUP} and $self->{DEL_GROUP}->{File};
                my $newComment = $self->GetNewValues('Comment');
                if (defined $newComment and length($newComment)) {
                    $verbose and print $out "Creating COM:\n";
                    $verbose > 1 and print $out "    + Comment = '$newComment'\n";
                    WriteMultiSegment($outfile, 0xfe, '', \$newComment) or $err = 1;
                    ++$self->{CHANGED};
                }
            }
            last;   # didn't want to loop anyway
        }
        # decrement counter for this directory since we are about to process it
        --$dirCount{$dirName};
#
# rewrite existing segments
#
        # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
        if (($marker & 0xf0) == 0xc0 and ($marker == 0xc0 or $marker & 0x03)) {
            $verbose and print $out "JPEG $markerName:\n";
            Write($outfile, $hdr, $segData) or $err = 1;
            next;
        } elsif ($marker == 0xda) {             # SOS
            $verbose and print $out "JPEG SOS (end of parsing)\n";
            # write SOS segment
            $s = pack('n', length($segData) + 2);
            Write($outfile, $hdr, $s, $segData) or $err = 1;
            my ($buff, $endPos, %afcpInfo);
            my $isAFCP = IsAFCP($raf);
            my $delPreview = $self->{DEL_PREVIEW};
            if ($oldOutfile or $delPreview or $isAFCP) {
                # write the rest of the image (as quickly as possible) up to the EOI
                my $endedWithFF;
                for (;;) {
                    my $n = $raf->Read($buff, 65536) or last Marker;
                    if (($endedWithFF and $buff =~ m/^\xd9/sg) or
                        $buff =~ m/\xff\xd9/sg)
                    {
                        $rtnVal = 1; # the JPEG is OK
                        # write up to the EOI
                        my $pos = pos($buff);
                        Write($outfile, substr($buff, 0, $pos)) or $err = 1;
                        $buff = substr($buff, $pos);
                        last;
                    }
                    unless ($n == 65536) {
                        $self->Error('JPEG EOI marker not found');
                        last Marker;
                    }
                    Write($outfile, $buff) or $err = 1;
                    $endedWithFF = substr($buff, 65535, 1) eq "\xff" ? 1 : 0;
                }
                # remember position of last data copied
                $endPos = $raf->Tell() - length($buff);
                if ($isAFCP) {
                    # rewrite AFCP directory (to memory for now)
                    require Image::ExifTool::AFCP;
                    require Image::ExifTool::Fixup;
                    $raf->Seek(-length($buff), 1);  # seek to end of JPEG image
                    my $afcpData = '';
                    $afcpInfo{RAF} = $raf;
                    $afcpInfo{OutFile} = \$afcpData;
                    $afcpInfo{Fixup} = new Image::ExifTool::Fixup;
                    $afcpInfo{ScanForAFCP} = 1;
                    my $result = Image::ExifTool::AFCP::ProcessAFCP($self, \%afcpInfo);
                    if ($result <=  0) {
                        $self->Error('Error rewriting AFCP trailer', 1);
                        undef %afcpInfo;
                    }
                }
                if ($oldOutfile) {
                    # locate preview image and fix up preview offsets
                    if (length($buff) < 1024) { # make sure we have at least 1kB of trailer
                        my $buf2;
                        $buff .= $buf2 if $raf->Read($buf2, 1024);
                    }
                    # get new preview image position (subtract 10 for segment and EXIF headers)
                    my $newPos = length($$outfile) - 10;
                    my $junkLen;
                    # adjust position if image isn't at the start (ie. Olympus E-1/E-300)
                    if ($buff =~ m/\xff\xd8\xff/sg) {
                        $junkLen = pos($buff) - 3;
                        $newPos += $junkLen;
                    }
                    # fix up the preview offsets to point to the start of the new image
                    my $previewInfo = $self->{PREVIEW_INFO};
                    delete $self->{PREVIEW_INFO};
                    my $fixup = $previewInfo->{Fixup};
                    $newPos += ($previewInfo->{BaseShift} || 0);
                    if ($previewInfo->{Relative}) {
                        # adjust for our base by looking at how far the pointer got shifted
                        $newPos -= $fixup->GetMarkerPointers($outfile, 'PreviewImage');
                    }
                    $fixup->SetMarkerPointers($outfile, 'PreviewImage', $newPos);
                    # clean up and write the buffered data
                    $outfile = $oldOutfile;
                    undef $oldOutfile;
                    Write($outfile, $writeBuffer) or $err = 1;
                    undef $writeBuffer;
                    # write preview image
                    if ($previewInfo->{Data} ne 'LOAD') {
                        # write any junk that existed before the preview image
                        Write($outfile, substr($buff,0,$junkLen)) or $err = 1 if $junkLen;
                        # write the saved preview image
                        Write($outfile, $previewInfo->{Data}) or $err = 1;
                        delete $previewInfo->{Data};
                        ++$self->{CHANGED};
                        $delPreview = 1;    # remove old preview
                    }
                }
            } else {
                $endPos = $raf->Tell();
                $rtnVal = 1;    # success unless we have a file write error
            }
            # copy over preview image if necessary
            unless ($delPreview) {
                my $writeTo;
                if (%afcpInfo) {
                    $writeTo = $afcpInfo{DataPos};  # write up to AFCP
                } else {
                    $raf->Seek(0, 2) or $err = 1;
                    $writeTo = $raf->Tell();        # write rest of file
                }
                $raf->Seek($endPos, 0) or $err = 1;
                while ($endPos < $writeTo) {
                    my $n = $writeTo - $endPos;
                    $n > 65536 and $n = 65536;
                    ($raf->Read($buff, $n) == $n and Write($outfile, $buff)) or $err = 1;
                    $endPos += $n;
                }
            }
            # write AFCP trailer if necessary
            if (%afcpInfo) {
                my $pos = Tell($outfile);
                my $afcpPt = $afcpInfo{OutFile};
                if ($pos > 0) {
                    # shift offsets to final AFCP location and write it out
                    $afcpInfo{Fixup}->{Shift} += $pos;
                    $afcpInfo{Fixup}->ApplyFixup($afcpPt);
                } else {
                    $self->Error("Can't get file position for fixing up AFCP offsets",1);
                }
                Write($outfile, $$afcpPt) or $err = 1;
            }
            last;   # all done parsing file
        } elsif ($marker==0x00 or $marker==0x01 or ($marker>=0xd0 and $marker<=0xd7)) {
            $verbose and $marker and print $out "JPEG $markerName:\n";
            # handle stand-alone markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
            Write($outfile, $hdr) or $err = 1;
            next;
        }
        #
        # NOTE: A 'next' statement after this point will cause $$segDataPt
        #       not to be written if there is an output file, so in this case
        #       the $self->{CHANGED} flags must be updated
        #
        my $segDataPt = \$segData;
        $length = length($segData);
        if ($verbose) {
            print $out "JPEG $markerName ($length bytes):\n";
            if ($verbose > 2 and $markerName =~ /^APP/) {
                HexDump($segDataPt, undef, %dumpParms);
            }
        }
        # rewrite this segment only if we are changing a tag which
        # is contained in its directory
        while (exists $$editDirs{$markerName}) {
            my $oldChanged = $self->{CHANGED};
            if ($marker == 0xe1) {              # APP1 (EXIF, XMP)
                # check for EXIF data
                if ($$segDataPt =~ /^$exifAPP1hdr/) {
                    $doneDir{IFD0} and $self->Warn('Multiple APP1 EXIF segments');
                    $doneDir{IFD0} = 1;
                    last unless $$editDirs{IFD0};
                    # write new EXIF data to memory
                    my $buff = $exifAPP1hdr; # start with EXIF APP1 header
                    # rewrite EXIF as if this were a TIFF file in memory
                    my %dirInfo = (
                        DataPt => $segDataPt,
                        DataPos => $segPos,
                        DirStart => 6,
                        Base => $segPos + 6,
                        OutFile => \$buff,
                        Parent => $markerName,
                    );
                    my $result = $self->ProcessTIFF(\%dirInfo);
                    $segDataPt = \$buff;
                    unless ($result > 0) { # check for problems writing the EXIF
                        last Marker unless $self->Options('IgnoreMinorErrors');
                        $$segDataPt = $exifAPP1hdr . $self->{EXIF_DATA}; # restore original EXIF
                        $self->{CHANGED} = $oldChanged;
                    }
                    # switch to buffered output if required
                    if ($self->{PREVIEW_INFO} and not $oldOutfile) {
                        $writeBuffer = '';
                        $oldOutfile = $outfile;
                        $outfile = \$writeBuffer;
                        # must account for segment, EXIF and TIFF headers
                        $self->{PREVIEW_INFO}->{Fixup}->{Start} += 18;
                    }
                    # delete segment if IFD contains no entries
                    unless (length($$segDataPt) > length($exifAPP1hdr)) {
                        $verbose and print $out "Deleting APP1\n";
                        next Marker;
                    }
                # check for XMP data
                } elsif ($$segDataPt =~ /^$xmpAPP1hdr/) {
                    $doneDir{XMP} and $self->Warn('Multiple APP1 XMP segments');
                    $doneDir{XMP} = 1;
                    last unless $$editDirs{XMP};
                    my $start = length $xmpAPP1hdr;
                    my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                    my %dirInfo = (
                        Base     => 0,
                        DataPt   => $segDataPt,
                        DataPos  => $segPos,
                        DataLen  => $length,
                        DirStart => $start,
                        DirLen   => $length - $start,
                        Parent   => $markerName,
                    );
                    my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                    if (defined $newData) {
                        undef $$segDataPt;  # free the old buffer
                        # add header to new segment unless empty
                        $newData = $xmpAPP1hdr . $newData if length $newData;
                        $segDataPt = \$newData;
                    } else {
                        $self->{CHANGED} = $oldChanged;
                    }
                    unless (length $$segDataPt) {
                        $verbose and print $out "Deleting APP1\n";
                        next Marker;
                    }
                }
            } elsif ($marker == 0xe2) {         # APP2 (ICC Profile)
                if ($$segDataPt =~ /^ICC_PROFILE\0/) {
                    if ($self->{DEL_GROUP} and $self->{DEL_GROUP}->{ICC_Profile}) {
                        ++$self->{CHANGED};
                        $verbose and print $out "  Deleting ICC_Profile segment\n";
                        next Marker;
                    }
                    # must concatenate blocks of profile
                    my $block_num = ord(substr($$segDataPt, 12, 1));
                    my $blocks_tot = ord(substr($$segDataPt, 13, 1));
                    $combinedSegData = '' if $block_num == 1;
                    unless (defined $combinedSegData) {
                        $self->Warn('APP2 ICC_Profile segments out of sequence');
                        next Marker;
                    }
                    $combinedSegData .= substr($$segDataPt, 14);
                    # continue accumulating segments unless this is the last
                    next Marker unless $block_num == $blocks_tot;
                    $doneDir{ICC_Profile} and $self->Warn('Multiple ICC_Profile records');
                    $doneDir{ICC_Profile} = 1;
                    $segDataPt = \$combinedSegData;
                    $length = length $combinedSegData;
                    my $tagTablePtr = GetTagTable('Image::ExifTool::ICC_Profile::Main');
                    my %dirInfo = (
                        DataPt   => $segDataPt,
                        DataPos  => $segPos + 14,
                        DataLen  => $length,
                        DirStart => 0,
                        DirLen   => $length,
                        Parent   => $markerName,
                    );
                    my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                    if (defined $newData) {
                        undef $$segDataPt;  # free the old buffer
                        $segDataPt = \$newData;
                    }
                    unless (length $$segDataPt) {
                        $verbose and print $out "Deleting APP2\n";
                        next Marker;
                    }
                    # write as ICC multi-segment
                    WriteMultiSegment($outfile, $marker, "ICC_PROFILE\0", $segDataPt, 'ICC') or $err = 1;
                    undef $combinedSegData;
                    undef $$segDataPt;
                    next Marker;
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
                    if ($dirOrder[0] eq 'Photoshop') {
                        # initialize combined data if necessary
                        $combinedSegData = $$segDataPt unless defined $combinedSegData;
                        next Marker;    # get the next segment to combine
                    }
                    $doneDir{Photoshop} and $self->Warn('Multiple Photoshop records');
                    $doneDir{Photoshop} = 1;
                    # process Photoshop APP13 record
                    my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                    my %dirInfo = (
                        DataPt   => $segDataPt,
                        DataPos  => $segPos,
                        DataLen  => $length,
                        DirStart => 14,     # directory starts after identifier
                        DirLen   => $length-14,
                        Parent   => $markerName,
                    );
                    my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                    if (defined $newData) {
                        undef $$segDataPt;  # free the old buffer
                        $segDataPt = \$newData;
                    } else {
                        $self->{CHANGED} = $oldChanged;
                    }
                    unless (length $$segDataPt) {
                        $verbose and print $out "Deleting APP13\n";
                        next Marker;
                    }
                    # write as multi-segment
                    WriteMultiSegment($outfile, $marker, $psAPP13hdr, $segDataPt) or $err = 1;
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
            } elsif ($marker == 0xfe) {         # COM (JPEG comment)
                my $newComment;
                unless ($doneDir{COM}) {
                    $doneDir{COM} = 1;
                    unless ($self->{DEL_GROUP} and $self->{DEL_GROUP}->{File}) {
                        my $tagInfo = $Image::ExifTool::Extra{Comment};
                        my $newValueHash = $self->GetNewValueHash($tagInfo);
                        unless (IsOverwriting($newValueHash, $segData)) {
                            delete $$editDirs{COM}; # we aren't editing COM after all
                            last;
                        }
                        $newComment = GetNewValues($newValueHash);
                    }
                }
                $verbose > 1 and print $out "    - Comment = '$$segDataPt'\n";
                if (defined $newComment and length $newComment) {
                    # write out the comments
                    $verbose > 1 and print $out "    + Comment = '$newComment'\n";
                    WriteMultiSegment($outfile, 0xfe, '', \$newComment) or $err = 1;
                } else {
                    $verbose and print $out "Deleting COM\n";
                }
                ++$self->{CHANGED};     # increment the changed flag
                undef $segDataPt;       # don't write existing comment
            } elsif ($marker == 0xe0) {         # APP0 (JFIF)
                if ($$segDataPt =~ /^JFIF\0/) {
                    SetByteOrder('MM');
                    my $tagTablePtr = GetTagTable('Image::ExifTool::JFIF::Main');
                    my %dirInfo = (
                        DataPt   => $segDataPt,
                        DataPos  => $segPos,
                        DataLen  => $length,
                        DirStart => 5,     # directory starts after identifier
                        DirLen   => $length-5,
                        Parent   => $markerName,
                    );
                    my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                    if (defined $newData and length $newData) {
                        $$segDataPt = "JFIF\0" . $newData;
                    }
                }
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
    # if oldOutfile is still set, there was an error copying the JPEG
    $oldOutfile and return 0;
    $/ = $oldsep;     # restore separator to original value
    # set return value to -1 if we only had a write error
    $rtnVal = -1 if $rtnVal and $err;
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Validate an image for writing
# Inputs: 0) ExifTool object reference, 1) raw value reference
# Returns: error string or undef on success
sub CheckImage($$)
{
    my ($self, $valPtr) = @_;
    if (length($$valPtr) and $$valPtr!~/^\xff\xd8/ and not
        $self->Options('IgnoreMinorErrors'))
    {
        return '[minor] Not a valid image';
    }
    return undef;
}

#------------------------------------------------------------------------------
# check a value for validity
# Inputs: 0) value reference, 1) format string, 2) optional count
# Returns: error string, or undef on success
# Notes: May modify value (if a count is specified for a string, it is null-padded
# to the specified length, and floating point values are rounded to integer if required)
sub CheckValue($$;$)
{
    my ($valPtr, $format, $count) = @_;
    my (@vals, $n);

    if ($format eq 'string' or $format eq 'undef') {
        return undef unless $count and $count > 0;
        my $len = length($$valPtr);
        if ($format eq 'string') {
            $len >= $count and return 'String too long';
        } else {
            $len > $count and return 'Data too long';
        }
        if ($len < $count) {
            $$valPtr .= "\0" x ($count - $len);
        }
        return undef;
    }
    if ($count and $count != 1) {
        @vals = split(' ',$$valPtr);
        $count < 0 and ($count = @vals or return undef);
    } else {
        $count = 1;
        @vals = ( $$valPtr );
    }
    return "Too many values specified ($count required)" if @vals > $count;
    return "Not enough values specified ($count required)" if @vals < $count;
    my $val;
    for ($n=0; $n<$count; ++$n) {
        $val = shift @vals;
        if ($format =~ /^int/) {
            # make sure the value is integer
            unless (IsInt($val)) {
                if (IsHex($val)) {
                    $val = $$valPtr = hex($val);
                } else {
                    # round single floating point values to the nearest integer
                    return 'Not an integer' unless IsFloat($val) and $count == 1;
                    $val = $$valPtr = int($val + ($val < 0 ? -0.5 : 0.5));
                }
            }
            my $rng = $intRange{$format} or return "Bad int format: $format";
            return "Value below $format minimum" if $val < $$rng[0];
            return "Value above $format maximum" if $val > $$rng[1];
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
# copy image data from one file to another
# Inputs: 0) ExifTool object reference
#         1) reference to list of image data [ position, size, pad bytes ]
#         2) output file ref
# Returns: true on success
sub CopyImageData($$$)
{
    my ($self, $imageDataBlocks, $outfile) = @_;
    my $raf = $self->{RAF};
    my ($dataBlock, $buff, $err);
    foreach $dataBlock (@$imageDataBlocks) {
        my ($pos, $size, $pad) = @$dataBlock;
        $raf->Seek($pos, 0) or $err = 'read', last;
        while ($size) {
            # copy in blocks of 64kB or smaller
            my $n = $size > 65536 ? 65536 : $size;
            $raf->Read($buff, $n) == $n or $err = 'read', last;
            Write($outfile, $buff) or $err = 'writ', last;
            $size -= $n;
        }
        last if $err;
        if ($pad) { # pad if necessary
            Write($outfile, "\0") or $err = 'writ', last;
        }
    }
    if ($err) {
        $self->Error("Error ${err}ing image data");
        return 0;
    }
    return 1;
}

#------------------------------------------------------------------------------
# write to binary data block
# Inputs: 0) ExifTool object reference, 1) source dirInfo reference,
#         2) tag table reference
# Returns: Binary data block or undefined on error
sub WriteBinaryData($$$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    $self or return 1;    # allow dummy access to autoload this package

    # get default format ('int8u' unless specified)
    my $defaultFormat = $$tagTablePtr{FORMAT} || 'int8u';
    my $increment = FormatSize($defaultFormat);
    unless ($increment) {
        warn "Unknown format $defaultFormat\n";
        return undef;
    }
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || length($$dataPt) - $dirStart;
    my $newData = substr($$dataPt, $dirStart, $dirLen) or return undef;
    my $dirName = $$dirInfo{DirName};
    my $verbose = $self->Options('Verbose');
    my $tagInfo;
    $dataPt = \$newData;
    foreach $tagInfo ($self->GetNewTagInfoList($tagTablePtr)) {
        my $tagID = $tagInfo->{TagID};
        # must check to be sure this tagInfo applies (ie. evaluate the condition!)
        my $writeInfo = $self->GetTagInfo($tagTablePtr, $tagID);
        next unless $writeInfo and $writeInfo eq $tagInfo;
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
        my $newValueHash = $self->GetNewValueHash($tagInfo);
        next unless IsOverwriting($newValueHash, $val);
        my $newVal = GetNewValues($newValueHash);
        next unless defined $newVal;    # can't delete from a binary table
        # set the size
        if ($$tagInfo{DataTag} and not $$tagInfo{IsOffset}) {
            warn 'Internal error' unless $newVal == 0xfeedfeed;
            my $data = $self->GetNewValues($$tagInfo{DataTag});
            $newVal = length($data) if defined $data;
        }
        my $rtnVal = WriteValue($newVal, $format, $count, $dataPt, $entry);
        if (defined $rtnVal) {
            if ($verbose > 1) {
                my $out = $self->{OPTIONS}->{TextOut};
                print $out "    - $dirName:$$tagInfo{Name} = '$val'\n";
                print $out "    + $dirName:$$tagInfo{Name} = '$newVal'\n";
            }
            ++$self->{CHANGED};
        }
    }
    # add necessary fixups for any offsets
    if ($tagTablePtr->{IS_OFFSET} and $$dirInfo{Fixup}) {
        my $fixup = $$dirInfo{Fixup};
        my $tagID;
        foreach $tagID (@{$tagTablePtr->{IS_OFFSET}}) {
            $tagInfo = $self->GetTagInfo($tagTablePtr, $tagID) or next;
            my $entry = $tagID * $increment;    # (no offset to dirStart for new dir data)
            next unless $entry <= $dirLen - 4;
            $fixup->AddFixup($entry, $$tagInfo{DataTag});
            # handle the preview image now if this is a JPEG file
            next unless $self->{FILE_TYPE} eq 'JPEG' and $$tagInfo{DataTag} and
                $$tagInfo{DataTag} eq 'PreviewImage' and defined $$tagInfo{OffsetPair};
            my $offset = ReadValue($dataPt, $entry, 'int32u', 1, $dirLen-$entry);
            $entry = $$tagInfo{OffsetPair} * $increment;
            my $size = ReadValue($dataPt, $entry, 'int32u', 1, $dirLen-$entry);
            my $previewInfo = $self->{PREVIEW_INFO};
            $previewInfo or $previewInfo = $self->{PREVIEW_INFO} = { };
            $previewInfo->{Data} = $self->GetNewValues('PreviewImage');
            unless (defined $previewInfo->{Data}) {
                if ($offset >= 0 and $offset + $size <= $$dirInfo{DataLen}) {
                    $previewInfo->{Data} = substr(${$$dirInfo{DataPt}},$offset,$size);
                } else {
                    $previewInfo->{Data} = 'LOAD'; # flag to load preview later
                }
            }
        }
    }
    return $newData;
}

#------------------------------------------------------------------------------
# Write TIFF as a directory
# Inputs: 0) ExifTool object reference, 1) source directory information reference
#         2) tag table reference, 3) optional reference to writing procedure
# Returns: New directory data or undefined on error
sub WriteTIFF($$$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    my $buff;
    $$dirInfo{OutFile} = \$buff;
    return $buff if $self->ProcessTIFF($dirInfo, $tagTablePtr) > 0;
    return undef;
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

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
