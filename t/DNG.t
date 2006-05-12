# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/DNG.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'DNG';
my $testnum = 1;

# test 2: Extract information from DNG.dng
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/DNG.dng');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}


# end
