#------------------------------------------------------------------------------
# File:         Fixup.pm
#
# Description:  Utility to handle pointer fixups
#
# Revisions:    01/19/2005 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Fixup;

use strict;
use Image::ExifTool qw(GetByteOrder SetByteOrder Get32u Set32u);
use vars qw($VERSION);

$VERSION = '1.00';

sub AddFixup($$);
sub ApplyFixup($$);
sub Dump($;$);

#------------------------------------------------------------------------------
# New - create new Fixup object
# Inputs: 0) reference to Fixup object or Fixup class name
sub new
{
    local $_;
    my $that = shift;
    my $class = ref($that) || $that || 'Image::ExifTool::Fixup';
    my $self = bless {}, $class;

    # initialize required members
    $self->{Start} = 0;
    $self->{Shift} = 0;

    return $self;
}

#------------------------------------------------------------------------------
# Add fixup pointer or another fixup object below this one
# Inputs: 0) Fixup object reference
#         1) Scalar for pointer offset, or reference to Fixup object
# Notes: Byte ordering must be set properly for the pointer being added (must keep
# track of the byte order of each offset since MakerNotes may have different byte order!)
sub AddFixup($$)
{
    my ($self, $pointer) = @_;
    if (ref $pointer) {
        $self->{Fixups} or $self->{Fixups} = [ ];
        push @{$self->{Fixups}}, $pointer;
    } else {
        my $byteOrder = GetByteOrder();
        my $phash = $self->{Pointers};
        $phash or $phash = $self->{Pointers} = { };
        $phash->{$byteOrder} or $phash->{$byteOrder} = [ ];
        push @{$phash->{$byteOrder}}, $pointer;
    }
}

#------------------------------------------------------------------------------
# fix up pointer offsets
# Inputs: 0) Fixup object reference, 1) data reference
# Outputs: Collapses fixup hierarchy into linear lists of fixup pointers
# Fixup hash elements:
#     Start - position in data where a zero pointer points to
#     Shift - amount to shift offsets (relative to Start)
#     Fixups - list of Fixup object references to to shift relative to this Fixup
#     Pointers - hash of references to fixup pointers, keyed by ByteOrder string
sub ApplyFixup($$)
{
    my ($self, $dataPt) = @_;

    my $start = $self->{Start};
    my $shift = $self->{Shift} + $start;   # make shift relative to start
    my $phash = $self->{Pointers};

    # fix up pointers in this fixup
    if ($phash and ($start or $shift)) {
        my $saveOrder = GetByteOrder(); # save original byte ordering
        my ($byteOrder, $ptr);
        foreach $byteOrder (keys %$phash) {
            SetByteOrder($byteOrder);
            foreach $ptr (@{$phash->{$byteOrder}}) {
                $ptr += $start;         # update pointer to new start location
                next unless $shift;
                # apply the fixup offset shift
                Set32u(Get32u($dataPt, $ptr) + $shift, $dataPt, $ptr);
            }
        }
        SetByteOrder($saveOrder);       # restore original byte ordering
    }
    # recurse into contained fixups
    if ($self->{Fixups}) {
        # create our pointer hash if it doesn't exist
        $phash or $phash = $self->{Pointers} = { };
        # loop through all contained fixups
        my $subFixup;
        foreach $subFixup (@{$self->{Fixups}}) {
            # adjust the subfixup start and shift
            $subFixup->{Start} += $start;
            $subFixup->{Shift} += $shift - $start;
            # recursively apply contained fixups
            ApplyFixup($subFixup, $dataPt);
            my $shash = $subFixup->{Pointers} or next;
            # add all pointers to our collapsed lists
            my $byteOrder;
            foreach $byteOrder (keys %$shash) {
                $phash->{$byteOrder} or $phash->{$byteOrder} = [ ];
                push @{$phash->{$byteOrder}}, @{$shash->{$byteOrder}};
                delete $shash->{$byteOrder};
            }
            delete $subFixup->{Pointers};
        }
        delete $self->{Fixups};    # remove our contained fixups
    }
    # reset our Start/Shift for the collapsed fixup
    $self->{Start} = $self->{Shift} = 0;
}

#------------------------------------------------------------------------------
# Dump fixup to console for debugging
# Inputs: 0) Fixup object reference, 1) optional initial indent string
sub Dump($;$)
{
    my ($self, $indent) = @_;
    $indent or $indent = '';
    printf "${indent}Fixup start=0x%x shift=0x%x\n", $self->{Start}, $self->{Shift};
    my $phash = $self->{Pointers};
    if ($phash) {
        my $byteOrder;
        foreach $byteOrder (keys %$phash) {
            print "$indent  $byteOrder: ", join(' ',@{$phash->{$byteOrder}}),"\n";
        }
    }
    if ($self->{Fixups}) {
        my $subFixup;
        foreach $subFixup (@{$self->{Fixups}}) {
            Dump($subFixup, $indent . '  ');
        }
    }
}


1; # end

__END__

=head1 NAME

Image::ExifTool::Fixup - Utility to handle pointer fixups

=head1 SYNOPSIS

    use Image::ExifTool::Fixup;

    $fixup = new Image::ExifTool::Fixup;

    # add a new fixup to a pointer at the specified offset in data
    $fixup->AddFixup($offset);

    # add a new Fixup object to the tree
    $fixup->AddFixup($subFixup);

    $fixup->{Start} += $shift1;   # shift pointer offsets and values

    $fixup->{Shift} += $shift2;   # shift pointer values only

    # recursively apply fixups to the specified data
    $fixup->ApplyFixups(\$data);

    $fixup->Dump();               # dump debugging information

=head1 DESCRIPTION

This module contains the code to keep track of pointers in memory and to
shift these pointers as required.  It is used by ExifTool to maintain the
pointers in image file directories (IFD's).

=head1 NOTES

Keeps track of pointers with different byte ordering, and relies on
Image::ExifTool::GetByteOrder() to determine the current byte ordering
when adding new pointers to a fixup.

Maintains a hierarchical list of fixups so that the whole hierarchy can
be shifted by a simple shift at the base.  Hierarchy is collapsed to a
linear list when ApplyFixups() is called.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
