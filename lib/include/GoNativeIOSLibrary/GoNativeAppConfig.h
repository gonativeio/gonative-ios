//
//  GoNativeAppConfig.h
//  GoNativeIOSLibrary
//
//  Created by Weiyin He on 1/7/16.
//  Copyright © 2016 Gonative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSString *kLEANAppConfigNotificationProcessedMenu = @"io.gonative.ios.LEANAppConfig.processedMenu";
static NSString *kLEANAppConfigNotificationProcessedTabNavigation = @"io.gonative.ios.LEANAppConfig.processedTabNavigation";
static NSString *kLEANAppConfigNotificationProcessedWebViewPools = @"io.gonative.ios.LEANAppConfig.processedWebViewPools";
static NSString *kLEANAppConfigNotificationProcessedSegmented = @"io.gonative.ios.LEANAppConfig.processedSegmented";
static NSString *kLEANAppConfigNotificationProcessedNavigationTitles = @"io.gonative.ios.LEANAppConfig.processedNavigationTitles";

typedef enum : NSUInteger {
    LEANToolbarVisibilityAlways,
    LEANToolbarVisibilityAnyItemEnabled
} LEANToolbarVisibility;

typedef enum : NSUInteger {
    GoNativeScreenOrientationUnspecified,
    GoNativeScreenOrientationPortrait,
    GoNativeScreenOrientationLandscape
} GoNativeScreenOrientation;

@interface GoNativeAppConfig : NSObject

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
@property BOOL disableConfigUpdater;
@property BOOL disableEventRecorder;
@property BOOL enableWindowOpen;
@property GoNativeScreenOrientation forceScreenOrientation;
@property BOOL keepScreenOn;

// navigation
@property NSMutableDictionary *menus;
@property NSURL *loginDetectionURL;
@property NSMutableArray *loginDetectRegexes;
@property NSMutableArray *loginDetectLocations;
@property BOOL showNavigationMenu;
@property NSMutableArray<NSPredicate*> *sidebarEnabledRegexes;
@property NSMutableArray<NSNumber*> *sidebarIsEnabled;
@property NSMutableArray *navStructureLevels;
@property NSMutableArray *navTitles;
@property NSMutableArray *regexInternalEternal;
@property NSMutableArray *regexIsInternal;
@property NSDictionary *redirects;
@property NSString *profilePickerJS;
@property NSString *userIdRegex;
@property BOOL useWebpageTitle;
@property NSArray *segmentedControlItems;

@property NSMutableDictionary *tabMenus;
@property NSMutableArray *tabMenuRegexes;
@property NSMutableArray *tabMenuIDs;

@property NSMutableDictionary *actions;
@property NSMutableArray *actionRegexes;
@property NSMutableArray *actionIDs;

@property LEANToolbarVisibility toolbarVisibility;
@property NSArray *toolbarItems;

@property BOOL pullToRefresh;

// styling
@property NSString *iosTheme;
@property NSString *customCss;
@property NSNumber *forceViewportWidth;
@property NSString *stringViewport;
@property UIColor *tintColor;
@property UIColor *titleTextColor;
@property BOOL showToolbar;
@property BOOL showNavigationBar;
@property BOOL showNavigationBarWithNavigationLevels;
@property NSMutableArray *navigationTitleImageRegexes;
@property NSNumber *menuAnimationDuration;
@property NSNumber *interactiveDelay;
@property UIFont *iosSidebarFont;
@property UIColor *iosSidebarTextColor;
@property BOOL showRefreshButton;
@property NSNumber *hideWebviewAlpha;
@property BOOL disableAnimations;


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

// parse integration
@property BOOL parseEnabled;
@property NSString *parseApplicationId;
@property NSString *parseClientKey;
@property BOOL parsePushEnabled;
@property BOOL parseAnalyticsEnabled;

// onesignal integration
@property BOOL oneSignalEnabled;
@property NSString *oneSignalAppId;

// Facebook SDK
@property BOOL facebookEnabled;
@property NSString *facebookAppId;
@property NSString *facebookDisplayName;

// identity service
@property NSArray *checkIdentityUrlRegexes;
@property NSURL *identityEndpointUrl;

// registration service
@property NSArray *registrationEndpoints;

// touch id
@property NSArray *authAllowedUrls;

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


+ (GoNativeAppConfig *)sharedAppConfig;
+ (NSURL*)urlForOtaConfig;
+ (NSURL*)urlForSimulatorConfig;
+ (NSURL*)urlForSimulatorIcon;
+ (NSURL*)urlForSimulatorSidebarIcon;
+ (NSURL*)urlForSimulatorNavTitleIcon;
- (void)setupFromJsonFiles;
- (void)processDynamicUpdate:(NSString*)json;

- (BOOL)shouldShowNavigationTitleImageForUrl:(NSString*)url;
-(NSString*)userAgentForUrl:(NSURL*)url;
- (BOOL)shouldShowSidebarForUrl:(NSString*)url;

@end
