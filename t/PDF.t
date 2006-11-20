# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/PDF.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..3\n"; $Image::ExifTool::noConfig = 1; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::PDF;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'PDF';
my $testnum = 1;

# test 2: Extract information from PDF.pdf
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/PDF.pdf');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Test Standard PDF decryption
{
    ++$testnum;
    my $skip = '';
    if (eval 'require Digest::MD5') {
        my $id = pack('H*','12116a1a124ae4cd8179e8978f6ac88b');
        my %cryptInfo = (
            Filter => '/Standard',
            P => -60,
            V => 1,
            R => 0,
            O => pack('H*','2055c756c72e1ad702608e8196acad447ad32d17cff583235f6dd15fed7dab67'),
            U => pack('H*','7150bd1da9d292af3627fca6a8dde1d696e25312041aed09059f9daee04353ae'),
        );
        my $exifTool = new Image::ExifTool;
        my $data = pack('N', 0x34a290d3);
        my $err = Image::ExifTool::PDF::DecryptInit($exifTool, \%cryptInfo, $id);
        $err and warn "\n  $err\n";
        Image::ExifTool::PDF::Decrypt(\$data);
        my $expected = 0x5924d335;
        my $got = unpack('N', $data);
        unless ($got == $expected) {
            warn "\n  Test $testnum (decryption) returned wrong value:\n";
            warn sprintf("    Expected 0x%x but got 0x%x\n", $expected, $got);
            print 'not ';
        }
    } else {
        $skip = ' # skip Requires Digest::MD5';
    }
    print "ok $testnum$skip\n";
}

# end
