//
//  LEANAppConfig.h
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANAppConfig : NSObject

@property NSDictionary *dict;
@property NSURL *initialURL;
@property NSString *initialHost;
@property NSURL *loginDetectionURL;
@property NSURL *loginDetectionURLnotloggedin;
@property NSURL *loginURL;
@property NSURL *loginURLfail;
@property NSURL *forgotPasswordURL;
@property NSURL *forgotPasswordURLfail;
@property NSURL *signupURL;
@property NSURL *signupURLfail;
@property NSPredicate *forceLandscapeMatch;
@property UIColor *tintColor;
@property UIColor *titleTextColor;
@property BOOL showShareButton;
@property BOOL loginIsFirstPage;
@property BOOL enableChromecast;
@property BOOL allowZoom;
@property BOOL showToolbar;
@property BOOL showNavigationBar;
@property NSDictionary *redirects;

+ (LEANAppConfig *)sharedAppConfig;

- (BOOL)hasKey:(NSString *)key;
- (id)objectForKey:(id)aKey;
- (id)objectForKeyedSubscript:(id)key;

@end
