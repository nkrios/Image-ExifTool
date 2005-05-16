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
use Image::ExifTool qw{ImageInfo};

use vars qw($VERSION @ISA @EXPORT);
$VERSION = '1.05';
@ISA = qw(Exporter);
@EXPORT = qw(check writeCheck testCompare testVerbose);

#------------------------------------------------------------------------------
# Compare 2 files and return true and erase the 2nd file if they are the same
# Inputs: 0) file1, 1) file2
# Returns: true if files are the same
sub testCompare($$$)
{
    my ($stdfile, $testfile, $testnum) = @_;
    my $success = 0;
    my $linenum;
    
    my $oldSep = $/;   
    $/ = "\x0a";        # set input line separator
    if (open(FILE1, $stdfile)) {
        if (open(FILE2, $testfile)) {
            $success = 1;
            my ($line1, $line2);
            my $linenum = 0;
            foreach (<FILE1>) {
                ++$linenum;
                $line1 = $_;
                $line2 = <FILE2>;
                if (defined $line2) {
                    next if $line1 eq $line2;
                    # ignore version number differences
                    next if $line1 =~ /ExifTool\s?Version/ and
                            $line2 =~ /ExifTool\s?Version/;
                    # ignore different FileModifyDate's
                    next if $line1 =~ /File\s?Modif.*Date/ and
                            $line2 =~ /File\s?Modif.*Date/;
                    # some systems use 3 digits in exponents... grrr
                    if ($line2 =~ s/e(\+|-)0/e$1/) {
                        next if $line1 eq $line2;
                    }
                }
                $success = 0;
                last;
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
                warn "\n  Test $testnum differs beginning at line $linenum:\n";
                defined $line1 or $line1 = '(null)';
                defined $line2 or $line2 = '(null)';
                chomp $line1;
                chomp $line2;
                warn qq{    Test gave: "$line2"\n};
                warn qq{    Should be: "$line1"\n};
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

#------------------------------------------------------------------------------
# Compare extracted information against a standard output file
# Inputs: 0) [optional] ExifTool object reference
#         1) tag hash reference
#         2) test name
#         3) test number
#         4) test number for comparison file (if different than this test)
# Returns: 1 if check passed
sub check($$$;$$)
{
    my $exifTool = shift if ref $_[0] ne 'HASH';
    my ($info, $testname, $testnum, $stdnum) = @_;
    return 0 unless $info;
    $stdnum = $testnum unless defined $stdnum;
    my $testfile = "t/${testname}_$testnum.failed";
    my $stdfile = "t/${testname}_$stdnum.out";
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
            my $tagID = $exifTool->GetTagID($_);
            my $desc = $exifTool->GetDescription($_);
            print FILE "[$groups] $tagID - $desc: $val";
        } else {
            print FILE "$_: $val";
        }
    }
    close(FILE);
    
    $\ = $oldSep;       # restore output line separator
#
# Compare the output file to the output from the standard test (TESTNAME_#.out)
#
    return testCompare($stdfile, $testfile,$testnum);
}

#------------------------------------------------------------------------------
# test writing feature by writing specified information to JPEG file
# Inputs: 0) list reference to lists of SetNewValue arguments
#         1) test name, 2) test number, 3) optional source file name
# Returns: 1 if check passed
sub writeCheck($$$;$)
{
    my ($writeInfo, $testname, $testnum, $srcfile) = @_;
    $srcfile or $srcfile = "t/$testname.jpg";
    my ($ext) = ($srcfile =~ /\.(.+?)$/);
    my $testfile = "t/${testname}_${testnum}_failed.$ext";
    my $exifTool = new Image::ExifTool;
    foreach (@$writeInfo) {
        $exifTool->SetNewValue(@$_);
    }
    unlink $testfile;
    $exifTool->WriteInfo($srcfile, $testfile);
    my $info = $exifTool->GetInfo('Error');
    foreach (keys %$info) { warn "$$info{$_}\n"; }
    $info = $exifTool->ImageInfo($testfile,{Duplicates=>1,Unknown=>1});
    my $rtnVal = check($exifTool, $info, $testname, $testnum);
    $rtnVal and unlink $testfile;
    return $rtnVal;
}

#------------------------------------------------------------------------------
# test verbose output
# Inputs: 0) test name, 1) test number, 2) Input file, 3) verbose level
# Returns: 0) ok value, 1) skip string if test must be skipped
sub testVerbose($$$$)
{
    my ($testname, $testnum, $infile, $verbose) = @_;
    my $testfile = "t/${testname}_$testnum";
    my $ok = 1;
    my $skip = '';
    # capture verbose output by redirecting STDOUT
    if (open(TESTFILE,">&STDOUT") and open(STDOUT,">$testfile.tmp")) {
        ImageInfo($infile, { Verbose => $verbose });
        close(STDOUT);
        open(STDOUT,">&TESTFILE"); # restore original STDOUT
        # re-write output file to change newlines to be same as standard test file
        # (if I was a Perl guru, maybe I would know a better way to do this)
        open(TMPFILE,"$testfile.tmp");
        open(TESTFILE,">$testfile.failed");
        my $oldSep = $\;
        $\ = "\x0a";        # set output line separator
        while (<TMPFILE>) {
            chomp;          # remove existing newline
            print TESTFILE $_;  # re-write line using \x0a for newlines
        }
        $\ = $oldSep;       # restore output line separator
        close(TESTFILE);
        unlink("$testfile.tmp");
        $ok = testCompare("$testfile.out","$testfile.failed",$testnum);
    } else {
        # skip this test
        $skip = ' # Skip Can not redirect standard output to test verbose output';
    }
    return ($ok, $skip);
}


1; #end
