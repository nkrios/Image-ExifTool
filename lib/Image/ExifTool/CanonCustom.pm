#------------------------------------------------------------------------------
# File:         CanonCustom.pm
#
# Description:  Read and write Canon Custom functions
#
# Revisions:    11/25/2003  - P. Harvey Created
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Christian Koller private communication (tests with the 20D)
#               3) Rainer Honle private communication (tests with the 5D)
#------------------------------------------------------------------------------

package Image::ExifTool::CanonCustom;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Canon;

$VERSION = '1.10';

sub ProcessCanonCustom($$$);
sub WriteCanonCustom($$$);
sub CheckCanonCustom($$$);
sub ConvertPFn($);
sub ConvertPFnInv($);

my %onOff = ( 0 => 'On', 1 => 'Off' );
my %offOn = ( 0 => 'Off', 1 => 'On' );
my %disableEnable = ( 0 => 'Disable', 1 => 'Enable' );
my %enableDisable = ( 0 => 'Enable', 1 => 'Disable' );
my %convPFn = ( PrintConv => \&ConvertPfn, PrintConvInv => \&ConvertPfnInv );

#------------------------------------------------------------------------------
# Custom functions for the 1D
# CanonCustom (keys are custom function number)
%Image::ExifTool::CanonCustom::Functions1D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    0 => {
        Name => 'FocusingScreen',
        PrintConv => {
            0 => 'Ec-N, R',
            1 => 'Ec-A,B,C,CII,CIII,D,H,I,L',
        },
    },
    1 => {
        Name => 'FinderDisplayDuringExposure',
        PrintConv => \%offOn,
    },
    2 => {
        Name => 'ShutterReleaseNoCFCard',
        Description => 'Shutter Release W/O CF Card',
        PrintConv => {
            0 => 'Yes',
            1 => 'No',
        },
    },
    3 => {
        Name => 'ISOSpeedExpansion',
        Description => 'ISO Speed Expansion',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
    4 => {
        Name => 'ShutterAELButton',
        Description => 'Shutter Button/AEL Button',
        PrintConv => {
            0 => 'AF/AE lock stop',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    5 => {
        Name => 'ManualTv',
        Description => 'Manual Tv/Av For M',
        PrintConv => {
            0 => 'Tv=Main/Av=Control',
            1 => 'Tv=Control/Av=Main',
            2 => 'Tv=Main/Av=Main w/o lens',
            3 => 'Tv=Control/Av=Main w/o lens',
        },
    },
    6 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3-stop set, 1/3-stop comp.',
            1 => '1-stop set, 1/3-stop comp.',
            2 => '1/2-stop set, 1/2-stop comp.',
        },
    },
    7 => {
        Name => 'USMLensElectronicMF',
        PrintConv => {
            0 => 'Turns on after one-shot AF',
            1 => 'Turns off after one-shot AF',
            2 => 'Always turned off',
        },
    },
    8 => {
        Name => 'LCDPanels',
        Description => 'Top/Back LCD Panels',
        PrintConv => {
            0 => 'Remain. shots/File no.',
            1 => 'ISO/Remain. shots',
            2 => 'ISO/File no.',
            3 => 'Shots in folder/Remain. shots',
        },
    },
    9 => {
        Name => 'AEBSequence',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    10 => {
        Name => 'AFPointIllumination',
        PrintConv => {
            0 => 'On',
            1 => 'Off',
            2 => 'On without dimming',
            3 => 'Brighter',
        },
    },
    11 => {
        Name => 'AFPointSelection',
        PrintConv => {
            0 => 'H=AF+Main/V=AF+Command',
            1 => 'H=Comp+Main/V=Comp+Command',
            2 => 'H=Command only/V=Assist+Main',
            3 => 'H=FEL+Main/V=FEL+Command',
        },
    },
    12 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    13 => {
        Name => 'AFPointSpotMetering',
        Description => 'No. AF Points/Spot Metering',
        PrintConv => {
            0 => '45/Center AF point',
            1 => '11/Active AF point',
            2 => '11/Center AF point',
            3 => '9/Active AF point',
        },
    },
    14 => {
        Name => 'FillFlashAutoReduction',
        PrintConv => \%enableDisable,
    },
    15 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    16 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    17 => {
        Name => 'AFPointActivationArea',
        PrintConv => {
            0 => 'Single AF point',
            1 => 'Expanded (TTL. of 7 AF points)',
            2 => 'Automatic expanded (max. 13)',
        },
    },
    18 => {
        Name => 'SwitchToRegisteredAFPoint',
        PrintConv => {
            0 => 'Assist + AF',
            1 => 'Assist',
            2 => 'Only while pressing assist',
        },
    },
    19 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock while metering',
            3 => 'AF point: M -> Auto / Auto -> Ctr.',
            4 => 'AF mode: ONE SHOT <-> AI SERVO',
            5 => 'IS start',
        },
    },
    20 => {
        Name => 'AIServoTrackingSensitivity',
        PrintConv => {
            0 => 'Standard',
            1 => 'Slow',
            2 => 'Moderately slow',
            3 => 'Moderately fast',
            4 => 'Fast',
        },
    },
);

# Custom functions for the 5D (ref 3)
%Image::ExifTool::CanonCustom::Functions5D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    0 => {
        Name => 'FocusingScreen',
        PrintConv => {
            0 => 'Ee-A',
            1 => 'Ee-D',
            2 => 'Ee-S',
        },
    },
    1 => {
        Name => 'SetFunctionWhenShooting',
        PrintConv => {
            0 => 'Default (no function)',
            1 => 'Change quality',
            2 => 'Change Parameters',
            3 => 'Menu display',
            4 => 'Image replay',
        },
    },
    2 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => \%offOn,
    },
    3 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/200 Fixed',
        },
    },
    4 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    5 => {
        Name => 'AFAssistBeam',
        PrintConv => {
            0 => 'Emits',
            1 => 'Does not emit',
        },
    },
    6 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1/2 Stop',
        },
    },
    7 => {
        Name => 'FlashFiring',
        PrintConv => {
            0 => 'Fires',
            1 => 'Does not fire',
        },
    },
    8 => {
        Name => 'ISOExpansion',
        PrintConv => \%offOn,
    },
    9 => {
        Name => 'AEBSequence',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    10 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    11 => {
        Name => 'MenuButtonDisplayPosition',
        PrintConv => {
            0 => 'Previous (top if power off)',
            1 => 'Previous',
            2 => 'Top',
        },
    },
    12 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    13 => {
        Name => 'AFPointSelectionMethod',
        PrintConv => {
            0 => 'Normal',
            1 => 'Multi-controller direct',
            2 => 'Quick Control Dial direct',
        },
    },
    14 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    15 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    16 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    17 => {
        Name => 'AFPointActivationArea',
        PrintConv => {
            0 => 'Standard',
            1 => 'Expanded',
        },
    },
    18 => {
        Name => 'LCDDisplayReturnToShoot',
        PrintConv => {
            0 => 'With Shutter Button only',
            1 => 'Also with * etc.',
        },
    },
    19 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock while metering',
            3 => 'AF point: M -> Auto / Auto -> Ctr.',
            4 => 'ONE SHOT <-> AI SERVO',
            5 => 'IS start',
        },
    },
    20 => {
        Name => 'AddOriginalDecisionData',
        PrintConv => \%offOn,
    },
);

# Custom functions for 10D
%Image::ExifTool::CanonCustom::Functions10D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    1 => {
        Name => 'SetButtonFunction',
        PrintConv => {
            0 => 'Not assigned',
            1 => 'Change quality',
            2 => 'Change parameters',
            3 => 'Menu display',
            4 => 'Image replay',
        },
    },
    2 => {
        Name => 'ShutterReleaseNoCFCard',
        Description => 'Shutter Release W/O CF Card',
        PrintConv => {
            0 => 'Yes',
            1 => 'No',
        },
    },
    3 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/200 Fixed',
        },
    },
    4 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    5 => {
        Name => 'AFAssist',
        Description => 'AF Assist/Flash Firing',
        PrintConv => {
            0 => 'Emits/Fires',
            1 => 'Does not emit/Fires',
            2 => 'Only ext. flash emits/Fires',
            3 => 'Emits/Does not fire',
        },
    },
    6 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/2 Stop',
            1 => '1/3 Stop',
        },
    },
    7 => {
        Name => 'AFPointRegistration',
        PrintConv => {
            0 => 'Center',
            1 => 'Bottom',
            2 => 'Right',
            3 => 'Extreme Right',
            4 => 'Automatic',
            5 => 'Extreme Left',
            6 => 'Left',
            7 => 'Top',
        },
    },
    8 => {
        Name => 'RawAndJpgRecording',
        PrintConv => {
            0 => 'RAW+Small/Normal',
            1 => 'RAW+Small/Fine',
            2 => 'RAW+Medium/Normal',
            3 => 'RAW+Medium/Fine',
            4 => 'RAW+Large/Normal',
            5 => 'RAW+Large/Fine',
        },
    },
    9 => {
        Name => 'AEBSequence',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    10 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    11 => {
        Name => 'MenuButtonDisplayPosition',
        PrintConv => {
            0 => 'Previous (top if power off)',
            1 => 'Previous',
            2 => 'Top',
        },
    },
    12 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    13 => {
        Name => 'AssistButtonFunction',
        PrintConv => {
            0 => 'Normal',
            1 => 'Select Home Position',
            2 => 'Select HP (while pressing)',
            3 => 'Av+/- (AF point by QCD)',
            4 => 'FE lock',
        },
    },
    14 => {
        Name => 'FillFlashAutoReduction',
        PrintConv => \%enableDisable,
    },
    15 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    16 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    17 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF Stop',
            1 => 'Operate AF',
            2 => 'Lock AE and start timer',
        },
    },
);

# Custom functions for the 20D (ref 2)
%Image::ExifTool::CanonCustom::Functions20D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    0 => {
        Name => 'SetFunctionWhenShooting',
        PrintConv => {
            0 => 'Default (no function)',
            1 => 'Change quality',
            2 => 'Change Parameters',
            3 => 'Menu display',
            4 => 'Image replay',
        },
    },
    1 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => \%offOn,
    },
    2 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/250 Fixed',
        },
    },
    3 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    4 => {
        Name => 'AFAssistBeam',
        PrintConv => {
            0 => 'Emits',
            1 => 'Does not emit',
            2 => 'Only ext. flash emits',
        },
    },
    5 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1/2 Stop',
        },
    },
    6 => {
        Name => 'FlashFiring',
        PrintConv => {
            0 => 'Fires',
            1 => 'Does not fire',
        },
    },
    7 => {
        Name => 'ISOExpansion',
        PrintConv => \%offOn,
    },
    8 => {
        Name => 'AEBSequence',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    9 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    10 => {
        Name => 'MenuButtonDisplayPosition',
        PrintConv => {
            0 => 'Previous (top if power off)',
            1 => 'Previous',
            2 => 'Top',
        },
    },
    11 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    12 => {
        Name => 'AFPointSelectionMethod',
        PrintConv => {
            0 => 'Normal',
            1 => 'Multi-controller direct',
            2 => 'Quick Control Dial direct',
        },
    },
    13 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    14 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    15 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    16 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock while metering',
            3 => 'AF point: M -> Auto / Auto -> Ctr.',
            4 => 'ONE SHOT <-> AI SERVO',
            5 => 'IS start',
        },
    },
    17 => {
        Name => 'AddOriginalDecisionData',
        PrintConv => \%offOn,
    },
);

# Custom functions for the 30D (PH)
%Image::ExifTool::CanonCustom::Functions30D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    1 => {
        Name => 'SetFunctionWhenShooting',
        PrintConv => {
            0 => 'Default (no function)',
            1 => 'Change quality',
            2 => 'Change Picture Style',
            3 => 'Menu display',
            4 => 'Image replay',
        },
    },
    2 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
        },
    },
    3 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/250 Fixed',
        },
    },
    4 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    5 => {
        Name => 'AFAssistBeam',
        PrintConv => {
            0 => 'Emits',
            1 => 'Does not emit',
            2 => 'Only ext. flash emits',
        },
    },
    6 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1/2 Stop',
        },
    },
    7 => {
        Name => 'FlashFiring',
        PrintConv => {
            0 => 'Fires',
            1 => 'Does not fire',
        },
    },
    8 => {
        Name => 'ISOExpansion',
        PrintConv => \%offOn,
    },
    9 => {
        Name => 'AEBSequence',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    10 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    11 => {
        Name => 'MenuButtonDisplayPosition',
        PrintConv => {
            0 => 'Previous (top if power off)',
            1 => 'Previous',
            2 => 'Top',
        },
    },
    12 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    13 => {
        Name => 'AFPointSelectionMethod',
        PrintConv => {
            0 => 'Normal',
            1 => 'Multi-controller direct',
            2 => 'Quick Control Dial direct',
        },
    },
    14 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    15 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    16 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    17 => {
        Name => 'MagnifiedView',
        PrintConv => {
            0 => 'Image playback only',
            1 => 'Image review and playback',
        },
    },
    18 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock while metering',
            3 => 'AF point: M -> Auto / Auto -> Ctr.',
            4 => 'ONE SHOT <-> AI SERVO',
            5 => 'IS start',
        },
    },
    19 => {
        Name => 'AddOriginalDecisionData',
        PrintConv => \%offOn,
    },
);

# Custom functions for the 350D (PH - unconfirmed)
%Image::ExifTool::CanonCustom::Functions350D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    0 => {
        Name => 'SetButtonCrossKeysFunc',
        PrintConv => {
            0 => 'Normal',
            1 => 'Set: Quality',
            2 => 'Set: Parameter',
            3 => 'Set: Playback',
            4 => 'Cross keys: AF frame selec.',
        },
    },
    1 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => \%offOn,
    },
    2 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/200 Fixed',
        },
    },
    3 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    4 => {
        Name => 'AFAssistBeam',
        PrintConv => {
            0 => 'Emits',
            1 => 'Does not emit',
            2 => 'Only emits ext. flash',
        },
    },
    5 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1/2 Stop',
        },
    },
    6 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    7 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    8 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
);

# Custom functions for the D30/D60
%Image::ExifTool::CanonCustom::FunctionsD30 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    NOTES => 'Custom functions for the EOS-D30 and D60.',
    WRITABLE => 'int8u',
    1 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => \%offOn,
    },
    2 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock',
            3 => 'AE+release/AE+AF',
        },
    },
    3 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    4 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/2 Stop',
            1 => '1/3 Stop',
        },
    },
    5 => {
        Name => 'AFAssist',
        PrintConv => {
            0 => 'Emits/Fires',
            1 => 'Does not emit/Fires',
            2 => 'Only ext. flash emits/Fires',
            3 => 'Emits/Does not fire',
        },
    },
    6 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/200 Fixed',
        },
    },
    7 => {
        Name => 'AEBSequence',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    8 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    9 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF Stop',
            1 => 'Operate AF',
            2 => 'Lock AE and start timer',
        },
    },
    10 => {
        Name => 'FillFlashAutoReduction',
        PrintConv => \%enableDisable,
    },
    11 => {
        Name => 'MenuButtonReturn',
        PrintConv => {
            0 => 'Top',
            1 => 'Previous (volatile)',
            2 => 'Previous',
        },
    },
    12 => {
        Name => 'SetButtonFunction',
        PrintConv => {
            0 => 'Not assigned',
            1 => 'Change quality',
            2 => 'Change ISO speed',
            3 => 'Select parameters',
        },
    },
    13 => {
        Name => 'SensorCleaning',
        PrintConv => \%disableEnable,
    },
    14 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    15 => {
        Name => 'ShutterReleaseNoCFCard',
        Description => 'Shutter Release W/O CF Card',
        PrintConv => {
            0 => 'Yes',
            1 => 'No',
        },
    },
);

# Custom functions for unknown cameras
%Image::ExifTool::CanonCustom::FuncsUnknown = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
);

# 1D personal function settings (ref PH)
%Image::ExifTool::CanonCustom::PersonalFuncs = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    NOTES => 'Personal function settings for the EOS-1D.',
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    1 => { Name => 'PF0CustomFuncRegistration', %convPFn },
    2 => { Name => 'PF1DisableShootingModes',   %convPFn },
    3 => { Name => 'PF2DisableMeteringModes',   %convPFn },
    4 => { Name => 'PF3ManualExposureMetering', %convPFn },
    5 => { Name => 'PF4ExposureTimeLimits',     %convPFn },
    6 => { Name => 'PF5ApertureLimits',         %convPFn },
    7 => { Name => 'PF6PresetShootingModes',    %convPFn },
    8 => { Name => 'PF7BracketContinuousShoot', %convPFn },
    9 => { Name => 'PF8SetBracketShots',        %convPFn },
    10 => { Name => 'PF9ChangeBracketSequence', %convPFn },
    11 => { Name => 'PF10RetainProgramShift',   %convPFn },
    #12 => { Name => 'PF11Unused',               %convPFn },
    #13 => { Name => 'PF12Unused',               %convPFn },
    14 => { Name => 'PF13DrivePriority',        %convPFn },
    15 => { Name => 'PF14DisableFocusSearch',   %convPFn },
    16 => { Name => 'PF15DisableAFAssistBeam',  %convPFn },
    17 => { Name => 'PF16AutoFocusPointShoot',  %convPFn },
    18 => { Name => 'PF17DisableAFPointSel',    %convPFn },
    19 => { Name => 'PF18EnableAutoAFPointSel', %convPFn },
    20 => { Name => 'PF19ContinuousShootSpeed', %convPFn },
    21 => { Name => 'PF20LimitContinousShots',  %convPFn },
    22 => { Name => 'PF21EnableQuietOperation', %convPFn },
    #23 => { Name => 'PF22Unused',               %convPFn },
    24 => { Name => 'PF23SetTimerLengths',      %convPFn },
    25 => { Name => 'PF24LightLCDDuringBulb',   %convPFn },
    26 => { Name => 'PF25DefaultClearSettings', %convPFn },
    27 => { Name => 'PF26ShortenReleaseLag',    %convPFn },
    28 => { Name => 'PF27ReverseDialRotation',  %convPFn },
    29 => { Name => 'PF28NoQuickDialExpComp',   %convPFn },
    30 => { Name => 'PF29QuickDialSwitchOff',   %convPFn },
    31 => { Name => 'PF30EnlargementMode',      %convPFn },
    32 => { Name => 'PF31OriginalDecisionData', %convPFn },
);

# 1D personal function values (ref PH)
%Image::ExifTool::CanonCustom::PersonalFuncValues = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    1 => 'PF1Value',
    2 => 'PF2Value',
    3 => 'PF3Value',
    4 => {
        Name => 'PF4ExposureTimeMin',
        RawConv => '$val > 0 ? $val : 0',
        ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val*4)*log(2))*1000/8',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val*8/1000)/log(2))/4',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    5 => {
        Name => 'PF4ExposureTimeMax',
        RawConv => '$val > 0 ? $val : 0',
        ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val*4)*log(2))*1000/8',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val*8/1000)/log(2))/4',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    6 => {
        Name => 'PF5ApertureMin',
        RawConv => '$val > 0 ? $val : 0',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val*4-32)*log(2)/2)',
        ValueConvInv => '(Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))+32)/4',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    7 => {
        Name => 'PF5ApertureMax',
        RawConv => '$val > 0 ? $val : 0',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val*4-32)*log(2)/2)',
        ValueConvInv => '(Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))+32)/4',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    8 => 'PF8BracketShots',
    9 => 'PF19ShootingSpeedLow',
    10 => 'PF19ShootingSpeedHigh',
    11 => 'PF20MaxContinousShots',
    12 => 'PF23ShutterButtonTime',
    13 => 'PF23FELockTime',
    14 => 'PF23PostReleaseTime',
    15 => 'PF25AEMode',
    16 => 'PF25MeteringMode',
    17 => 'PF25DriveMode',
    18 => 'PF25AFMode',
    19 => 'PF25AFPointSel',
    20 => 'PF25ImageSize',
    21 => 'PF25WBMode',
    22 => 'PF25Parameters',
    23 => 'PF25ColorMatrix',
    24 => 'PF27Value',
);

#------------------------------------------------------------------------------
# Conversion routines
# Inputs: 0) value to convert
sub ConvertPfn($)
{
    my $val = shift;
    return $val ? ($val==1 ? 'On' : "On ($val)") : "Off";
}
sub ConvertPfnInv($)
{
    my $val = shift;
    return $1 if $val =~ /(\d+)/;
    return  1 if $val =~ /on/i;
    return  0 if $val =~ /off/i;
    return undef;
}

#------------------------------------------------------------------------------
# process Canon custom directory
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessCanonCustom($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $verbose = $exifTool->Options('Verbose');

    # first entry in array must be the size
    my $len = Image::ExifTool::Get16u($dataPt,$offset);
    unless ($len == $size or ($$exifTool{CameraModel}=~/\bD60\b/ and $len+2 == $size)) {
        $exifTool->Warn("Invalid CanonCustom data");
        return 0;
    }
    $verbose and $exifTool->VerboseDir('CanonCustom', $size/2-1);
    my $pos;
    for ($pos=2; $pos<$size; $pos+=2) {
        # ($pos is position within custom directory)
        my $val = Image::ExifTool::Get16u($dataPt,$offset+$pos);
        my $tag = ($val >> 8);
        $val = ($val & 0xff);
        $exifTool->HandleTag($tagTablePtr, $tag, $val,
            Index  => $pos/2-1,
            Format => 'int8u',
            Count  => 1,
            Size   => 1,
        );
    }
    return 1;
}

#------------------------------------------------------------------------------
# check new value for Canon custom data block
# Inputs: 0) ExifTool object reference, 1) tagInfo hash reference,
#         2) raw value reference
# Returns: error string or undef (and may modify value) on success
sub CheckCanonCustom($$$)
{
    my ($exifTool, $tagInfo, $valPtr) = @_;
    return Image::ExifTool::CheckValue($valPtr, 'int8u');
}

#------------------------------------------------------------------------------
# write Canon custom data
# Inputs: 0) ExifTool object reference, 1) ,
#         2) tag table referencesource dirInfo reference
# Returns: New custom data block or undefined on error
sub WriteCanonCustom($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || length($$dataPt) - $dirStart;
    my $dirName = $$dirInfo{DirName};
    my $verbose = $exifTool->Options('Verbose');
    my $newData = substr($$dataPt, $dirStart, $dirLen) or return undef;
    $dataPt = \$newData;

    # first entry in array must be the size
    unless (Image::ExifTool::Get16u($dataPt,0) == $dirLen) {
        $exifTool->Warn("Invalid CanonCustom data");
        return undef;
    }
    my $newTags = $exifTool->GetNewTagInfoHash($tagTablePtr);
    my $pos;
    for ($pos=2; $pos<$dirLen; $pos+=2) {
        my $val = Image::ExifTool::Get16u($dataPt, $pos);
        my $tag = ($val >> 8);
        my $tagInfo = $$newTags{$tag};
        next unless $tagInfo;
        my $newValueHash = $exifTool->GetNewValueHash($tagInfo);
        $val = ($val & 0xff);
        next unless Image::ExifTool::IsOverwriting($newValueHash, $val);
        my $newVal = Image::ExifTool::GetNewValues($newValueHash);
        next unless defined $newVal;    # can't delete from a custom table
        Image::ExifTool::Set16u(($newVal & 0xff) + ($tag << 8), $dataPt, $pos);
        if ($verbose > 1) {
            $exifTool->VPrint(0, "    - $dirName:$$tagInfo{Name} = '$val'\n",
                                 "    + $dirName:$$tagInfo{Name} = '$newVal'\n");
        }
        ++$exifTool->{CHANGED};
    }
    return $newData;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::CanonCustom - Read and Write Canon custom functions

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

The Canon custom functions meta information is very specific to the
camera model, and is found in both the EXIF maker notes and in the
Canon RAW files.  This module contains the definitions necessary for
Image::ExifTool to read this information.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Christian Koller for his work in decoding the 20D custom
functions, and Rainer Honle for decoding the 5D custom functions.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Canon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
