//
//  LEANIcons.m
//  GoNativeIOS
//
//  Created by Weiyin He on 9/19/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANIcons.h"
#import "FAImageView.h"

@implementation LEANIcons
+ (LEANIcons *)sharedIcons
{
    static LEANIcons *sharedIcons;
    
    @synchronized(self)
    {
        if (!sharedIcons){
            sharedIcons = [[LEANIcons alloc] init];
        }
        return sharedIcons;
    }
}

- (instancetype)init
{
    if (self = [super init]) {
        
    }
    return self;
}

+ (UIImage*)imageForIconIdentifier:(NSString*)string size:(CGFloat)size
{
    return [[LEANIcons sharedIcons] imageForIconName:string size:size];
}

- (UIImage*)imageForIconName:(NSString*)name size:(CGFloat)size
{
    if (!name || size <= 0) {
        return nil;
    }
    
    NSString *fontAwesomeString = [NSString fontAwesomeIconStringForIconIdentifier:name];
    if (!fontAwesomeString) {
        return nil;
    }

    FAImageView *imageView = [[FAImageView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    imageView.image = nil;
    [imageView setDefaultIconIdentifier:name];
    imageView.defaultView.backgroundColor = [UIColor clearColor];

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [imageView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
