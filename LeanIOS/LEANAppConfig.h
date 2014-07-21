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
@property BOOL pushNotifications;
@property BOOL loginLaunchBackground;
@property BOOL loginIconImage;
@property NSDictionary *redirects;
@property NSMutableArray *navStructureLevels;
@property NSMutableArray *navTitles;
@property NSNumber *interactiveDelay;
@property NSArray *interceptForms;
@property NSMutableArray *regexInternalEternal;
@property NSMutableArray *regexIsInternal;
@property NSMutableDictionary *menus;
@property NSMutableArray *loginDetectRegexes;
@property NSMutableArray *loginDetectLocations;

+ (LEANAppConfig *)sharedAppConfig;

- (BOOL)hasKey:(NSString *)key;
- (id)objectForKey:(id)aKey;
- (id)objectForKeyedSubscript:(id)key;

@end
