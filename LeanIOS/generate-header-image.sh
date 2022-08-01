#!/bin/sh

# Use Mac OSX's utility to create app icons of various sizes.

BASEDIR=$(dirname $0)

sips -z 80 80 -s format png --out $BASEDIR/Images.xcassets/HeaderImage.imageset/header.png $BASEDIR/iosHeaderImage 2>&1
sips -z 160 160 -s format png --out $BASEDIR/Images.xcassets/HeaderImage.imageset/header@2x.png $BASEDIR/iosHeaderImage 2>&1
sips -z 240 240 -s format png --out $BASEDIR/Images.xcassets/HeaderImage.imageset/header@3x.png $BASEDIR/iosHeaderImage 2>&1

optipng $BASEDIR/Images.xcassets/HeaderImage.imageset/header.png 2>&1
optipng $BASEDIR/Images.xcassets/HeaderImage.imageset/header@2x.png 2>&1
optipng $BASEDIR/Images.xcassets/HeaderImage.imageset/header@3x.png 2>&1

sips -z 80 80 -s format png --out $BASEDIR/Images.xcassets/HeaderImage.imageset/headerDark.png $BASEDIR/iosHeaderImageDark 2>&1
sips -z 160 160 -s format png --out $BASEDIR/Images.xcassets/HeaderImage.imageset/headerDark@2x.png $BASEDIR/iosHeaderImageDark 2>&1
sips -z 240 240 -s format png --out $BASEDIR/Images.xcassets/HeaderImage.imageset/headerDark@3x.png $BASEDIR/iosHeaderImageDark 2>&1

optipng $BASEDIR/Images.xcassets/HeaderImage.imageset/headerDark.png 2>&1
optipng $BASEDIR/Images.xcassets/HeaderImage.imageset/headerDark@2x.png 2>&1
optipng $BASEDIR/Images.xcassets/HeaderImage.imageset/headerDark@3x.png 2>&1
