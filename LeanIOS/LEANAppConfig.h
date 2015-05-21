//
//  LEANAppConfig.h
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *kLEANAppConfigNotificationProcessedMenu = @"io.gonative.ios.LEANAppConfig.processedMenu";
static NSString *kLEANAppConfigNotificationProcessedTabNavigation = @"io.gonative.ios.LEANAppConfig.processedTabNavigation";
static NSString *kLEANAppConfigNotificationProcessedWebViewPools = @"io.gonative.ios.LEANAppConfig.processedWebViewPools";

typedef enum : NSUInteger {
    LEANToolbarVisibilityAlways,
    LEANToolbarVisibilityAnyItemEnabled
} LEANToolbarVisibility;

@interface LEANAppConfig : NSObject

// general
@property NSURL *initialURL;
@property NSString *initialHost;
@property NSString *appName;
@property NSString *publicKey;
@property NSString *deviceRegKey;
@property NSString *userAgentAdd;
@property NSString *forceUserAgent;
@property NSString *userAgent;
@property NSMutableArray *userAgentRegexes;
@property NSMutableArray *userAgentStrings;
@property BOOL useWKWebView;
@property NSUInteger forceSessionCookieExpiry;
@property NSArray *replaceStrings;

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

@property NSMutableDictionary *tabMenus;
@property NSMutableArray *tabMenuRegexes;
@property NSMutableArray *tabMenuIDs;

@property NSMutableDictionary *actions;
@property NSMutableArray *actionRegexes;
@property NSMutableArray *actionIDs;

@property LEANToolbarVisibility toolbarVisibility;
@property NSArray *toolbarItems;

// styling
@property NSString *iosTheme;
@property NSString *customCss;
@property NSNumber *forceViewportWidth;
@property NSString *stringViewport;
@property UIColor *tintColor;
@property UIColor *titleTextColor;
@property BOOL showToolbar;
@property BOOL showNavigationBar;
@property NSMutableArray *navigationTitleImageRegexes;
@property NSNumber *menuAnimationDuration;
@property NSNumber *interactiveDelay;
@property UIFont *iosSidebarFont;
@property UIColor *iosSidebarTextColor;
@property BOOL showRefreshButton;


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
@property BOOL analytics;
@property NSInteger idsite_test;
@property NSInteger idsite_prod;

// misc
@property NSPredicate *forceLandscapeMatch;
@property BOOL showShareButton;
@property BOOL enableChromecast;
@property BOOL allowZoom;
@property NSString *updateConfigJS;

// simulator
@property BOOL isSimulator;
@property BOOL isSimulating;
@property UIImage *appIcon;
@property UIImage *sidebarIcon;
@property UIImage *navigationTitleIcon;

@property NSArray *webviewPools;


+ (LEANAppConfig *)sharedAppConfig;
+ (NSURL*)urlForOtaConfig;
+ (NSURL*)urlForSimulatorConfig;
+ (NSURL*)urlForSimulatorIcon;
+ (NSURL*)urlForSimulatorSidebarIcon;
+ (NSURL*)urlForSimulatorNavTitleIcon;
- (void)setupFromJsonFiles;
- (void)processDynamicUpdate:(NSString*)json;

- (BOOL)shouldShowNavigationTitleImageForUrl:(NSString*)url;
-(NSString*)userAgentForUrl:(NSURL*)url;

@end
