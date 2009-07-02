# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/Geotag.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..6\n"; $Image::ExifTool::noConfig = 1; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Geotag;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'Geotag';
my $testnum = 1;
my @testTags = ('Error', 'Warning', 'GPS:*', 'XMP:*');
my $testfile2;

# test 2: Geotag from GPX track log
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile2;
    $exifTool->SetNewValue(Geotag => 't/images/Geotag.gpx');
    $exifTool->SetNewValue(Geotime => '2003:05:24 17:09:31Z');
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile2);
    my $info = $exifTool->ImageInfo($testfile2, @testTags);
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 3-5: Geotag tests using Magellan track log
{
    # geotag to XMP
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue(Geotag => 't/images/Geotag.log');
    $exifTool->SetNewValue('XMP:Geotime' => '2009:04:03 06:11:30-05:00');
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, @testTags);
    if (check($exifTool, $info, $testname, $testnum, 3)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";

    # point too far outside track
    ++$testnum;
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    my ($num, $err) = $exifTool->SetNewValue(Geotime => '2009:04:03 08:00:00-05:00');
    $exifTool->WriteInfo($testfile2, $testfile);
    $info = $exifTool->ImageInfo($testfile, @testTags);
    if (check($exifTool, $info, $testname, $testnum, 2)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";

    # delete geotags
    ++$testnum;
    my $testfile5 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile5;
    ($num, $err) = $exifTool->SetNewValue(Geotime => undef);
    $exifTool->WriteInfo($testfile2, $testfile5);
    $info = $exifTool->ImageInfo($testfile5, 'Filename', @testTags);
    if (check($exifTool, $info, $testname, $testnum) and not $err) {
        unlink $testfile2;
        unlink $testfile5;
    } else {
        warn "\n  $err\n" if $err;
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 6: Geotag from Garmin XML track log
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue(Geotag => 't/images/Geotag.xml');
    $exifTool->SetNewValuesFromFile('t/images/Panasonic.jpg',
        'Geotime<${DateTimeOriginal}+02:00'
    );
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, @testTags);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# end
