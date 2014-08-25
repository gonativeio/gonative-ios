//
//  LEANAppConfig.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANAppConfig.h"
#import "LEANUtilities.h"
#import <CommonCrypto/CommonCrypto.h>

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
        if (![[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:NO]) {
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
    self.deviceRegKey = general[@"deviceRegKey"];
    
    if ([self.initialHost hasPrefix:@"www."]) {
        self.initialHost = [self.initialHost stringByReplacingCharactersInRange:NSMakeRange(0, [@"www." length]) withString:@""];
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
    
    self.navigationTitleImage = [styling[@"navigationTitleImage"] boolValue];
    
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
    } else {
        self.appIcon = nil;
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

+ (NSURL*)urlForSimulatorConfig
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationSupport = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *url = [applicationSupport URLByAppendingPathComponent:@"simulatorAppConfig.json"];
    // exclude from backup
    [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    return url;
}

+ (NSURL*)urlForSimulatorIcon
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationSupport = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *url = [applicationSupport URLByAppendingPathComponent:@"simulatorAppIcon.image"];
    // exclude from backup
    [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    return url;
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
}

- (void)processSidebarNav:(NSDictionary*)sidebarNav
{
    self.numActiveMenus = 0;
    self.menus = nil;
    self.loginDetectionURL = nil;
    self.loginDetectRegexes = nil;
    self.loginDetectLocations = nil;
    self.userIdRegex = nil;
    
    if (![sidebarNav isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
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
    self.tabMenus = nil;
    self.tabMenuIDs = nil;
    self.tabMenuRegexes = nil;
    
    if (![tabNavigation isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
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
    if (tabSelection && [tabSelection isKindOfClass:[NSArray class]]) {
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

- (void)processNavigationLevels:(NSDictionary*)navigationLevels
{
    self.navStructureLevels = nil;
    
    if (![navigationLevels isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
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
    self.navTitles = nil;
    
    if (![navigationTitles isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
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
    self.webviewPools = nil;
    if (![webviewPools isKindOfClass:[NSArray class]]) {
        return;
    }
    
    self.webviewPools = webviewPools;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANAppConfigNotificationProcessedWebViewPools object:self];
}

@end
