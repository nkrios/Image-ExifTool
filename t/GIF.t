# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/GIF.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..4\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'GIF';
my $testnum = 1;

# test 2: GIF file using data in memory
{
    ++$testnum;
    open(TESTFILE, 't/images/GIF.gif');
    binmode(TESTFILE);
    my $gifImage;
    read(TESTFILE, $gifImage, 100000);
    close(TESTFILE);
    my $info = ImageInfo(\$gifImage);
    print 'not ' unless check($info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 3/4: Test removing comment then adding it back again to GIF in memory
{
    ++$testnum;
    open(TESTFILE, 't/images/GIF.gif');
    binmode(TESTFILE);
    my $gifImage;
    read(TESTFILE, $gifImage, 100000);
    close(TESTFILE);
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('Comment');
    my $image1;
    $exifTool->WriteInfo(\$gifImage, \$image1);
    my $info = ImageInfo(\$image1);
    print 'not ' unless check($info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    $info = ImageInfo(\$gifImage);
    my $gifComment = $info->{Comment};
    $exifTool->SetNewValue('Comment',$gifComment);
    my $image2;
    $exifTool->WriteInfo(\$image1, \$image2);
    print 'not ' unless $image2 eq $gifImage;
    print "ok $testnum\n";
}


# end
