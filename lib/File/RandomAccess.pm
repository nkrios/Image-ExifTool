#------------------------------------------------------------------------------
# File:         RandomAccess.pm
#
# Description:  Buffer to support random access reading of sequential file
#
# Revisions:    02/11/04 - P. Harvey Created
#               02/20/04 - P. Harvey Added flag to disable SeekTest in new()
#
# Notes:        Calls the normal file i/o routines unless SeekTest() fails, in
#               which case the file is buffered in memory to allow random access.
#               SeekTest() is called automatically when the object is created
#               unless specified.
#
#               May also be used for string i/o (just pass a scalar reference)
#
# Legal:        Copyright (c) 2003-2004 Phil Harvey (phil@owl.phy.queensu.ca)
#               This library is free software; you can redistribute it and/or
#               modify it under the same terms as Perl itself.
#------------------------------------------------------------------------------

package File::RandomAccess;

use strict;
require 5.002;
require Exporter;

use vars qw($VERSION @ISA @EXPORT_OK);
$VERSION = '1.00';
@ISA = qw(Exporter);

# constants
my $CHUNK_SIZE = 65536; # size of chunks to read from file (must be power of 2)

#------------------------------------------------------------------------------
# Create new RandomAccess object
# Inputs: 0) reference to RandomAccess object or RandomAccess class name
#         1) file reference or scalar reference
#         2) flag set if file is already random access (disables automatic SeekTest)
sub new($$;$)
{
    my ($that, $filePt, $isRandom) = @_;
    my $class = ref($that) || $that;
    my $self;
    
    if (ref $filePt eq 'SCALAR') {
        # string i/o
        $self = {
            BUFF_PT => $filePt,
            POS => 0,
            LEN => length($$filePt),
            TESTED => -1,
        };
        bless $self, $class;
    } else {
        # file i/o
        my $buff = '';
        $self = { 
            FILE_PT => $filePt, # file pointer
            BUFF_PT => \$buff,  # reference to file data
            POS => 0,           # current position in file
            LEN => 0,           # data length
            TESTED => 0,        # 0=untested, 1=passed, -1=failed (requires buffering)
        };
        bless $self, $class;
        $self->SeekTest() unless $isRandom;
    }
    return $self;
}

#------------------------------------------------------------------------------
# Perform seek test and turn on buffering if necessary
# Inputs: 0) reference to RandomAccess object
# Returns: 1 if seek test passed (ie. no buffering required)
# Notes: Must be done before any other i/o
sub SeekTest($)
{
    my $self = shift;
    unless ($self->{TESTED}) {
        my $fp = $self->{FILE_PT};
        if (seek($fp, 1, 1) and seek($fp, -1, 1)) {
            $self->{TESTED} = 1;    # test passed
        } else {
            $self->{TESTED} = -1;   # test failed (requires buffering)
        }
    }
    return $self->{TESTED} == 1 ? 1 : 0;
}

#------------------------------------------------------------------------------
# Get current position in file
# Inputs: 0) reference to RandomAccess object
# Returns: current position in file
sub Tell($)
{
    my $self = shift;
    my $rtnVal;
    if ($self->{TESTED} < 0) {
        $rtnVal = $self->{POS};
    } else {
        $rtnVal = tell($self->{FILE_PT});
    }
}

#------------------------------------------------------------------------------
# Seek to position in file
# Inputs: 0) reference to RandomAccess object
#         1) position, 2) whence (0=from start, 1=from cur pos, 2=from end)
# Returns: 1 on success
# Notes: When buffered, this doesn't quite behave like seek() since it will return
#        success even if you seek outside the limits of the file.  However if you
#        do this, you will get an error on your next Read().
sub Seek($$$)
{
    my ($self, $num, $whence) = @_;
    my $rtnVal;
    if ($self->{TESTED} < 0) {
        if ($whence == 0) {
            $self->{POS} = $num;
        } elsif ($whence == 1) {
            $self->{POS} += $num;
        } else {
            $self->Slurp();                 # read whole file into buffer
            $self->{POS} = $self->{LEN};    # position at end of file
        }
        $rtnVal = 1;
    } else {
        $rtnVal = seek($self->{FILE_PT}, $num, $whence);
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Read from the file
# Inputs: 0) reference to RandomAccess object
#         1) buffer, 2) bytes to read
# Returns: Number of bytes read
sub Read($$$)
{
    my $self = shift;
    my $len = $_[1];
    my $rtnVal;

    if ($self->{TESTED} < 0) {
        my $buff;
        my $newPos = $self->{POS} + $len;
        # number of bytes to read from file
        my $num = $newPos - $self->{LEN};
        if ($num > 0 and $self->{FILE_PT}) {
            # read data from file in multiples of $CHUNK_SIZE
            $num = (($num - 1) | ($CHUNK_SIZE - 1)) + 1;
            $num = read($self->{FILE_PT}, $buff, $num);
            if ($num) {
                ${$self->{BUFF_PT}} .= $buff;
                $self->{LEN} += $num;
            }
        }
        # number of bytes left in data buffer
        $num = $self->{LEN} - $self->{POS};
        if ($len > $num) {
            $rtnVal = $num;
        } else {
            $rtnVal = $len;
        }
        # return data from our buffer
        $_[0] = substr(${$self->{BUFF_PT}}, $self->{POS}, $rtnVal);
        $self->{POS} += $rtnVal;
    } else {
        $rtnVal = read($self->{FILE_PT}, $_[0], $len);
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Read a line from file (end of line is $/)
# Inputs: 0) reference to RandomAccess object, 1) buffer
# Returns: Number of bytes read
sub ReadLine($$)
{
    my $self = shift;
    my $rtnVal;
    my $fp = $self->{FILE_PT};
    
    if ($self->{TESTED} < 0) {
        my ($num, $buff);
        my $pos = $self->{POS};
        if ($fp) {
            # make sure we have some data after the current position
            while ($self->{LEN} <= $pos) {
                $num = read($fp, $buff, $CHUNK_SIZE);
                return 0 unless $num;
                ${$self->{BUFF_PT}} .= $buff;
                $self->{LEN} += $num;
            }
            # scan and read until we find the EOL (or hit EOF)
            for (;;) {
                $pos = index(${$self->{BUFF_PT}}, $/, $pos) + 1;
                last if $pos > 0;
                $pos = $self->{LEN};    # have scanned to end of buffer
                $num = read($fp, $buff, $CHUNK_SIZE) or last;
                ${$self->{BUFF_PT}} .= $buff;
                $self->{LEN} += $num;
            }
        } else {
            # string i/o
            $pos = index(${$self->{BUFF_PT}}, $/, $pos) + 1;
            $pos <= 0 and $pos = $self->{LEN};
        }
        # read the line from our buffer
        $rtnVal = $pos - $self->{POS};
        $_[0] = substr(${$self->{BUFF_PT}}, $self->{POS}, $rtnVal);
        $self->{POS} = $pos;
    } else {
        $_[0] = <$fp>;
        if (defined $_[0]) {
            $rtnVal = length($_[0]);
        } else {
            $rtnVal = 0;
        }
    }
    return $rtnVal;  
}

#------------------------------------------------------------------------------
# Read whole file into buffer (without changing read pointer)
# Inputs: 0) reference to RandomAccess object
sub Slurp($)
{
    my $self = shift;
    my $fp = $self->{FILE_PT} || return;
    # read whole file into buffer (in large chunks)
    my ($buff, $num);
    while (($num = read($fp, $buff, 16 * $CHUNK_SIZE)) != 0) {
        ${$self->{BUFF_PT}} .= $buff;
        $self->{LEN} += $num;
    }
}


#------------------------------------------------------------------------------
# set binary mode
# Inputs: 0) reference to RandomAccess object
sub BinMode($)
{
    my $self = shift;
    binmode($self->{FILE_PT}) if $self->{FILE_PT};
}

#------------------------------------------------------------------------------
# close the file and free the buffer
# Inputs: 0) reference to RandomAccess object
sub Close($)
{
    my $self = shift;
    # close the file
    if ($self->{FILE_PT}) {
        close($self->{FILE_PT});
        delete $self->{FILE_PT};
    }
    # reset the buffer
    my $emptyBuff = '';
    $self->{BUFF_PT} = \$emptyBuff;
    $self->{LEN} = 0;
    $self->{POS} = 0;
}

#------------------------------------------------------------------------------
1;  # end
