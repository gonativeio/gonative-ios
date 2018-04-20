#!/bin/sh

# Use Mac OSX's utility to create app icons of various sizes.

BASEDIR=$(dirname $0)

sips --resampleHeight 90 -s format png --out $BASEDIR/navbar_logo.png $BASEDIR/navigationTitleImageLocation 2>&1

optipng $BASEDIR/navbar_logo.png 2>&1
