#!/bin/sh

# Use Mac OSX's utility to create app icons of various sizes.

BASEDIR=$(dirname $0)

sips --resampleHeight 90 -s format png --out $BASEDIR/Images.xcassets/NavBarImage.imageset/navBar.png $BASEDIR/navigationTitleImageLocation 2>&1

optipng $BASEDIR/Images.xcassets/NavBarImage.imageset/navBar.png 2>&1

sips --resampleHeight 90 -s format png --out $BASEDIR/Images.xcassets/NavBarImage.imageset/navBarDark.png $BASEDIR/navigationTitleImageLocationDark 2>&1

optipng $BASEDIR/Images.xcassets/NavBarImage.imageset/navBarDark.png 2>&1
