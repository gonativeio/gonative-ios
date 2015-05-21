//
//  LEANAppConfig.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANAppConfig.h"
#import "LEANUtilities.h"
#import <WebKit/WebKit.h>

@interface LEANAppConfig ()
@property id json;
@property NSUInteger numActiveMenus;
@property NSString *lastConfigUpdate;
@end

@implementation LEANAppConfig

+ (LEANAppConfig *)sharedAppConfig
{
    static LEANAppConfig *sharedAppConfig;
    
    @synchronized(self)
    {
        if (!sharedAppConfig){
            sharedAppConfig = [[LEANAppConfig alloc] init];
            
            [sharedAppConfig setupFromJsonFiles];
        }
        
        return sharedAppConfig;
    }
}

- (void)setupFromJsonFiles
{
    
    // read json
    NSURL *simulatorJson = [LEANAppConfig urlForSimulatorConfig];
    NSURL *otaJson = [LEANAppConfig urlForOtaConfig];
    NSURL *packageJson = [[NSBundle mainBundle] URLForResource:@"appConfig" withExtension:@"json"];
    
    for (NSURL *url in @[simulatorJson, otaJson, packageJson]) {
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir]) {
            continue;
        }
        
        NSError *jsonError;
        NSInputStream *inputStream = [NSInputStream inputStreamWithURL:url];
        [inputStream open];
        self.json = [NSJSONSerialization JSONObjectWithStream:inputStream options:0 error:&jsonError];
        [inputStream close];
        if (!jsonError) {
            // success!
            self.isSimulating = url == simulatorJson;
            break;
        } else {
            NSLog(@"Error parsing json: %@", jsonError);
        }
    }

    [self processConfig];
}

- (void)processConfig
{
    self.isSimulator = [[NSUserDefaults standardUserDefaults] boolForKey:@"isSimulator"];
    if (!self.isSimulator && [self.json[@"simulator"][@"isSimulator"] boolValue]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isSimulator"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        self.isSimulator = YES;
    }
    
    ////////////////////////////////////////////////////////////
    // General
    ////////////////////////////////////////////////////////////
    NSDictionary *general = self.json[@"general"];
    
    self.userAgentAdd = general[@"userAgentAdd"];
    self.forceUserAgent = general[@"forceUserAgent"];
    self.initialURL = [NSURL URLWithString:general[@"initialUrl"]];
    self.initialHost = [self.initialURL host];
    self.appName = general[@"appName"];
    self.publicKey = general[@"publicKey"];
    
    if (general[@"useWKWebView"]) {
        self.useWKWebView = [general[@"useWKWebView"] boolValue];
    } else {
        self.useWKWebView = YES;
    }
    
    // check for presence of WKWebView
    if (self.useWKWebView && !NSClassFromString(@"WKWebView")) {
        self.useWKWebView = NO;
    }
    
    if (self.useWKWebView) {
        NSLog(@"Using WKWebView");
    } else {
        NSLog(@"Using UIWebView");
    }
    
    self.deviceRegKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"deviceRegKey"];
    if (!self.deviceRegKey && [general[@"deviceRegKey"] isKindOfClass:[NSString class]]) {
        self.deviceRegKey = general[@"deviceRegKey"];
        [[NSUserDefaults standardUserDefaults] setObject:self.deviceRegKey forKey:@"deviceRegKey"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    if ([self.initialHost hasPrefix:@"www."]) {
        self.initialHost = [self.initialHost stringByReplacingCharactersInRange:NSMakeRange(0, [@"www." length]) withString:@""];
    }
    
    NSNumber *forceSessionCookieExpiry = general[@"forceSessionCookieExpiry"];
    if ([forceSessionCookieExpiry isKindOfClass:[NSNumber class]]) {
        self.forceSessionCookieExpiry = [forceSessionCookieExpiry unsignedIntegerValue];
    } else {
        self.forceSessionCookieExpiry = 0;
    }
    
    // process custom user agent by regex
    [self processUserAgentRegexes:general[@"userAgentRegexes"]];
    
    // html string replacements (requires UIWebView)
    // replaceStrings should be an array of JSON objects with fields "old" and "new"
    id replaceStrings = general[@"replaceStrings"];
    if ([replaceStrings isKindOfClass:[NSArray class]]) {
        self.replaceStrings = replaceStrings;
    }
    
    // modify user agent app-wide
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    NSString *newAgent;
    if ([self.forceUserAgent length] > 0) {
        newAgent = self.forceUserAgent;
    } else {
        NSString *originalAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
        NSString *userAgentAdd = [LEANAppConfig sharedAppConfig].userAgentAdd;
        if (!userAgentAdd) userAgentAdd = @"gonative";
        if ([userAgentAdd length] > 0) {
            newAgent = [NSString stringWithFormat:@"%@ %@", originalAgent, userAgentAdd];
        } else {
            newAgent = originalAgent;
        }
    }
    self.userAgent = newAgent;
    NSDictionary *dictionary = @{@"UserAgent": self.userAgent};
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    
    
    ////////////////////////////////////////////////////////////
    // Forms
    ////////////////////////////////////////////////////////////
    NSDictionary *forms = self.json[@"forms"];
    
    // search
    NSDictionary *search = forms[@"search"];
    if (search && [search[@"active"] boolValue]) {
        self.searchTemplateURL = search[@"searchTemplateURL"];
    } else {
        self.searchTemplateURL = nil;
    }
    
    // login
    NSDictionary *loginConfig = forms[@"loginConfig"];
    if (loginConfig && [loginConfig[@"active"] boolValue]) {
        self.loginConfig = loginConfig;
        self.loginURL = [NSURL URLWithString:loginConfig[@"interceptUrl"]];
        self.loginIsFirstPage = [loginConfig[@"loginIsFirstPage"] boolValue];
    } else {
        self.loginConfig = nil;
        self.loginURL = nil;
        self.loginIsFirstPage = NO;
    }
    
    self.loginLaunchBackground = [forms[@"loginLaunchBackground"] boolValue];
    if ([forms[@"loginIconImage"] isKindOfClass:[NSNumber class]]) {
        self.loginIconImage = [forms[@"loginIconImage"] boolValue];
    } else self.loginIconImage = YES;
    
    // signup
    NSDictionary *signupConfig = forms[@"signupConfig"];
    if (signupConfig && [signupConfig[@"active"] boolValue]) {
        self.signupConfig = signupConfig;
        self.signupURL = [NSURL URLWithString:signupConfig[@"interceptUrl"]];
    } else {
        self.signupConfig = nil;
        self.signupURL = nil;
    }
    
    // other forms to be intercepted
    NSDictionary *interceptForms = forms[@"interceptForms"];
    if (interceptForms && [interceptForms[@"active"] boolValue]) {
        self.interceptForms = interceptForms[@"forms"];
    } else {
        self.interceptForms = nil;
    }
    
    
    ////////////////////////////////////////////////////////////
    // Navigation
    ////////////////////////////////////////////////////////////
    NSDictionary *navigation = self.json[@"navigation"];
    NSDictionary *sidebarNav = navigation[@"sidebarNavigation"];
    
    [self processSidebarNav:sidebarNav];
    
    [self processNavigationLevels:navigation[@"navigationLevels"]];
    
    [self processNavigationTitles:navigation[@"navigationTitles"]];
    
    
    if ([navigation[@"redirects"] isKindOfClass:[NSArray class]]) {
        NSUInteger len = [navigation[@"redirects"] count];
        self.redirects = [[NSMutableDictionary alloc] initWithCapacity:len];
        for (id redirect in navigation[@"redirects"]) {
            [self.redirects setValue:redirect[@"to"] forKey:redirect[@"from"]];
        }
    } else {
        self.redirects = nil;
    }
    
    if ([navigation[@"profilePickerJS"] isKindOfClass:[NSString class]]) {
        self.profilePickerJS = navigation[@"profilePickerJS"];
    } else {
        self.profilePickerJS = nil;
    }
    
    // regex for internal vs external links
    // note that we ignore "active" here.
    if (navigation[@"regexInternalExternal"]) {
        id temp = navigation[@"regexInternalExternal"][@"rules"];
        
        NSUInteger num = [temp count];
        self.regexInternalEternal = [[NSMutableArray alloc] initWithCapacity:num];
        self.regexIsInternal = [[NSMutableArray alloc] initWithCapacity:num];
        for (id entry in temp) {
            if ([entry isKindOfClass:[NSDictionary class]] && entry[@"regex"] && entry[@"internal"]) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                NSNumber *internal = entry[@"internal"];
                if (predicate) {
                    [self.regexInternalEternal addObject:predicate];
                    [self.regexIsInternal addObject:internal];
                }
            }
            
        }
    } else {
        self.regexInternalEternal = nil;
    }
    
    // tab menus
    id tabNavigation = navigation[@"tabNavigation"];
    [self processTabNavigation:tabNavigation];
    
    // custom actions
    id actionConfig = navigation[@"actionConfig"];
    [self processActions:actionConfig];
    
    // toolbar
    self.toolbarVisibility = LEANToolbarVisibilityAnyItemEnabled;
    id toolbarNav = navigation[@"toolbarNavigation"];
    if ([toolbarNav isKindOfClass:[NSDictionary class]]) {
        NSString *toolbarVisibility = toolbarNav[@"visibility"];
        if ([toolbarVisibility isKindOfClass:[NSString class]]) {
            if ([toolbarVisibility isEqualToString:@"always"]) {
                self.toolbarVisibility = LEANToolbarVisibilityAlways;
            }
        }
        
        NSArray *items = toolbarNav[@"items"];
        if ([items isKindOfClass:[NSArray class]]) {
            self.toolbarItems = items;
        }
    }
    
    // refresh button
    if ([navigation[@"iosShowRefreshButton"] isKindOfClass:[NSNumber class]]) {
        self.showRefreshButton = [navigation[@"iosShowRefreshButton"] boolValue];
    } else self.showRefreshButton = NO;
    
    ////////////////////////////////////////////////////////////
    // Styling
    ////////////////////////////////////////////////////////////
    NSDictionary *styling = self.json[@"styling"];
    
    if ([styling[@"customCSS"] isKindOfClass:[NSString class]]) {
        self.customCss = styling[@"customCSS"];
    } else {
        self.customCss = nil;
    }
    
    if ([styling[@"forceViewportWidth"] isKindOfClass:[NSNumber class]]) {
        self.forceViewportWidth = styling[@"forceViewportWidth"];
    } else {
        self.forceViewportWidth = nil;
    }
    
    if ([styling[@"iosTheme"] isKindOfClass:[NSString class]] &&
        [styling[@"iosTheme"] isEqualToString:@"dark"]) {
        self.iosTheme = @"dark";
    } else {
        self.iosTheme = @"light";
    }
    
    if ([styling[@"showNavigationBar"] isKindOfClass:[NSNumber class]])
        self.showNavigationBar = [styling[@"showNavigationBar"] boolValue];
    else self.showNavigationBar = YES;
    self.tintColor = [LEANUtilities colorFromHexString:styling[@"iosTintColor"]];
    self.titleTextColor = [LEANUtilities colorFromHexString:styling[@"iosTitleColor"]];
    
    [self processNavigationTitleImage:styling[@"navigationTitleImage"]];
    
    if ([styling[@"menuAnimationDuration"] isKindOfClass:[NSNumber class]]) {
        self.menuAnimationDuration = styling[@"menuAnimationDuration"];
    } else {
        self.menuAnimationDuration = @0.15;
    }
    
    if ([styling[@"transitionInteractiveDelayMax"] isKindOfClass:[NSNumber class]]) {
        self.interactiveDelay = styling[@"transitionInteractiveDelayMax"];
    } else {
        self.interactiveDelay = @0.2;
    }
    
    if ([styling[@"showToolbar"] isKindOfClass:[NSNumber class]])
        self.showToolbar = [styling[@"showToolbar"] boolValue];
    else self.showToolbar = NO;
    
    // fonts
    id sidebarFont = styling[@"iosSidebarFont"];
    if ([sidebarFont isKindOfClass:[NSString class]]) {
        self.iosSidebarFont = [UIFont fontWithName:sidebarFont size:[UIFont systemFontSize]];
    } else if ([sidebarFont isKindOfClass:[NSDictionary class]] &&
               [sidebarFont[@"name"] isKindOfClass:[NSString class]]) {
        NSString *fontName = sidebarFont[@"name"];
        NSNumber *fontSize = sidebarFont[@"size"];
        if (![fontSize isKindOfClass:[NSNumber class]]) {
            fontSize = [NSNumber numberWithFloat:[UIFont systemFontSize]];
        }
        self.iosSidebarFont = [UIFont fontWithName:fontName size:[fontSize floatValue]];
    } else {
        self.iosSidebarFont = nil;
    }
    
    self.iosSidebarTextColor = [LEANUtilities colorFromHexString:styling[@"iosSidebarTextColor"]];
    
    ////////////////////////////////////////////////////////////
    // Services
    ////////////////////////////////////////////////////////////
    NSDictionary *services = self.json[@"services"];
    
    NSDictionary *push = services[@"push"];
    self.pushNotifications = [push[@"active"] boolValue];
    
    NSDictionary *analytics = services[@"analytics"];
    self.analytics = [analytics[@"active"] boolValue];
    if (self.analytics) {

        id idsite_test = analytics[@"idsite_test"];
        id idsite_prod = analytics[@"idsite_prod"];
        
        // simulator should always use test site
        if (self.isSimulator) {
            idsite_prod = idsite_test;
        }

        if ([idsite_test isKindOfClass:[NSNumber class]] &&
            [idsite_prod isKindOfClass:[NSNumber class]]) {
            self.idsite_test = [idsite_test integerValue];
            self.idsite_prod = [idsite_prod integerValue];
        } else {
            NSLog(@"Analytics requires idsite_test and idsite_prod");
            self.analytics = NO;
        }
        
    } else {
        self.analytics = NO;
    }
    
    ////////////////////////////////////////////////////////////
    // Performance
    ////////////////////////////////////////////////////////////
    NSDictionary *performance = self.json[@"performance"];
    
    // webview pool urls
    [self processWebViewPools:performance[@"webviewPools"]];
    
    ////////////////////////////////////////////////////////////
    // Miscellaneous stuff
    ////////////////////////////////////////////////////////////
    self.showShareButton = [self.json[@"showShareButton"] boolValue];
    self.enableChromecast = [self.json[@"enableChromecast"] boolValue];
    
    if (self.json[@"forceLandscapeRegex"]) {
        self.forceLandscapeMatch = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", self.json[@"forceLandscapeRegex"]];
    } else {
        self.forceLandscapeMatch = nil;
    }
    
    if (self.json[@"allowZoom"]) {
        self.allowZoom = [self.json[@"allowZoom"] boolValue];
    }
    else
        self.allowZoom = YES;
    
    self.updateConfigJS = self.json[@"updateConfigJS"];
    
    if (self.isSimulating) {
        self.appIcon = [UIImage imageWithData:[NSData dataWithContentsOfURL:[LEANAppConfig urlForSimulatorIcon]]];
        self.sidebarIcon = [UIImage imageWithData:[NSData dataWithContentsOfURL:[LEANAppConfig urlForSimulatorSidebarIcon]]];
        self.navigationTitleIcon = [UIImage imageWithData:[NSData dataWithContentsOfURL:[LEANAppConfig urlForSimulatorNavTitleIcon]]];
    } else {
        self.appIcon = nil;
        self.sidebarIcon = nil;
        self.navigationTitleIcon = nil;
    }
}

+ (NSURL*)urlForOtaConfig
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationSupport = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *url = [applicationSupport URLByAppendingPathComponent:@"appConfig.json"];
    // exclude from backup
    [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    return url;
}

+ (NSURL*)urlForSimulatorFile:(NSString*)name
{
    if (!name) {
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationSupport = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];

    NSURL *directory = [applicationSupport URLByAppendingPathComponent:@"simulatorFiles" isDirectory:YES];
    [directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    [fileManager createDirectoryAtURL:directory withIntermediateDirectories:NO attributes:nil error:nil];
    
    NSURL *url = [directory URLByAppendingPathComponent:name];
    // exclude from backup
    [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    return url;
}

+ (NSURL*)urlForSimulatorConfig
{
    return [LEANAppConfig urlForSimulatorFile:@"appConfig.json"];
}

+ (NSURL*)urlForSimulatorIcon
{
    return [LEANAppConfig urlForSimulatorFile:@"appIcon.image"];
}

+ (NSURL*)urlForSimulatorSidebarIcon
{
    return [LEANAppConfig urlForSimulatorFile:@"sidebarIcon.image"];
}

+ (NSURL*)urlForSimulatorNavTitleIcon
{
    return [LEANAppConfig urlForSimulatorFile:@"navigationTitleIcon.image"];
}

- (void)processDynamicUpdate:(NSString *)json
{
    if (!json || [json length] == 0 || [json isEqualToString:self.lastConfigUpdate]) {
        return;
    }
    
    self.lastConfigUpdate = json;
    
    NSError *error;
    id parsedJson = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error) {
        NSLog(@"Error processing config update: %@", error);
        return;
    }
    
    if (![parsedJson isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    [self processTabNavigation:parsedJson[@"tabNavigation"]];
    [self processSidebarNav:parsedJson[@"sidebarNavigation"]];
    [self processNavigationLevels:parsedJson[@"navigationLevels"]];
    [self processNavigationTitles:parsedJson[@"navigationTitles"]];
    [self processWebViewPools:parsedJson[@"webviewPools"]];
    [self processNavigationTitleImage:parsedJson[@"navigationTitleImage"]];
}

- (void)processSidebarNav:(NSDictionary*)sidebarNav
{
    if (![sidebarNav isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    self.showNavigationMenu = NO;
    self.numActiveMenus = 0;
    self.menus = nil;
    self.loginDetectionURL = nil;
    self.loginDetectRegexes = nil;
    self.loginDetectLocations = nil;
    self.userIdRegex = nil;
    
    // menus
    id menus = sidebarNav[@"menus"];
    if ([menus isKindOfClass:[NSArray class]]) {
        [self processMenus:menus];
    }
    
    if ([sidebarNav[@"userIdRegex"] isKindOfClass:[NSString class]]) {
        self.userIdRegex = sidebarNav[@"userIdRegex"];
    }
    
    // menu selection config
    id menuSelectionConfig = sidebarNav[@"menuSelectionConfig"];
    if ((self.numActiveMenus > 1 || self.loginIsFirstPage) && [menuSelectionConfig isKindOfClass:[NSDictionary class]]) {
        id testUrl = menuSelectionConfig[@"testURL"];
        if ([testUrl isKindOfClass:[NSString class]]) {
            self.loginDetectionURL = [NSURL URLWithString:testUrl];
        }
        
        id redirectLocations = menuSelectionConfig[@"redirectLocations"];
        if ([redirectLocations isKindOfClass:[NSArray class]]) {
            self.loginDetectRegexes = [NSMutableArray array];
            self.loginDetectLocations = [NSMutableArray array];
            for (id entry in redirectLocations) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                if (predicate) {
                    [self.loginDetectRegexes addObject:predicate];
                    [self.loginDetectLocations addObject:entry];
                }
            }
        }
    }

}

- (void)processMenus:(NSArray*)menus
{
    if (![menus isKindOfClass:[NSArray class]]) {
        return;
    }
    
    self.menus = [NSMutableDictionary dictionary];
    for (id menu in menus) {
        // skip if not active
        if (![menu[@"active"] boolValue]) {
            continue;
        }
        
        self.numActiveMenus++;
        
        NSString *name = menu[@"name"];
        if (name && [menu[@"items"] isKindOfClass:[NSArray class]]) {
            self.menus[name] = menu[@"items"];
            
            // show menu if the menu named "default" is active
            if ([name isEqualToString:@"default"]) {
                self.showNavigationMenu = YES;
            }
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANAppConfigNotificationProcessedMenu object:self];
}

- (void)processTabNavigation:(NSDictionary*)tabNavigation
{
    if (![tabNavigation isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    self.tabMenus = nil;
    self.tabMenuIDs = nil;
    self.tabMenuRegexes = nil;

    // tab menus
    id tabMenus = tabNavigation[@"tabMenus"];
    if ([tabMenus isKindOfClass:[NSArray class]]) {
        self.tabMenus = [NSMutableDictionary dictionary];
        for (id menu in tabMenus) {
            NSString *tabMenuId = menu[@"id"];
            if (tabMenuId && [menu[@"items"] isKindOfClass:[NSArray class]]) {
                self.tabMenus[tabMenuId] = menu[@"items"];
            }
        }
    }
    
    id tabSelection = tabNavigation[@"tabSelectionConfig"];
    if ([tabSelection isKindOfClass:[NSArray class]]) {
        self.tabMenuRegexes = [NSMutableArray array];
        self.tabMenuIDs = [NSMutableArray array];
        
        for (id entry in tabSelection) {
            if ([entry isKindOfClass:[NSDictionary class]] &&
                entry[@"regex"] && entry[@"id"]) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                NSString *menuId = entry[@"id"];
                
                [self.tabMenuRegexes addObject:predicate];
                [self.tabMenuIDs addObject:menuId];
            }
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANAppConfigNotificationProcessedTabNavigation object:self];
}

- (void)processActions:(NSDictionary*)actionConfig
{
    if (![actionConfig isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    self.actions = nil;
    self.actionIDs = nil;
    self.actionRegexes = nil;
    
    if (![actionConfig[@"active"] boolValue]) {
        return;
    }

    id actions = actionConfig[@"actions"];
    if ([actions isKindOfClass:[NSArray class]]) {
        self.actions = [NSMutableDictionary dictionary];
        for (id menu in actions) {
            NSString *identifier = menu[@"id"];
            if ([identifier isKindOfClass:[NSString class]] && [menu[@"items"] isKindOfClass:[NSArray class]]) {
                self.actions[identifier] = menu[@"items"];
            }
        }
    }
    
    id actionSelection = actionConfig[@"actionSelection"];
    if ([actionSelection isKindOfClass:[NSArray class]]) {
        self.actionRegexes = [NSMutableArray array];
        self.actionIDs = [NSMutableArray array];
        
        for (id entry in actionSelection) {
            if ([entry isKindOfClass:[NSDictionary class]] &&
                entry[@"regex"] && entry[@"id"]) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                NSString *identifier = entry[@"id"];
                
                [self.actionRegexes addObject:predicate];
                [self.actionIDs addObject:identifier];
            }
        }
    }
    
}

- (void)processNavigationLevels:(NSDictionary*)navigationLevels
{
    if (![navigationLevels isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    self.navStructureLevels = nil;
    
    // navigation levels
    if ([navigationLevels[@"active"] boolValue]) {
        id urlLevels = navigationLevels[@"levels"];
        self.navStructureLevels = [[NSMutableArray alloc] initWithCapacity:[urlLevels count]];
        for (id entry in urlLevels) {
            if ([entry isKindOfClass:[NSDictionary class]] && entry[@"regex"] && entry[@"level"]) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                NSNumber *level = entry[@"level"];
                [self.navStructureLevels addObject:@{@"predicate": predicate, @"level": level}];
            }
        }
    }
}

- (void)processNavigationTitles:(NSDictionary*)navigationTitles
{
    if (![navigationTitles isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    self.navTitles = nil;
    
    // navigation titles
    if ([navigationTitles[@"active"] boolValue]) {
        id titles = navigationTitles[@"titles"];
        self.navTitles = [[NSMutableArray alloc] initWithCapacity:[titles count]];
        for (id entry in titles) {
            if ([entry isKindOfClass:[NSDictionary class]] && entry[@"regex"]) {
                NSMutableDictionary *toAdd = [[NSMutableDictionary alloc] init];
                
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                [toAdd setObject:predicate forKey:@"predicate"];
                
                if (entry[@"title"]) {
                    [toAdd setObject:entry[@"title"] forKey:@"title"];
                }
                if (entry[@"urlRegex"]) {
                    [toAdd setObject:[NSRegularExpression regularExpressionWithPattern:entry[@"urlRegex"] options:0 error:nil] forKey:@"urlRegex"];
                }
                if (entry[@"urlChompWords"]) {
                    [toAdd setObject:entry[@"urlChompWords"] forKey:@"urlChompWords"];
                }
                
                [self.navTitles addObject:toAdd];
            }
        }
    }
}

- (void)processWebViewPools:(NSArray*)webviewPools
{
    if (![webviewPools isKindOfClass:[NSArray class]]) {
        return;
    }
    
    self.webviewPools = nil;

    self.webviewPools = webviewPools;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANAppConfigNotificationProcessedWebViewPools object:self];
}

- (void)processNavigationTitleImage:(id)navTitleImage
{
    if (!navTitleImage) return;
    
    self.navigationTitleImageRegexes = [NSMutableArray array];
    
    if ([navTitleImage isKindOfClass:[NSNumber class]]) {
        // create regex that matches everything
        NSPredicate *predicate;
        if ([navTitleImage boolValue]) {
            predicate = [NSPredicate predicateWithFormat:@"TRUEPREDICATE"];
        } else {
            predicate = [NSPredicate predicateWithFormat:@"FALSEPREDICATE"];
        }
        
        [self.navigationTitleImageRegexes addObject:predicate];
        return;
    }
    
    if ([navTitleImage isKindOfClass:[NSArray class]]) {
        for (id entry in navTitleImage) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry];
            if (predicate) {
                [self.navigationTitleImageRegexes addObject:predicate];
            }
        }
    }
}

- (BOOL)shouldShowNavigationTitleImageForUrl:(NSString*)url
{
    for (NSPredicate *predicate in self.navigationTitleImageRegexes) {
        if ([predicate evaluateWithObject:url]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)processUserAgentRegexes:(NSArray*)config
{
    if (![config isKindOfClass:[NSArray class]]) return;
    
    self.userAgentRegexes = [NSMutableArray array];
    self.userAgentStrings = [NSMutableArray array];
    
    for (NSDictionary *entry in config) {
        if ([entry isKindOfClass:[NSDictionary class]]) {
            NSString *regex = entry[@"regex"];
            NSString *userAgent = entry[@"userAgent"];
            if ([regex isKindOfClass:[NSString class]] && [userAgent isKindOfClass:[NSString class]]) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
                if (predicate) {
                    [self.userAgentRegexes addObject:predicate];
                    [self.userAgentStrings addObject:userAgent];
                }
            }
        }
    }
}

-(NSString*)userAgentForUrl:(NSURL*)url
{
    NSString *urlString = [url absoluteString];
    for (NSUInteger i = 0; i < [self.userAgentRegexes count]; i++) {
        if ([self.userAgentRegexes[i] evaluateWithObject:urlString]) {
            return self.userAgentStrings[i];
        }
    }

    return self.userAgent;
}

@end
