# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/FLAC.t'

use Image::ExifTool;
use t::TestLib;

$| = 1;
print "1..", scalar(@Image::ExifTool::langs) - 1, "\n";

my $testname = 'Lang';
my $testnum = 0;

# tests 1-N: Test all languages
my $exifTool = new Image::ExifTool;
my $lang;
foreach $lang (@Image::ExifTool::langs) {
    next if $lang eq 'en'; # skip english
    ++$testnum;
    my $not = 'not ';
    $exifTool->Options(Lang => $lang);
    if ($exifTool->Options('Lang') eq $lang) {
        my $info = $exifTool->ImageInfo('t/images/FujiFilm.jpg', 'Exif:All');
        $not = '' if check($exifTool, $info, $testname, $testnum);
    } else {
        warn "\n  Error loading language $lang\n";
    }
    print "${not}ok $testnum\n";
}

# end
