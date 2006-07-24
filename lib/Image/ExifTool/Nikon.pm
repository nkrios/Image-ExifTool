#------------------------------------------------------------------------------
# File:         Nikon.pm
#
# Description:  Nikon EXIF maker notes tags
#
# Revisions:    12/09/2003 - P. Harvey Created
#               05/17/2004 - P. Harvey Added information from Joseph Heled
#               09/21/2004 - P. Harvey Changed tag 2 to ISOUsed & added PrintConv
#               12/01/2004 - P. Harvey Added default PRINT_CONV
#               12/06/2004 - P. Harvey Added SceneMode
#               01/01/2005 - P. Harvey Decode preview image and preview IFD
#               03/35/2005 - T. Christiansen additions
#               05/10/2005 - P. Harvey Decode encrypted lens data
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Joseph Heled private communication (tests with D70)
#               3) Thomas Walter private communication (tests with Coolpix 5400)
#               4) http://www.cybercom.net/~dcoffin/dcraw/
#               5) Brian Ristuccia private communication (tests with D70)
#               6) Danek Duvall private communication (tests with D70)
#               7) Tom Christiansen private communication (tchrist@perl.com)
#               8) Robert Rottmerhusen private communication
#               9) http://members.aol.com/khancock/pilot/nbuddy/
#              10) Werner Kober private communication (D2H, D2X, D100, D70, D200)
#              11) http://www.rottmerhusen.com/objektives/lensid/nikkor.html
#              12) http://libexif.sourceforge.net/internals/mnote-olympus-tag_8h-source.html
#              13) Roger Larsson private communication (tests with D200)
#              14) http://homepage3.nifty.com/kamisaka/makernote/makernote_nikon.htm
#              15) http://tomtia.plala.jp/DigitalCamera/MakerNote/index.asp
#------------------------------------------------------------------------------

package Image::ExifTool::Nikon;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.45';

# nikon lens ID numbers (ref 8/11)
my %nikonLensIDs = (
    Notes => q{
        The Nikon LensID is constructed as a Composite tag from the raw hex values
        of 8 other tags: LensIDNumber, LensFStops, MinFocalLength, MaxFocalLength,
        MaxApertureAtMinFocal, MaxApertureAtMaxFocal, MCUVersion and LensType, in
        that order.
    },
    # (hex digits must be uppercase in keys below)
    '01 58 50 50 14 14 02 00' => 'AF Nikkor 50mm f/1.8',
    '02 42 44 5C 2A 34 02 00' => 'AF Zoom-Nikkor 35-70mm f/3.3-4.5',
    '02 42 44 5C 2A 34 08 00' => 'AF Zoom-Nikkor 35-70mm f/3.3-4.5',
    '03 48 5C 81 30 30 02 00' => 'AF Zoom-Nikkor 70-210mm f/4',
    '04 48 3C 3C 24 24 03 00' => 'AF Nikkor 28mm f/2.8',
    '05 54 50 50 0C 0C 04 00' => 'AF Nikkor 50mm f/1.4',
    '06 54 53 53 24 24 06 00' => 'AF Micro-Nikkor 55mm f/2.8',
    '07 40 3C 62 2C 34 03 00' => 'AF Zoom-Nikkor 28-85mm f/3.5-4.5',
    '08 40 44 6A 2C 34 04 00' => 'AF Zoom-Nikkor 35-105mm f/3.5-4.5',
    '09 48 37 37 24 24 04 00' => 'AF Nikkor 24mm f/2.8',
    '0A 48 8E 8E 24 24 03 00' => 'AF Nikkor 300mm f/2.8 IF-ED',
    '0B 48 7C 7C 24 24 05 00' => 'AF Nikkor 180mm f/2.8 IF-ED',
    '0D 40 44 72 2C 34 07 00' => 'AF Zoom-Nikkor 35-135mm f/3.5-4.5',
    '0E 48 5C 81 30 30 05 00' => 'AF Zoom-Nikkor 70-210mm f/4',
    '0F 58 50 50 14 14 05 00' => 'AF Nikkor 50mm f/1.8 N',
    '10 48 8E 8E 30 30 08 00' => 'AF Nikkor 300mm f/4 IF-ED',
    '11 48 44 5C 24 24 08 00' => 'AF Zoom-Nikkor 35-70mm f/2.8',
    '12 48 5C 81 30 3C 09 00' => 'AF Nikkor 70-210mm f/4-5.6',
    '13 42 37 50 2A 34 0B 00' => 'AF Zoom-Nikkor 24-50mm f/3.3-4.5',
    '14 48 60 80 24 24 0B 00' => 'AF Zoom-Nikkor 80-200mm f/2.8 ED',
    '15 4C 62 62 14 14 0C 00' => 'AF Nikkor 85mm f/1.8',
    '17 3C A0 A0 30 30 11 00' => 'Nikkor 500mm f/4 P',
    '18 40 44 72 2C 34 0E 00' => 'AF Zoom-Nikkor 35-135mm f/3.5-4.5 N',
    '1A 54 44 44 18 18 11 00' => 'AF Nikkor 35mm f/2',
    '1B 44 5E 8E 34 3C 10 00' => 'AF Zoom-Nikkor 75-300mm f/4.5-5.6',
    '1C 48 30 30 24 24 12 00' => 'AF Nikkor 20mm f/2.8',
    '1D 42 44 5C 2A 34 12 00' => 'AF Zoom-Nikkor 35-70mm f/3.3-4.5 N',
    '1E 54 56 56 24 24 13 00' => 'AF Micro-Nikkor 60mm f/2.8',
    '20 48 60 80 24 24 15 00' => 'AF Zoom-Nikkor ED 80-200mm f/2.8',
    '22 48 72 72 18 18 16 00' => 'AF DC-Nikkor 135mm f/2',
    '24 48 60 80 24 24 1A 02' => 'AF Zoom-Nikkor ED 80-200mm f/2.8D',
    '25 48 44 5C 24 24 1B 02' => 'AF Zoom-Nikkor 35-70mm f/2.8D',
    '25 48 44 5C 24 24 52 02' => 'AF Zoom-Nikkor 35-70mm f/2.8D N',
    '27 48 8E 8E 24 24 F2 02' => 'AF-I Nikkor 300mm f/2.8D IF-ED',
    '27 48 8E 8E 24 24 1D 02' => 'AF-I Nikkor 300mm f/2.8D IF-ED',
    '28 3C A6 A6 30 30 1D 02' => 'AF-I Nikkor 600mm f/4D IF-ED',
    '2A 54 3C 3C 0C 0C 26 02' => 'AF Nikkor 28mm f/1.4D',
    '2C 48 6A 6A 18 18 27 02' => 'AF DC-Nikkor 105mm f/2D',
    '2D 48 80 80 30 30 21 02' => 'AF Micro-Nikkor 200mm f/4D IF-ED',
    '2E 48 5C 82 30 3C 28 02' => 'AF Nikkor 70-210mm f/4-5.6D',
    '2F 48 30 44 24 24 29 02' => 'AF Zoom-Nikkor 20-35mm f/2.8(IF)',
    '31 54 56 56 24 24 25 02' => 'AF Micro-Nikkor 60mm f/2.8D',
    '32 54 6A 6A 24 24 35 02' => 'AF Micro-Nikkor 105mm f/2.8D',
    '33 48 2D 2D 24 24 31 02' => 'AF Nikkor 18mm f/2.8D',
    '34 48 29 29 24 24 32 02' => 'AF Fisheye Nikkor 16mm f/2.8D',
    '36 48 37 37 24 24 34 02' => 'AF Nikkor 24mm f/2.8D',
    '37 48 30 30 24 24 36 02' => 'AF Nikkor 20mm f/2.8D',
    '38 4C 62 62 14 14 37 02' => 'AF Nikkor 85mm f/1.8D',
    '3B 48 44 5C 24 24 3A 02' => 'AF Zoom-Nikkor 35-70mm f/2.8D N',
    '3D 3C 44 60 30 3C 3E 02' => 'AF Zoom-Nikkor 35-80mm f/4-5.6D',
    '3E 48 3C 3C 24 24 3D 02' => 'AF Nikkor 28mm f/2.8D',
    '41 48 7C 7C 24 24 43 02' => 'AF Nikkor 180mm f/2.8D IF-ED',
    '42 54 44 44 18 18 44 02' => 'AF Nikkor 35mm f/2D',
    '43 54 50 50 0C 0C 46 02' => 'AF Nikkor 50mm f/1.4D',
    '46 3C 44 60 30 3C 49 02' => 'AF Zoom-Nikkor 35-80mm f/4-5.6D N',
    '47 42 37 50 2A 34 4A 02' => 'AF Zoom-Nikkor 24-50mm f/3.3-4.5D',
    '48 48 8E 8E 24 24 4B 02' => 'AF-S Nikkor 300mm f/2.8D IF-ED',
    '4A 54 62 62 0C 0C 4D 02' => 'AF Nikkor 85mm f/1.4D IF',
    '4C 40 37 6E 2C 3C 4F 02' => 'AF Zoom-Nikkor 24-120mm f/3.5-5.6D IF',
    '4D 40 3C 80 2C 3C 62 02' => 'AF Zoom-Nikkor 28-200mm f/3.5-5.6D IF',
    '4E 48 72 72 18 18 51 02' => 'AF DC-Nikkor 135mm f/2D',
    '4F 40 37 5C 2C 3C 53 06' => 'IX-Nikkor 24-70mm f/3.5-5.6',
    '53 48 60 80 24 24 60 02' => 'AF Zoom-Nikkor 80-200mm f/2.8D ED',
    '54 44 5C 7C 34 3C 58 02' => 'AF Zoom-Micro Nikkor 70-180mm f/4.5-5.6D ED',
    '56 48 5C 8E 30 3C 5A 02' => 'AF Zoom-Nikkor 70-300mm f/4-5.6D ED',
    '59 48 98 98 24 24 5D 02' => 'AF-S Nikkor 400mm f/2.8D IF-ED',
    '5A 3C 3E 56 30 3C 5E 06' => 'IX-Nikkor 30-60mm f/4-5.6',
    '5D 48 3C 5C 24 24 63 02' => 'AF-S Zoom-Nikkor 28-70mm f/2.8D IF-ED',
    '5E 48 60 80 24 24 64 02' => 'AF-S Zoom-Nikkor 80-200mm f/2.8D IF-ED',
    '5F 40 3C 6A 2C 34 65 02' => 'AF Zoom-Nikkor 28-105mm f/3.5-4.5D IF',
    '61 44 5E 86 34 3C 67 02' => 'AF Zoom-Nikkor 75-240mm f/4.5-5.6D',
    '63 48 2B 44 24 24 68 02' => 'AF-S Nikkor 17-35mm f/2.8D IF-ED',
    '64 00 62 62 24 24 6A 02' => 'PC Micro-Nikkor 85mm f/2.8D',
    '65 44 60 98 34 3C 6B 0A' => 'AF VR Zoom-Nikkor 80-400mm f/4.5-5.6D ED',
    '66 40 2D 44 2C 34 6C 02' => 'AF Zoom-Nikkor 18-35mm f/3.5-4.5D IF-ED',
    '67 48 37 62 24 30 6D 02' => 'AF Zoom-Nikkor 24-85mm f/2.8-4D IF',
    '68 42 3C 60 2A 3C 6E 06' => 'AF Zoom-Nikkor 28-80mm f/3.3-5.6G',
    '69 48 5C 8E 30 3C 6F 06' => 'AF Zoom-Nikkor 70-300mm f/4-5.6G',
    '6A 48 8E 8E 30 30 70 02' => 'AF-S Nikkor 300mm f/4D IF-ED',
    '6B 48 24 24 24 24 71 02' => 'AF Nikkor ED 14mm f/2.8D',
    '6D 48 8E 8E 24 24 73 02' => 'AF-S Nikkor 300mm f/2.8D IF-ED II',
    '6E 48 98 98 24 24 74 02' => 'AF-S Nikkor 400mm f/2.8D IF-ED II',
    '6F 3C A0 A0 30 30 75 02' => 'AF-S Nikkor 500mm f/4D IF-ED',
    '70 3C A6 A6 30 30 76 02' => 'AF-S Nikkor 600mm f/4D IF-ED',
    '72 48 4C 4C 24 24 77 00' => 'Nikkor 45mm f/2.8 P',
    '74 40 37 62 2C 34 78 06' => 'AF-S Zoom-Nikkor 24-85mm f/3.5-4.5G IF-ED',
    '75 40 3C 68 2C 3C 79 06' => 'AF Zoom-Nikkor 28-100mm f/3.5-5.6G',
    '76 58 50 50 14 14 7A 02' => 'AF Nikkor 50mm f/1.8D',
    '77 48 5C 80 24 24 7B 0E' => 'AF-S VR Zoom-Nikkor 70-200mm f/2.8G IF-ED',
    '78 40 37 6E 2C 3C 7C 0E' => 'AF-S VR Zoom-Nikkor 24-120mm f/3.5-5.6G IF-ED',
    '79 40 3C 80 2C 3C 7F 06' => 'AF Zoom-Nikkor 28-200mm f/3.5-5.6G IF-ED',
    '7A 3C 1F 37 30 30 7E 06' => 'AF-S DX Zoom-Nikkor 12-24mm f/4G IF-ED',
    '7B 48 80 98 30 30 80 0E' => 'AF-S VR Zoom-Nikkor 200-400mm f/4G IF-ED',
    '7D 48 2B 53 24 24 82 06' => 'AF-S DX Zoom-Nikkor 17-55mm f/2.8G IF-ED',
    '7F 40 2D 5C 2C 34 84 06' => 'AF-S DX Zoom-Nikkor 18-70mm f/3.5-4.5G IF-ED',
    '80 48 1A 1A 24 24 85 06' => 'AF DX Fisheye-Nikkor 10.5mm f/2.8G ED',
    '81 54 80 80 18 18 86 0E' => 'AF-S VR Nikkor 200mm f/2G IF-ED',
    '82 48 8E 8E 24 24 87 0E' => 'AF-S VR Nikkor 300mm f/2.8G IF-ED',
    '89 3C 53 80 30 3C 8B 06' => 'AF-S DX Zoom-Nikkor 55-200mm f/4-5.6G ED',
    '8A 54 6A 6A 24 24 8C 0E' => 'AF-S VR Micro-Nikkor 105mm f/2.8G IF-ED', #10
    '8B 40 2D 80 2C 3C 8D 0E' => 'AF-S DX VR Zoom-Nikkor 18-200mm f/3.5-5.6G IF-ED',
    '8C 40 2D 53 2C 3C 8E 06' => 'AF-S DX Zoom-Nikkor 18-55mm f/3.5-5.6G ED',
#
    '06 3F 68 68 2C 2C 06 00' => 'Cosina 100mm F/3.5 Macro',
#
    '26 48 11 11 30 30 1C 02' => 'Sigma 8mm F4 EX Circular Fisheye',
    '48 3C 19 31 30 3C 4B 06' => 'Sigma 10-20mm F4-5.6 EX DC HSM',
    '48 38 1F 37 34 3C 4B 06' => 'Sigma 12-24mm F4.5-5.6 EX Aspherical DG HSM',
    '02 3F 24 24 2C 2C 02 00' => 'Sigma 14mm F3.5',
    '48 48 24 24 24 24 4B 02' => 'Sigma 14mm F2.8 EX ASPHERICAL HSM',
    '26 48 27 27 24 24 1C 02' => 'Sigma 15mm F2.8 EX Diagonal Fish-Eye',
    '26 40 27 3F 2C 34 1C 02' => 'Sigma 15-30mm F3.5-4.5 EX Aspherical DG DF',
    '48 48 2B 44 24 30 4B 06' => 'Sigma 17-35mm F2.8-4 EX DG  Aspherical HSM',
    '26 54 2B 44 24 30 1C 02' => 'Sigma 17-35mm F2.8-4 EX ASPHERICAL',
    '26 48 2D 50 24 24 1C 06' => 'Sigma 18-50mm F2.8 EX DC',
    '26 40 2D 50 2C 3C 1C 06' => 'Sigma 18-50mm F3.5-5.6 DC',
    '26 40 2D 70 2B 3C 1C 06' => 'Sigma 18-125mm F3.5-5.6 DC',
    '26 40 2D 80 2C 40 1C 06' => 'Sigma 18-200mm F3.5-6.3 DC',
    '26 58 31 31 14 14 1C 02' => 'Sigma 20mm F1.8 EX Aspherical DG DF RF',
    '26 58 37 37 14 14 1C 02' => 'Sigma 24mm F1.8 EX Aspherical DG DF MACRO',
    '02 46 37 37 25 25 02 00' => 'Sigma 24mm F2.8 Macro',
    '26 48 37 56 24 24 1C 02' => 'Sigma 24-60mm F2.8 EX DG',
    '26 54 37 5C 24 24 1C 02' => 'Sigma 24-70mm F2.8 EX DG Macro',
    '26 40 37 5C 2C 3C 1C 02' => 'Sigma 24-70mm F3.5-5.6 ASPHERICAL HF',
    '26 54 37 73 24 34 1C 02' => 'Sigma 24-135mm F2.8-4.5',
    '26 58 3C 3C 14 14 1C 02' => 'Sigma 28mm F1.8 EX DG DF',
    '26 48 3C 5C 24 24 1C 06' => 'Sigma 28-70mm F2.8 EX DG',
    '26 48 3C 5C 24 30 1C 02' => 'Sigma 28-70mm F2.8-4 HIGH SPEED ZOOM',
    '02 46 3C 5C 25 25 02 00' => 'Sigma 28-70mm F2.8',
    '02 3F 3C 5C 2D 35 02 00' => 'Sigma 28-70mm F3.5-4.5 UC',
    '26 40 3C 60 2C 3C 1C 02' => 'Sigma 28-80mm F3.5-5.6 Mini Zoom Macro II Aspherical',
    '26 3E 3C 6A 2E 3C 1C 02' => 'Sigma 28-105mm F3.8-5.6 UC-III ASPHERICAL IF',
    '26 40 3C 80 2C 3C 1C 02' => 'Sigma 28-200mm F3.5-5.6 Compact Aspherical Hyperzoom Macro',
    '26 40 3C 80 2B 3C 1C 02' => 'Sigma 28-200mm F3.5-5.6 Compact Aspherical Hyperzoom Macro',
    '26 41 3C 8E 2C 40 1C 02' => 'Sigma 28-300mm F3.5-6.3 DG MACRO',
    '26 40 3C 8E 2C 40 1C 02' => 'Sigma 28-300mm F3.5-6.3 Macro',
    '48 54 3E 3E 0C 0C 4B 06' => 'Sigma 30mm F1.4 EX DC HSM',
    '02 40 44 73 2B 36 02 00' => 'Sigma 35-135mm F3.5-4.5 a',
    '32 54 50 50 24 24 35 02' => 'Sigma 50mm F2.8 EX DG Macro',
    '48 3C 50 A0 30 40 4B 02' => 'Sigma 50-500mmF4-6.3 EX APO RF HSM',
    '26 3C 54 80 30 3C 1C 06' => 'Sigma 55-200mm F4-5.6 DC',
    '48 54 5C 80 24 24 4B 02' => 'Sigma 70-200mm F2.8 EX APO IF HSM',
    '26 3C 5C 8E 30 3C 1C 02' => 'Sigma 70-300mm F4-5.6 DG MACRO',
    '56 3C 5C 8E 30 3C 1C 02' => 'Sigma 70-300mm F4-5.6 APO Macro Super II',
    '02 37 5E 8E 35 3D 02 00' => 'Sigma 75-300mm F4.5-5.6 APO',
    '02 48 65 65 24 24 02 00' => 'Sigma 90mm F2.8 Macro',
    '77 44 61 98 34 3C 7B 0E' => 'Sigma 80-400mm f4.5-5.6 EX OS',
    '48 48 68 8E 30 30 4B 02' => 'Sigma 100-300mm F4 EX IF HSM',
    '26 44 73 98 34 3C 1C 02' => 'Sigma 135-400mm F4.5-5.6 APO Aspherical',
    '48 48 76 76 24 24 4B 06' => 'Sigma 150mm F2.8 EX DG APO Macro HSM',
    '26 40 7B A0 34 40 1C 02' => 'Sigma APO 170-500mm F5-6.3 ASPHERICAL RF',
    '48 4C 7D 7D 2C 2C 4B 02' => 'Sigma APO MACRO 180mm F3.5 EX DG HSM',
    '48 54 8E 8E 24 24 4B 02' => 'Sigma APO 300mm F2.8 EX DG HSM',
    '26 48 8E 8E 30 30 1C 02' => 'Sigma APO TELE MACRO 300mm F4',
    '02 2F 98 98 3D 3D 02 00' => 'Sigma 400mm F5.6 APO',
#
    '03 43 5C 81 35 35 02 00' => 'Soligor AF C/D ZOOM UMCS 70-210mm 1:4.5',
#
    '00 3C 1F 37 30 30 00 06' => 'Tokina AT-X 124 AF PRO DX - AF 12-24mm f/4',
    '00 40 2B 2B 2C 2C 00 02' => 'Tokina AT-X 17 AF PRO - AF 17mm f/3.5',
    '25 48 3C 5C 24 24 1B 02' => 'Tokina AT-X287AF PRO SV 28-70mm F2.8',
    '00 48 3C 60 24 24 00 02' => 'Tokina AT-X280AF PRO 28-80mm F2.8 ASPHERICAL',
    '14 54 60 80 24 24 0B 00' => 'Tokina AT-X828AF 80-200mm F2.8',
    '24 44 60 98 34 3C 1A 02' => 'Tokina AT-X840AF II 80-400mm F4.5-5.6',
    '00 54 68 68 24 24 00 02' => 'Tokina AT-X M100 PRO D - 100mm F2.8',
    '14 48 68 8E 30 30 0B 00' => 'Tokina AT-X340AF II 100-300mm F4',
    '00 54 8E 8E 24 24 00 02' => 'Tokina AT-X300AF PRO 300mm F2.8',
#
    '00 36 1C 2D 34 3C 00 06' => 'Tamron SP AF11-18mm F/4.5-5.6 Di II LD Aspherical (IF)',
    '07 46 2B 44 24 30 03 02' => 'Tamron SP AF17-35mm F/2.8-4 Di LD Aspherical (IF)',
    '00 3F 2D 80 2B 40 00 06' => 'Tamron AF18-200mm f/3.5-6.3 XR Di II LD Aspherical (IF)',
    '00 3F 2D 80 2C 40 00 06' => 'Tamron AF18-200mm f/3.5-6.3 XR Di II LD Aspherical (IF) MACRO',
    '07 40 30 45 2D 35 03 02' => 'Tamron AF19-35mm F3.5-4.5',
    '00 49 30 48 22 2B 00 02' => 'Tamron SP AF20-40mm f/2.7-3.5',
    '45 41 37 72 2C 3C 48 02' => 'Tamron SP AF24-135mm F3.5-5.6 AD ASPHERICAL(IF)MACRO',
    '33 54 3C 5E 24 24 62 02' => 'Tamron SP AF28-75mm F2.8 XR Di LD ASPHERICAL(IF)MACRO',
    '10 3D 3C 60 2C 3C D2 02' => 'Tamron AF28-80mm f/3.5-5.6 Aspherical',
    '45 3D 3C 60 2C 3C 48 02' => 'Tamron AF 28-80mm F3.5-5.6 ASPHERICAL',
    '00 48 3C 6A 24 24 00 02' => 'Tamron SP AF28-105mm f/2.8',
    '0B 3E 3D 7F 2F 3D 0E 02' => 'Tamron AF28-200mm f/3.8-5.6D',
    '0B 3E 3D 7F 2F 3D 0E 00' => 'Tamron AF28-200mm f/3.8-5.6',
    '4D 41 3C 8E 2B 40 62 02' => 'Tamron AF28-300mm f/3.5-6.3 XR Di LD Aspherical (IF)',
    '4D 41 3C 8E 2C 40 62 02' => 'Tamron AF28-300mm f/3.5-6.3D',
    '69 48 5C 8E 30 3C 6F 02' => 'Tamron AF70-300mm F4-5.6 LD MACRO 1:2',
    '32 53 64 64 24 24 35 02' => 'Tamron SP AF90mm f/2.8 Di 1:1 Macro',
    '00 4C 7C 7C 2C 2C 00 02' => 'Tamron SP AF180mm F3.5 Di Model B01',
    '20 3C 80 98 3D 3D 1E 02' => 'Tamron AF200-400mm f/5.6 LD IF',
    '00 3E 80 A0 38 3F 00 02' => 'Tamron SP AF200-500mm f/5-6.3 Di LD (IF)',
    '00 3F 80 A0 38 3F 00 02' => 'Tamron SP AF200-500mm F5-6.3 Di',
#
    '00 00 00 00 00 00 00 01' => 'Manual Lens No CPU',
    '1E 5D 64 64 20 20 13 00' => 'Unknown 90mm F/2.5',
    '2F 40 30 44 2C 34 29 02' => 'Unknown 20-35mm F/3.5-4.5D',
    '12 3B 68 8D 3D 43 09 02' => 'Unknown 100-290mm F5.6-6.7',
);

# Nikon maker note tags
%Image::ExifTool::Nikon::Main = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikon,
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRINT_CONV => 'Image::ExifTool::Nikon::FormatString($val)',
    0x0001 => { #2
        # the format differs for different models.  for D70, this is a string '0210',
        # but for the E775 it is binary: "\x00\x01\x00\x00"
        Name => 'FirmwareVersion',
        Writable => 'undef',
        Count => 4,
        # convert to string if binary
        ValueConv => '$_=$val; /^[\x00-\x09]/ and $_=join("",unpack("CCCC",$_)); $_',
        ValueConvInv => '$val',
        PrintConv => '$_=$val;s/^(\d{2})/$1\./;s/^0//;$_',
        PrintConvInv => '$_=$val;s/\.//;"0$_"',
    },
    0x0002 => {
        # this is the ISO actually used by the camera
        # (may be different than ISO setting if auto)
        Name => 'ISO',
        Writable => 'int16u',
        Priority => 0,  # the EXIF ISO is more reliable
        Count => 2,
        Groups => { 2 => 'Image' },
        PrintConv => '$_=$val;s/^0 //;$_',
        PrintConvInv => '"0 $val"',
    },
    0x0003 => { Name => 'ColorMode',    Writable => 'string' },
    0x0004 => { Name => 'Quality',      Writable => 'string' },
    0x0005 => { Name => 'WhiteBalance', Writable => 'string' },
    0x0006 => { Name => 'Sharpness',    Writable => 'string' },
    0x0007 => { Name => 'FocusMode',    Writable => 'string' },
    0x0008 => { Name => 'FlashSetting', Writable => 'string' },
    # FlashType shows 'Built-in,TTL' when builtin flash fires,
    # and 'Optional,TTL' when external flash is used (ref 2)
    0x0009 => { #2
        Name => 'FlashType',
        Writable => 'string',
        Count => 13,
    },
    0x000b => { Name => 'WhiteBalanceFineTune', Writable => 'int16u' }, #2
    0x000c => {
        Name => 'ColorBalance1',
        Writable => 'rational64u',
        Count => 4,
    },
    0x000d => { #15
        Name => 'ProgramShift',
        Writable => 'undef',
        Count => 4,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*6 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c4",$a,1,6,0);
        },
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    0x000e => {
        Name => 'ExposureDifference',
        Writable => 'undef',
        Count => 4,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*12 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c4",$a,1,12,0);
        },
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    0x000f => { Name => 'ISOSelection', Writable => 'string' }, #2
    0x0010 => {
        Name => 'DataDump',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x0011 => {
        Name => 'NikonPreview',
        Groups => { 1 => 'NikonPreview', 2 => 'Image' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::PreviewImage',
            Start => '$val',
        },
    },
    0x0012 => { #2
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        Writable => 'undef',
        Count => 4,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*6 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c4",$a,1,6,0);
        },
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    # D70 - another ISO tag
    0x0013 => { #2
        Name => 'ISOSetting',
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$_=$val;s/^0 //;$_',
        PrintConvInv => '"0 $val"',
    },
    # D70 Image boundary?? top x,y bot-right x,y
    0x0016 => { #2
        Name => 'ImageBoundary',
        Writable => 'int16u',
        Count => 4,
    },
    0x0018 => { #5
        Name => 'FlashExposureBracketValue',
        Writable => 'undef',
        Count => 4,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*6 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c4",$a,1,6,0);
        },
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x0019 => { #5
        Name => 'ExposureBracketValue',
        Format => 'rational64s',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    0x001a => { #PH
        Name => 'ImageProcessing',
        Format => 'string',
    },
    0x001b => { #15
        Name => 'CropHiSpeed',
        PrintConv => q{
            my @a = split ' ', $val;
            return "Unknown ($val)" unless @a == 7;
            $a[0] = $a[0] ? "On" : "Off";
            return "$a[0] ($a[1]x$a[2] cropped to $a[3]x$a[4] at pixel $a[5],$a[6])";
        }
    },
    0x001d => { #4
        Name => 'SerialNumber',
        Writable => 0,
        Notes => 'Not writable because this value is used as a key to decrypt other information',
        RawConv => '$self->{NikonInfo}->{SerialNumber} = $val',
    },
    0x001e => { #14
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            1 => 'sRGB',
            2 => 'AdobeRGB',
        },
    },
    0x0080 => { Name => 'ImageAdjustment',  Writable => 'string' },
    0x0081 => { Name => 'ToneComp',         Writable => 'string' }, #2
    0x0082 => { Name => 'AuxiliaryLens',    Writable => 'string' },
    0x0083 => {
        Name => 'LensType',
        Writable => 'int8u',
        # credit to Tom Christiansen (ref 7) for figuring this out...
        PrintConv => q[$_ = $val ? Image::ExifTool::DecodeBits($val,
            {
                0 => 'MF',
                1 => 'D',
                2 => 'G',
                3 => 'VR',
            }) : 'AF';
            # remove commas and change "D G" to just "G"
            s/,//g; s/\bD G\b/G/; $_
        ],
        PrintConvInv => q[
            my $bits = 0;
            $bits |= 0x01 if $val =~ /\bMF\b/i;
            $bits |= 0x02 if $val =~ /\bD\b/i;
            $bits |= 0x06 if $val =~ /\bG\b/i;
            $bits |= 0x08 if $val =~ /\bVR\b/i;
            return $bits;
        ],
    },
    0x0084 => { #2
        Name => "Lens",
        Writable => 'rational64u',
        Count => 4,
        # short focal, long focal, aperture at short focal, aperture at long focal
        PrintConv => q{
            $val =~ tr/,/./;    # in case locale is whacky
            my ($a,$b,$c,$d) = split ' ', $val;
            ($a==$b ? $a : "$a-$b") . "mm f/" . ($c==$d ? $c : "$c-$d")
        },
        PrintConvInv => '$_=$val; tr/a-z\///d; s/(^|\s)([0-9.]+)(?=\s|$)/$1$2-$2/g; s/-/ /g; $_',
    },
    0x0085 => {
        Name => 'ManualFocusDistance',
        Writable => 'rational64u',
    },
    0x0086 => {
        Name => 'DigitalZoom',
        Writable => 'rational64u',
    },
    0x0087 => { #5
        Name => 'FlashMode',
        Writable => 'int8u',
        PrintConv => {
            0 => 'Did Not Fire',
            1 => 'Fired, Manual', #14
            7 => 'Fired, External', #14
            8 => 'Fired, Commander Mode',
            9 => 'Fired, TTL Mode',
        },
    },
    0x0088 => {
        Name => 'AFInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::AFInfo',
        },
    },
    0x0089 => { #5
        Name => 'ShootingMode',
        Writable => 'int16u',
        # credit to Tom Christiansen (ref 7) for figuring this out...
        # The (new?) bit 5 seriously complicates our life here: after firmwareB's
        # 1.03, bit 5 turns on when you ask for BUT DO NOT USE the long-range
        # noise reduction feature, probably because even not using it, it still
        # slows down your drive operation to 50% (1.5fps max not 3fps).  But no
        # longer does !$val alone indicate single-frame operation. - TC
        PrintConv => q[
            $_ = '';
            unless ($val & 0x87) {
                return 'Single-Frame' unless $val;
                $_ = 'Single-Frame, ';
            }
            return $_ . Image::ExifTool::DecodeBits($val,
            {
                0 => 'Continuous',
                1 => 'Delay',
                2 => 'PC Control',
                4 => 'Exposure Bracketing',
                5 => 'Unused LE-NR Slowdown',
                6 => 'White-Balance Bracketing',
                7 => 'IR Control',
            });
        ],
    },
    0x008a => { #15
        Name => 'AutoBracketRelease',
        PrintConv => {
            0 => 'None',
            1 => 'Auto Release',
            2 => 'Manual Release',
        },
    },
    0x008b => { #8
        Name => 'LensFStops',
        ValueConv => 'my ($a,$b,$c)=unpack("C3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => 'my $a=int($val*12+0.5);$a<256 ? pack("C4",$a,1,12,0) : undef',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
        Writable => 'undef',
        Count => 4,
    },
    0x008c => {
        Name => 'NEFCurve1',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x008d => { Name => 'ColorHue' ,        Writable => 'string' }, #2
    # SceneMode takes on the following values: PORTRAIT, PARTY/INDOOR, NIGHT PORTRAIT,
    # BEACH/SNOW, LANDSCAPE, SUNSET, NIGHT SCENE, MUSEUM, FIREWORKS, CLOSE UP, COPY,
    # BACK LIGHT, PANORAMA ASSIST, SPORT, DAWN/DUSK
    0x008f => { Name => 'SceneMode',        Writable => 'string' }, #2
    # LightSource shows 3 values COLORED SPEEDLIGHT NATURAL.
    # (SPEEDLIGHT when flash goes. Have no idea about difference between other two.)
    0x0090 => { Name => 'LightSource',      Writable => 'string' }, #2
    0x0092 => { #2
        Name => 'HueAdjustment',
        Writable => 'int16s',
    },
# this doesn't look right:
#    0x0093 => { #15
#        Name => 'SaturationAdjustment',
#        Writable => 'int16s',
#    },
    0x0094 => { Name => 'Saturation',       Writable => 'int16s' },
    0x0095 => { Name => 'NoiseReduction',   Writable => 'string' },
    0x0096 => {
        Name => 'NEFCurve2',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x0097 => [ #4
        {
            Condition => '$$valPt =~ /^0100/', # (D100)
            Name => 'ColorBalance0100',
            Writable => 0,
            SubDirectory => {
                Start => '$valuePtr + 72',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance1',
            },
        },
        {
            Condition => '$$valPt =~ /^0102/', # (D2H)
            Name => 'ColorBalance0102',
            Writable => 0,
            SubDirectory => {
                Start => '$valuePtr + 10',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
            },
        },
        {
            Condition => '$$valPt =~ /^0103/', # (D70)
            Name => 'ColorBalance0103',
            Writable => 0,
            # D70:  at file offset 'tag-value + base + 20', 4 16 bits numbers,
            # v[0]/v[1] , v[2]/v[3] are the red/blue multipliers.
            SubDirectory => {
                Start => '$valuePtr + 20',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance3',
            },
        },
        {
            Condition => '$$valPt =~ /^0205/', # (D50)
            Name => 'ColorBalance0205',
            Writable => 0,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
                DecryptLen => 22, # 324 bytes encrypted, but don't need to decrypt it all
                DirOffset => 14,
            },
        },
        {
            Condition => '$$valPt =~ /^02/', # (0204=D2X,0206=D2Hs,0207=D200)
            Name => 'ColorBalance02',
            Writable => 0,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 284,
                DecryptLen => 14, # 324 bytes encrypted, but don't need to decrypt it all
                DirOffset => 6,
            },
        },
        {
            Name => 'ColorBalanceUnknown',
            Writable => 0,
        },
    ],
    0x0098 => [
        { #8
            Condition => '$$valPt =~ /^0100/',
            Name => 'LensData0100',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData00',
            },
        },
        { #8
            Condition => '$$valPt =~ /^0101/',
            Name => 'LensData0101',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData01',
            },
        },
        # note: this information is encrypted if the version is 02xx
        { #8
            Condition => '$$valPt =~ /^0201/',
            Name => 'LensData0201',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData01',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
            },
        },
        {
            Name => 'LensDataUnknown',
            Writable => 0,
        },
    ],
    0x0099 => { #2/15
        Name => 'RawImageCenter',
        Writable => 'int16u',
        Count => 2,
    },
    0x009a => { #10
        Name => 'SensorPixelSize',
        Writable => 'rational64u',
        Count => 2,
        PrintConv => '$val=~s/ / x /;"$val um"',
        PrintConvInv => '$val=~tr/a-zA-Z/ /;$val',
    },
    0x00a0 => { Name => 'SerialNumber',     Writable => 'string' }, #2
    0x00a2 => { Name => 'ImageDataSize' }, # size of compressed image data plus EOI segment (ref 10)
    0x00a5 => { #15
        Name => 'ImageCount',
        Writable => 'int32u',
    },
    0x00a6 => { #15
        Name => 'DeletedImageCount',
        Writable => 'int32u',
    },
    # the sum of 0xa5 and 0xa6 is equal to 0xa7 ShutterCount (D2X,D2Hs,D2H,D200, ref 10)
    0x00a7 => { # Number of shots taken by camera so far (ref 2)
        Name => 'ShutterCount',
        Writable => 0,
        Notes => 'Not writable because this value is used as a key to decrypt other information',
        RawConv => '$self->{NikonInfo}->{ShutterCount} = $val',
    },
    0x00a9 => { #2
        Name => 'ImageOptimization',
        Writable => 'string',
        Count => 16,
    },
    0x00aa => { Name => 'Saturation',       Writable => 'string' }, #2
    0x00ab => { Name => 'VariProgram',      Writable => 'string' }, #2
    0x00ac => { Name => 'ImageStabilization',Writable=> 'string' }, #14
    0x00ad => { Name => 'AFResponse',       Writable => 'string' }, #14
    0x00b1 => { #14
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'On for ISO 1600/3200',
            2 => 'Weak',
            4 => 'Normal',
            6 => 'Strong',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    # 0x0e01 I don't know what this is, but in D70 NEF files produced by Nikon
    # Capture, the data for this tag extends 4 bytes past the end of the maker notes.
    # Very odd.  I hope these 4 bytes aren't useful because they will get lost by any
    # utility that blindly copies the maker notes (not ExifTool) - PH
    0x0e01 => {
        Name => 'NikonCaptureData',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::Main',
        },
    },
    0x0e09 => 'NikonCaptureVersion', #12
    # 0x0e0e is in D70 Nikon Capture files (not out-of-the-camera D70 files) - PH
    0x0e0e => { #PH
        Name => 'NikonCaptureOffsets',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::CaptureOffsets',
            Validate => '$val =~ /^0100/',
            Start => '$valuePtr + 4',
        },
    },
    # 0x0e10 - unknown (written by Nikon Capture)
    # 0x0e13 - some sort of edit history written by Nikon Capture
);

# Nikon AF information (ref 13)
%Image::ExifTool::Nikon::AFInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'AFMode',
        PrintConv => {
            0 => 'Single Area',
            1 => 'Dynamic Area',
            2 => 'Dynamic Area, Closest Subject',
            3 => 'Group Dynamic',
            4 => 'Single Area (wide)',
            5 => 'Dynamic Area (wide)',
        },
    },
    1 => {
        Name => 'AFPoint',
        Notes => 'in some focus modes this value is not meaningful',
        PrintConv => {
            0 => 'Center',
            1 => 'Top',
            2 => 'Bottom',
            3 => 'Left',
            4 => 'Right',
            5 => 'Upper-left',
            6 => 'Upper-right',
            7 => 'Lower-left',
            8 => 'Lower-right',
            9 => 'Far Left',
            10 => 'Far Right',
        },
    },
    2 => {
        Name => 'AFPointsUsed',
        Format => 'int16u',
        PrintConv => {
            BITMASK => {
                0 => 'Center',
                1 => 'Top',
                2 => 'Bottom',
                3 => 'Left',
                4 => 'Right',
                5 => 'Upper-left',
                6 => 'Upper-right',
                7 => 'Lower-left',
                8 => 'Lower-right',
                9 => 'Far Left',
                10 => 'Far Right',
            },
        },
    },
);

# ref PH
%Image::ExifTool::Nikon::CaptureOffsets = (
    PROCESS_PROC => \&ProcessNikonCaptureOffsets,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => 'IFD0_Offset',
    2 => 'PreviewIFD_Offset',
    3 => 'SubIFD_Offset',
);

# ref 4
%Image::ExifTool::Nikon::ColorBalance1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'WB_RBGGLevels',
        Format => 'int16u[4]',
        Protected => 1,
    },
);

# ref 4
%Image::ExifTool::Nikon::ColorBalance2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'WB_RGGBLevels',
        Format => 'int16u[4]',
        Protected => 1,
    },
);

# ref 4
%Image::ExifTool::Nikon::ColorBalance3 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'WB_RGBGLevels',
        Format => 'int16u[4]',
        Protected => 1,
    },
);

%Image::ExifTool::Nikon::Type2 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0003 => {
        Name => 'Quality',
        Description => 'Image Quality',
    },
    0x0004 => 'ColorMode',
    0x0005 => 'ImageAdjustment',
    0x0006 => 'CCDSensitivity',
    0x0007 => 'WhiteBalance',
    0x0008 => 'Focus',
    0x000A => 'DigitalZoom',
    0x000B => 'Converter',
);

# these are standard EXIF tags, but they are duplicated here so we
# can change some names to extract the Nikon preview separately
%Image::ExifTool::Nikon::PreviewImage = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 1 => 'NikonPreview', 2 => 'Image'},
    0x103 => {
        Name => 'Compression',
        PrintConv => \%Image::ExifTool::Exif::compression,
        Priority => 0,
    },
    0x11a => {
        Name => 'XResolution',
        Priority => 0,
    },
    0x11b => {
        Name => 'YResolution',
        Priority => 0,
    },
    0x128 => {
        Name => 'ResolutionUnit',
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
        Priority => 0,
    },
    0x201 => {
        Name => 'PreviewImageStart',
        Flags => [ 'IsOffset', 'Permanent' ],
        OffsetPair => 0x202, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'NikonPreview',
        Protected => 2,
    },
    0x202 => {
        Name => 'PreviewImageLength',
        Flags => 'Permanent' ,
        OffsetPair => 0x201, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'NikonPreview',
        Protected => 2,
    },
    0x213 => {
        Name => 'YCbCrPositioning',
        PrintConv => {
            1 => 'Centered',
            2 => 'Co-sited',
        },
        Priority => 0,
    },
);

# these are duplicated enough times to make it worthwhile to define them centrally
my %nikonApertureConversions = (
    ValueConv => '2**($val/24)',
    ValueConvInv => '$val>0 ? 24*log($val)/log(2) : 0',
    PrintConv => 'sprintf("%.1f",$val)',
    PrintConvInv => '$val',
);

my %nikonFocalConversions = (
    ValueConv => '5 * 2**($val/24)',
    ValueConvInv => '$val>0 ? 24*log($val/5)/log(2) : 0',
    PrintConv => 'sprintf("%.1fmm",$val)',
    PrintConvInv => '$val=~s/\s*mm$//;$val',
);

# Version 100 Nikon lens data
%Image::ExifTool::Nikon::LensData00 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    NOTES => 'This structure is used by the D100 and newer D1X models.',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => {
        Name => 'LensDataVersion',
        Format => 'undef[4]',
    },
    0x06 => { #8
        Name => 'LensIDNumber',
        Notes => 'see LensID values below',
    },
    0x07 => { #8
        Name => 'LensFStops',
        ValueConv => '$val / 12',
        ValueConvInv => '$val * 12',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
    },
    0x08 => { #8/9
        Name => 'MinFocalLength',
        %nikonFocalConversions,
    },
    0x09 => { #8/9
        Name => 'MaxFocalLength',
        %nikonFocalConversions,
    },
    0x0a => { #8
        Name => 'MaxApertureAtMinFocal',
        %nikonApertureConversions,
    },
    0x0b => { #8
        Name => 'MaxApertureAtMaxFocal',
        %nikonApertureConversions,
    },
    0x0c => 'MCUVersion', #8
);

# Nikon lens data (note: needs decrypting if LensDataVersion is 0201)
%Image::ExifTool::Nikon::LensData01 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    NOTES => q{
        Nikon encrypts the LensData information below if LensDataVersion is 0201,
        but  the decryption algorithm is known so the information can be extracted.
        It isn't yet writable, however, because the encryption adds complications
        which make writing more difficult.
    },
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => {
        Name => 'LensDataVersion',
        Format => 'undef[4]',
    },
    0x05 => { #8
        Name => 'AFAperture',
        %nikonApertureConversions,
    },
    0x08 => { #8
        Name => 'FocusPosition',
        PrintConv => 'sprintf("0x%02x", $val)',
        PrintConvInv => '$val',
    },
    0x09 => { #8/9
        # With older AF lenses this does not work... (ref 13)
        # ie) AF Nikkor 50mm f/1.4 => 48 (0x30)
        # AF Zoom-Nikkor 35-105mm f/3.5-4.5 => @35mm => 15 (0x0f), @105mm => 141 (0x8d)
        Name => 'FocusDistance',
        ValueConv => '0.01 * 10**($val/40)', # in m
        ValueConvInv => '$val>0 ? 40*log($val*100)/log(10) : 0',
        PrintConv => '$val ? sprintf("%.2f m",$val) : "inf"',
        PrintConvInv => '$val eq "inf" ? 0 : $val =~ s/\s.*//, $val',
    },
    0x0a => { #8/9
        Name => 'FocalLength',
        Priority => 0,
        %nikonFocalConversions,
    },
    0x0b => { #8
        Name => 'LensIDNumber',
        Notes => 'see LensID values below',
    },
    0x0c => { #8
        Name => 'LensFStops',
        ValueConv => '$val / 12',
        ValueConvInv => '$val * 12',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
    },
    0x0d => { #8/9
        Name => 'MinFocalLength',
        %nikonFocalConversions,
    },
    0x0e => { #8/9
        Name => 'MaxFocalLength',
        %nikonFocalConversions,
    },
    0x0f => { #8
        Name => 'MaxApertureAtMinFocal',
        %nikonApertureConversions,
    },
    0x10 => { #8
        Name => 'MaxApertureAtMaxFocal',
        %nikonApertureConversions,
    },
    0x11 => 'MCUVersion', #8
    0x12 => { #8
        Name => 'EffectiveMaxAperture',
        %nikonApertureConversions,
    },
);

# tags in Nikon QuickTime videos (PH - observations with Coolpix S3)
# (note: very similar to information in Pentax videos)
%Image::ExifTool::Nikon::MOV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        This information is found in Nikon QT video images, and is very similar to
        information found in Pentax MOV videos.
    },
    0x00 => {
        Name => 'Make',
        Format => 'string[5]',
        PrintConv => 'ucfirst(lc($val))',
    },
    0x18 => {
        Name => 'Model',
        Format => 'string[8]',
    },
    0x26 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x2a => {
        Name => 'FNumber',
        Format => 'int32u',
        ValueConv => '$val * 0.1',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x32 => {
        Name => 'ExposureCompensation',
        Format => 'int32s',
        ValueConv => '$val * 0.1',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x44 => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Fluorescent', #2
            4 => 'Tungsten',
            5 => 'Manual',
        },
    },
    0x48 => {
        Name => 'FocalLength',
        Writable => 'int32u',
        ValueConv => '$val * 0.1',
        PrintConv => 'sprintf("%.1fmm",$val)',
    },
    0xaf => {
        Name => 'Software',
        Format => 'string[16]',
    },
    0xdf => { # (this is a guess ... could also be offset 0xdb)
        Name => 'ISO',
        Format => 'int16u',
    },
);


# Nikon composite tags
%Image::ExifTool::Nikon::Composite = (
    GROUPS => { 2 => 'Camera' },
    LensSpec => {
        Description => 'Lens',
        Require => {
            0 => 'Nikon:Lens',
            1 => 'Nikon:LensType',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '"$prt[0] $prt[1]"',
    },
    LensID => {
        SeparateTable => 'Nikon',   # print values in a separate table
        Require => {
            0 => 'Nikon:LensIDNumber',
            1 => 'LensFStops',
            2 => 'MinFocalLength',
            3 => 'MaxFocalLength',
            4 => 'MaxApertureAtMinFocal',
            5 => 'MaxApertureAtMaxFocal',
            6 => 'MCUVersion',
            7 => 'Nikon:LensType',
        },
        # construct lens ID string as per ref 11
        ValueConv => 'uc(join(" ",(unpack("H*",pack("C*",@raw)) =~ /../g)))',
        PrintConv => \%nikonLensIDs,
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Nikon::Composite');


#------------------------------------------------------------------------------
# Clean up formatting of string values
# Inputs: 0) string value
# Returns: formatted string value
# - removes trailing spaces and changes case to something more sensible
sub FormatString($)
{
    my $str = shift;
    # limit string length (can be very long for some unknown tags)
    if (length($str) > 60) {
        $str = substr($str,0,55) . "[...]";
    } else {
        $str =~ s/\s+$//;   # remove trailing white space and null terminator
        # Don't change case of hyphenated strings (like AF-S) or non-words (no vowels)
        unless ($str =~ /-/ or $str !~ /[AEIOUY]/) {
            # change all letters but the first to lower case
            $str =~ s/([A-Z]{1})([A-Z]+)/$1\L$2/g;
        }
    }
    return $str;
}

#------------------------------------------------------------------------------
# decoding tables from ref 4
my @xlat = (
  [ 0xc1,0xbf,0x6d,0x0d,0x59,0xc5,0x13,0x9d,0x83,0x61,0x6b,0x4f,0xc7,0x7f,0x3d,0x3d,
    0x53,0x59,0xe3,0xc7,0xe9,0x2f,0x95,0xa7,0x95,0x1f,0xdf,0x7f,0x2b,0x29,0xc7,0x0d,
    0xdf,0x07,0xef,0x71,0x89,0x3d,0x13,0x3d,0x3b,0x13,0xfb,0x0d,0x89,0xc1,0x65,0x1f,
    0xb3,0x0d,0x6b,0x29,0xe3,0xfb,0xef,0xa3,0x6b,0x47,0x7f,0x95,0x35,0xa7,0x47,0x4f,
    0xc7,0xf1,0x59,0x95,0x35,0x11,0x29,0x61,0xf1,0x3d,0xb3,0x2b,0x0d,0x43,0x89,0xc1,
    0x9d,0x9d,0x89,0x65,0xf1,0xe9,0xdf,0xbf,0x3d,0x7f,0x53,0x97,0xe5,0xe9,0x95,0x17,
    0x1d,0x3d,0x8b,0xfb,0xc7,0xe3,0x67,0xa7,0x07,0xf1,0x71,0xa7,0x53,0xb5,0x29,0x89,
    0xe5,0x2b,0xa7,0x17,0x29,0xe9,0x4f,0xc5,0x65,0x6d,0x6b,0xef,0x0d,0x89,0x49,0x2f,
    0xb3,0x43,0x53,0x65,0x1d,0x49,0xa3,0x13,0x89,0x59,0xef,0x6b,0xef,0x65,0x1d,0x0b,
    0x59,0x13,0xe3,0x4f,0x9d,0xb3,0x29,0x43,0x2b,0x07,0x1d,0x95,0x59,0x59,0x47,0xfb,
    0xe5,0xe9,0x61,0x47,0x2f,0x35,0x7f,0x17,0x7f,0xef,0x7f,0x95,0x95,0x71,0xd3,0xa3,
    0x0b,0x71,0xa3,0xad,0x0b,0x3b,0xb5,0xfb,0xa3,0xbf,0x4f,0x83,0x1d,0xad,0xe9,0x2f,
    0x71,0x65,0xa3,0xe5,0x07,0x35,0x3d,0x0d,0xb5,0xe9,0xe5,0x47,0x3b,0x9d,0xef,0x35,
    0xa3,0xbf,0xb3,0xdf,0x53,0xd3,0x97,0x53,0x49,0x71,0x07,0x35,0x61,0x71,0x2f,0x43,
    0x2f,0x11,0xdf,0x17,0x97,0xfb,0x95,0x3b,0x7f,0x6b,0xd3,0x25,0xbf,0xad,0xc7,0xc5,
    0xc5,0xb5,0x8b,0xef,0x2f,0xd3,0x07,0x6b,0x25,0x49,0x95,0x25,0x49,0x6d,0x71,0xc7 ],
  [ 0xa7,0xbc,0xc9,0xad,0x91,0xdf,0x85,0xe5,0xd4,0x78,0xd5,0x17,0x46,0x7c,0x29,0x4c,
    0x4d,0x03,0xe9,0x25,0x68,0x11,0x86,0xb3,0xbd,0xf7,0x6f,0x61,0x22,0xa2,0x26,0x34,
    0x2a,0xbe,0x1e,0x46,0x14,0x68,0x9d,0x44,0x18,0xc2,0x40,0xf4,0x7e,0x5f,0x1b,0xad,
    0x0b,0x94,0xb6,0x67,0xb4,0x0b,0xe1,0xea,0x95,0x9c,0x66,0xdc,0xe7,0x5d,0x6c,0x05,
    0xda,0xd5,0xdf,0x7a,0xef,0xf6,0xdb,0x1f,0x82,0x4c,0xc0,0x68,0x47,0xa1,0xbd,0xee,
    0x39,0x50,0x56,0x4a,0xdd,0xdf,0xa5,0xf8,0xc6,0xda,0xca,0x90,0xca,0x01,0x42,0x9d,
    0x8b,0x0c,0x73,0x43,0x75,0x05,0x94,0xde,0x24,0xb3,0x80,0x34,0xe5,0x2c,0xdc,0x9b,
    0x3f,0xca,0x33,0x45,0xd0,0xdb,0x5f,0xf5,0x52,0xc3,0x21,0xda,0xe2,0x22,0x72,0x6b,
    0x3e,0xd0,0x5b,0xa8,0x87,0x8c,0x06,0x5d,0x0f,0xdd,0x09,0x19,0x93,0xd0,0xb9,0xfc,
    0x8b,0x0f,0x84,0x60,0x33,0x1c,0x9b,0x45,0xf1,0xf0,0xa3,0x94,0x3a,0x12,0x77,0x33,
    0x4d,0x44,0x78,0x28,0x3c,0x9e,0xfd,0x65,0x57,0x16,0x94,0x6b,0xfb,0x59,0xd0,0xc8,
    0x22,0x36,0xdb,0xd2,0x63,0x98,0x43,0xa1,0x04,0x87,0x86,0xf7,0xa6,0x26,0xbb,0xd6,
    0x59,0x4d,0xbf,0x6a,0x2e,0xaa,0x2b,0xef,0xe6,0x78,0xb6,0x4e,0xe0,0x2f,0xdc,0x7c,
    0xbe,0x57,0x19,0x32,0x7e,0x2a,0xd0,0xb8,0xba,0x29,0x00,0x3c,0x52,0x7d,0xa8,0x49,
    0x3b,0x2d,0xeb,0x25,0x49,0xfa,0xa3,0xaa,0x39,0xa7,0xc5,0xa7,0x50,0x11,0x36,0xfb,
    0xc6,0x67,0x4a,0xf5,0xa5,0x12,0x65,0x7e,0xb0,0xdf,0xaf,0x4e,0xb3,0x61,0x7f,0x2f ]
);

# decrypt Nikon data block (ref 4)
# Inputs: 0) reference to data block, 1) serial number key, 2) shutter count key
#         4) optional start offset (default 0)
#         5) optional number of bytes to decode (default to the end of the data)
# Returns: Decrypted data block
sub Decrypt($$$;$$)
{
    my ($dataPt, $serial, $count, $start, $len) = @_;
    $start or $start = 0;
    my $end = $len ? $start + $len : length($$dataPt);
    my $i;
    my $key = 0;
    for ($i=0; $i<4; ++$i) {
        $key ^= ($count >> ($i*8)) & 0xff;
    }
    my $ci = $xlat[0][$serial & 0xff];
    my $cj = $xlat[1][$key];
    my $ck = 0x60;
    my @data = unpack('C*',$$dataPt);
    for ($i=$start; $i<$end; ++$i) {
        $cj = ($cj + $ci * $ck) & 0xff;
        $ck = ($ck + 1) & 0xff;
        $data[$i] ^= $cj;
    }
    return pack('C*',@data);
}

#------------------------------------------------------------------------------
# process Nikon Encrypted data block
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success
sub ProcessNikonEncrypted($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    # get the encrypted directory data
    my $buff = substr(${$$dirInfo{DataPt}}, $$dirInfo{DirStart}, $$dirInfo{DirLen});
    # save it until we have enough information to decrypt it later
    push @{$exifTool->{NikonInfo}->{Encrypted}}, [ $tagTablePtr, $buff, $$dirInfo{TagInfo}];
    if ($exifTool->Options('Verbose')) {
        my $indent = substr($exifTool->{INDENT}, 0, -2);
        $exifTool->VPrint(0, $indent, "[$dirInfo->{TagInfo}->{Name} directory to be decrypted later]\n");
    }
    return 1;
}

#------------------------------------------------------------------------------
# process Nikon Capture Offsets IFD (ref PH)
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success
# Notes: This isn't a normal IFD, but is close...
sub ProcessNikonCaptureOffsets($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $success = 0;
    return 0 unless $dirLen > 2;
    my $count = Get16u($dataPt, $dirStart);
    return 0 unless $count and $count * 12 + 2 <= $dirLen;
    if ($exifTool->Options('Verbose')) {
        $exifTool->VerboseDir('NikonCaptureOffsets', $count);
    }
    my $index;
    for ($index=0; $index<$count; ++$index) {
        my $pos = $dirStart + 12 * $index + 2;
        my $tagID = Get32u($dataPt, $pos);
        my $value = Get32u($dataPt, $pos + 4);
        $exifTool->HandleTag($tagTablePtr, $tagID, $value,
            Index  => $index,
            DataPt => $dataPt,
            Start  => $pos,
            Size   => 12,
        ) and $success = 1;
    }
    return $success;
}

#------------------------------------------------------------------------------
# Process Nikon Makernotes directory
# Inputs: 0) ExifTool object reference
#         1) Reference to directory information hash
#         2) Pointer to tag table for this directory
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessNikon($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $verbose = $exifTool->Options('Verbose');
    my $nikonInfo = $exifTool->{NikonInfo} = { };
    my @encrypted;  # list to save encrypted data
    $$nikonInfo{Encrypted} = \@encrypted;
    my $rtnVal = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $tagTablePtr);
    # process any encrypted information we found
    my $encryptedDir;
    if (@encrypted) {
        my $serial = $exifTool->{NikonInfo}->{SerialNumber} || 0;
        my $count = $exifTool->{NikonInfo}->{ShutterCount};
        unless (defined $count) {
            $exifTool->Warn("Can't decrypt Nikon information (no ShutterCount key)");
            undef @encrypted;
        }
        foreach $encryptedDir (@encrypted) {
            my ($subTablePtr, $data, $tagInfo) = @$encryptedDir;
            my ($start, $len, $offset);
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                $start = $tagInfo->{SubDirectory}->{DecryptStart};
                $len = $tagInfo->{SubDirectory}->{DecryptLen};
                $offset = $tagInfo->{SubDirectory}->{DirOffset};
            }
            $start or $start = 0;
            if (defined $offset) {
                # offset, if specified, is releative to start of encrypted data
                $offset += $start;
            } else {
                $offset = 0;
            }
            my $maxLen = length($data) - $start;
            if ($len) {
                $len = $maxLen if $len > $maxLen;
            } else {
                $len = $maxLen;
            }
            # use fixed serial numbers if no good serial number found
            unless ($serial =~ /^\d+$/) {
                if ($exifTool->{CameraModel} =~ /\bD200$/) {
                    $serial = 0x60; # D200 (ref 10)
                } else {
                    $serial = 0x22; # D50 (ref 8)
                }
            }
            $data = Decrypt(\$data, $serial, $count, $start, $len);
            my %subdirInfo = (
                DataPt   => \$data,
                DirStart => $offset,
                DirLen   => length($data),
            );
            if ($verbose > 2) {
                $exifTool->VerboseDir("Decrypted $$tagInfo{Name}");
                my %parms = (
                    Prefix => $exifTool->{INDENT},
                    Out => $exifTool->Options('TextOut'),
                );
                $parms{MaxLen} = 96 unless $verbose > 3;
                Image::ExifTool::HexDump(\$data, undef, %parms);
            }
            # process the decrypted information
            $exifTool->ProcessBinaryData(\%subdirInfo, $subTablePtr);
        }
    }
    delete $exifTool->{NikonInfo};
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Nikon - Nikon EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Nikon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://members.aol.com/khancock/pilot/nbuddy/>

=item L<http://www.rottmerhusen.com/objektives/lensid/nikkor.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Joseph Heled, Thomas Walter, Brian Ristuccia, Danek Duvall, Tom
Christiansen, Robert Rottmerhusen, Werner Kober and Roger Larsson for their
help figuring out some Nikon tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Nikon Tags>,
L<Image::ExifTool::TagNames/NikonCapture Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
