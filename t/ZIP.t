# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/ZIP.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..6\n"; $Image::ExifTool::noConfig = 1; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::ZIP;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'ZIP';
my $testnum = 1;

# tests 2-3: Extract information from test ZIP and GZIP files
{
    my $exifTool = new Image::ExifTool;
    my $type;
    foreach $type (qw(zip gz)) {
        ++$testnum;
        my $info = $exifTool->ImageInfo("t/images/ZIP.$type");
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

# tests 4-6: Extract information from other ZIP-based files (requires Archive::Zip)
{
    my $exifTool = new Image::ExifTool;
    my $file;
    foreach $file ('OOXML.docx', 'CaptureOne.eip', 'iWork.numbers') {
        ++$testnum;
        my $skip = '';
        if (eval 'require Archive::Zip') {
            my $info = $exifTool->ImageInfo("t/images/$file");
            print 'not ' unless check($exifTool, $info, $testname, $testnum);
        } else {
            $skip = ' # skip Requires Archive::Zip';
        }
        print "ok $testnum$skip\n";
    }
}

# end
