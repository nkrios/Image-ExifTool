#------------------------------------------------------------------------------
# File:         TestLib.pm
#
# Description:  Utility routines for testing ExifTool modules
#
# Revisions:    Feb. 19/04 - P. Harvey Created
#               Feb. 26/04 - P. Harvey Name temporary file ".failed" and erase
#                            it if the test passes
#               Feb. 27/04 - P. Harvey Change print format and allow ExifTool
#                            object to be passed instead of tags hash ref.
#               Oct. 30/04 - P. Harvey Split testCompare() into separate sub.
#------------------------------------------------------------------------------

package t::TestLib;

use strict;
require 5.002;
require Exporter;
use Image::ExifTool;

use vars qw($VERSION @ISA @EXPORT_OK);
$VERSION = '1.02';
@ISA = qw(Exporter);
@EXPORT_OK = qw(check testCompare);

# Compare 2 files and return true and erase the 2nd file if they are the same
# Inputs: 0) file1, 1) file2
# Returns: true if files are the same
sub testCompare($$$)
{
    my ($compfile, $testfile, $testnum) = @_;
    my $success = 0;
    my $linenum;
    
    my $oldSep = $/;   
    $/ = "\x0a";        # set input line separator
    if (open(FILE1, $compfile)) {
        if (open(FILE2, $testfile)) {
            $success = 1;
            my ($line1, $line2);
            my $linenum = 0;
            foreach (<FILE1>) {
                ++$linenum;
                $line1 = $_;
                $line2 = <FILE2>;
                unless (defined $line2 and $line1 eq $line2) {
                    $success = 0;
                    last;
                }
            }
            if ($success) {
                # make sure there is nothing left in file2
                $line2 = <FILE2>;
                if ($line2) {
                    ++$linenum;
                    $success = 0;
                }
            }
            unless ($success) {
                if (defined $line2) {
                    chomp $line2;
                    warn "\n  Test $testnum differs at line $linenum: \"$line2\"\n";
                } else {
                    chomp $line1;
                    warn "\n  Test $testnum missing line $linenum: \"$line1\"\n";
                }
            }
            close(FILE2);
        }
        close(FILE1);
    }
    $/ = $oldSep;       # restore input line separator
    
    # erase .failed file if test was successful
    $success and unlink $testfile;
    
    return $success
}

# Compare extracted information against a standard output file
# Inputs: 0) [optional] ExifTool object reference
#         1) tag hash reference
#         2) test name
#         3) test number
#         4) test number for comparison file (if different than this test)
# Returns: 1 if check passed
sub check($$$;$$)
{
    my $exifTool = shift if ref $_[0] eq 'Image::ExifTool';
    my ($info, $testname, $testnum, $compnum) = @_;
    return 0 unless $info;
    $compnum = $testnum unless defined $compnum;
    my $testfile = "t/${testname}_$testnum.failed";
    my $compfile = "t/${testname}_$compnum.out";
    open(FILE, ">$testfile") or return 0;
    
    # use one type of linefeed so this test works across platforms
    my $oldSep = $\;
    $\ = "\x0a";        # set output line separator
    
    # get a list of found tags
    my @tags;
    if ($exifTool) {
        # sort tags by group to make it a bit prettier
        @tags = $exifTool->GetTagList($info, 'Group0');
    } else {
        @tags = sort keys %$info;
    }
#
# Write information to file (with filename "TESTNAME_#.failed")
#
    foreach (@tags) {
        # skip version number because it changes with every new version.  :)
        next if $_ eq 'ExifToolVersion';
        my $val = $$info{$_};
        if (ref $val eq 'SCALAR') {
            if ($$val =~ /^Binary data/) {
                $val = "($$val)";
            } else {
                $val = '(Binary data ' . length($$val) . ' bytes)';
            }
        } else {
            # make sure there are no linefeeds in output
            $val =~ tr/\x0a\x0d/;/;
            # translate unknown characters
            $val =~ tr/\x01-\x1f\x80-\xff/\./;
            # remove NULL chars
            $val =~ s/\x00//g;
        }
        # (no "\n" needed since we set the output line separator above)
        if ($exifTool) {
            my $groups = join ', ', $exifTool->GetGroup($_);
            my $desc = $exifTool->GetDescription($_);
            print FILE "[$groups] $desc: $val";
        } else {
            print FILE "$_: $val";
        }
    }
    close(FILE);
    
    $\ = $oldSep;       # restore output line separator
#
# Compare the output file to the output from the standard test (TESTNAME_#.out)
#
    return testCompare($compfile, $testfile,$testnum);
}


1; #end
