//
//  LEANAppConfig.h
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANAppConfig : NSObject

// general
@property NSURL *initialURL;
@property NSString *initialHost;
@property NSString *appName;
@property NSString *publicKey;
@property NSString *userAgentAdd;

// navigation
@property NSMutableDictionary *menus;
@property NSURL *loginDetectionURL;
@property NSMutableArray *loginDetectRegexes;
@property NSMutableArray *loginDetectLocations;
@property BOOL showNavigationMenu;
@property NSMutableArray *navStructureLevels;
@property NSMutableArray *navTitles;
@property NSMutableArray *regexInternalEternal;
@property NSMutableArray *regexIsInternal;
@property NSDictionary *redirects;
@property NSString *profilePickerJS;
@property NSString *userIdRegex;
@property BOOL useWebpageTitle;

// styling
@property NSString *customCss;
@property NSNumber *forceViewportWidth;
@property NSString *stringViewport;
@property UIColor *tintColor;
@property UIColor *titleTextColor;
@property BOOL showToolbar;
@property BOOL showNavigationBar;
@property NSNumber *menuAnimationDuration;
@property NSNumber *interactiveDelay;


// forms
@property NSString *searchTemplateURL;
@property NSDictionary *loginConfig;
@property NSURL *loginURL;
@property BOOL loginIsFirstPage;
@property BOOL loginLaunchBackground;
@property BOOL loginIconImage;
@property NSURL *signupURL;
@property NSDictionary *signupConfig;
@property NSArray *interceptForms;


// services
@property BOOL pushNotifications;

// misc
@property NSPredicate *forceLandscapeMatch;
@property BOOL showShareButton;
@property BOOL enableChromecast;
@property BOOL allowZoom;


+ (LEANAppConfig *)sharedAppConfig;
+ (NSURL*)urlForOtaConfig;

@end
