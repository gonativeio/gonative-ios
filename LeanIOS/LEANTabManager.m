//
//  LEANTabManager.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/14/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANTabManager.h"
#import "LEANWebViewController.h"
#import "GoNativeAppConfig.h"
#import "LEANIcons.h"
#import "LEANUtilities.h"

@interface LEANTabManager() <UITabBarDelegate>
@property UITabBar *tabBar;
@property NSArray *menu;
@property (weak, nonatomic) LEANWebViewController* wvc;
@property NSString *currentMenuID;
@property BOOL showTabBar;
@property NSMutableDictionary<NSObject*, NSArray<NSPredicate*>*> *tabRegexCache;
@property BOOL useJavascript; // disables auto-loading of tabs from config
@end

@implementation LEANTabManager

- (instancetype)initWithTabBar:(UITabBar*)tabBar webviewController:(LEANWebViewController*)wvc;
{
    self = [super init];
    if (self) {
        self.tabBar = tabBar;
        self.tabBar.delegate = self;
        self.wvc = wvc;
        self.showTabBar = NO;
        self.tabRegexCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)didLoadUrl:(NSURL *)url
{
    if (self.useJavascript) {
        [self autoSelectTabForUrl:url];
        return;
    }
    
    NSArray *tabMenuRegexes = [GoNativeAppConfig sharedAppConfig].tabMenuRegexes;
    if (!tabMenuRegexes || !url) return;
    
    NSString *urlString = [url absoluteString];
    
    BOOL showTabBar = NO;
    for (NSUInteger i = 0; i < [tabMenuRegexes count]; i++) {
        NSPredicate *predicate = tabMenuRegexes[i];
        if ([predicate evaluateWithObject:urlString]) {
            [self loadTabBarMenu:[GoNativeAppConfig sharedAppConfig].tabMenuIDs[i]];
            showTabBar = YES;
            break;
        }
    }
    
    if (showTabBar) {
        if (!self.showTabBar) {
            // select first item
            if ([self.tabBar.items count] > 0 && !self.tabBar.selectedItem) {
                self.tabBar.selectedItem = self.tabBar.items[0];
            }
        }
        [self.wvc showTabBarAnimated:YES];
    } else {
        [self.wvc hideTabBarAnimated:YES];
    }
    
    self.showTabBar = showTabBar;
    
    [self autoSelectTabForUrl:url];
}

- (void)loadTabBarMenu:(NSString*)menuID
{
    if ([menuID isEqualToString:self.currentMenuID]) {
        return;
    }
    
    self.currentMenuID = menuID;
    
    NSArray *menu = [GoNativeAppConfig sharedAppConfig].tabMenus[menuID];
    [self setTabBarItems:menu];
}

- (void)setTabBarItems:(NSArray*) menu
{
    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:[menu count]];
    
    UITabBarItem *selectedItem;
    
    for (NSUInteger i = 0; i < [menu count]; i++) {
        NSString *label = menu[i][@"label"];
        NSString *iconName = menu[i][@"icon"];
        
        if (![label isKindOfClass:[NSString class]]) {
            label = @"";
        }
        
        UIImage *iconImage;
        if ([iconName isKindOfClass:[NSString class]]) {
            if (iconName && [iconName hasPrefix:@"gonative-"]) {
                iconImage = [UIImage imageNamed:iconName];
            } else {
                iconImage = [LEANIcons imageForIconIdentifier:iconName size:26];
            }
        }
        
        [items addObject:[[UITabBarItem alloc] initWithTitle:label image:iconImage tag:i]];
        
        if ([menu[i][@"selected"] boolValue]) {
            selectedItem = [items lastObject];
        }
    }
    
    self.menu = menu;
    [self.tabBar setItems:items animated:NO];
    if (selectedItem) {
        self.tabBar.selectedItem = selectedItem;
    }
}

- (NSArray<NSPredicate*>*) getRegexForTab:(NSDictionary*) tabConfig
{
    if (![tabConfig isKindOfClass:[NSDictionary class]]) return nil;
    
    id regex = tabConfig[@"regex"];
    if (!regex) return nil;
    
    return [LEANUtilities createRegexArrayFromStrings:regex];
}

- (NSArray<NSPredicate*>*) getCachedRegexForTab:(NSInteger) position
{
    if (!self.menu || position < 0 || position >= [self.menu count]) return nil;
    
    NSDictionary *tabConfig = self.menu[position];
    if (![tabConfig isKindOfClass:[NSDictionary class]]) return nil;
    
    NSArray<NSPredicate*>* cached = self.tabRegexCache[tabConfig];
    if ([cached isKindOfClass:[NSNumber class]]) return nil;
    else {
        NSArray<NSPredicate*>* regex = [self getRegexForTab:tabConfig];
        if (!regex) {
            self.tabRegexCache[tabConfig] = (NSArray<NSPredicate*>*)[NSNull null];
            return nil;
        } else {
            self.tabRegexCache[tabConfig] = regex;
            return regex;
        }
    }
}

- (void)autoSelectTabForUrl:(NSURL*)url
{
    if (!self.menu) return;
    
    NSString *urlString = [url absoluteString];
    
    for (NSInteger i = 0; i < [self.menu count]; i++) {
        NSArray<NSPredicate*> *regexList = [self getCachedRegexForTab:i];
        if (!regexList) continue;
        
        for (NSPredicate *regex in regexList) {
            BOOL matches = NO;
            @try {
                matches = [regex evaluateWithObject:urlString];
            }
            @catch (NSException* exception) {
                NSLog(@"Error in tab selection regex: %@", exception);
            }

            if (matches) {
                self.tabBar.selectedItem = self.tabBar.items[i];
                return;
            }
        }
    }
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    NSInteger idx = item.tag;
    if (idx < [self.menu count]) {
        NSString *url = self.menu[idx][@"url"];
        NSString *javascript = self.menu[idx][@"javascript"];
        
        if ([url length] > 0) {
            if ([url hasPrefix:@"javascript:"]) {
                NSString *js = [url substringFromIndex: [@"javascript:" length]];
                [self.wvc runJavascript:js];
            }
            else if ([javascript length] > 0) {
                [self.wvc loadUrl:[NSURL URLWithString:[url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]] andJavascript:javascript];
            } else {
                [self.wvc loadUrl:[NSURL URLWithString:[url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]]];
            }
        }
    }
}

- (void)selectTabWithUrl:(NSString*)url javascript:(NSString*)javascript
{
    for (NSUInteger i = 0; i < [self.menu count]; i++) {
        NSString *entryUrl = self.menu[i][@"url"];
        NSString *entryJs = self.menu[i][@"javascript"];
        
        if ([url isEqualToString:entryUrl] &&
            ((javascript == nil && entryJs == nil) || [javascript isEqualToString:entryJs])) {
            UITabBarItem *item = self.tabBar.items[i];
            if (item) {
                self.tabBar.selectedItem = item;
                return;
            }
        }
    }
}

- (void)selectTabNumber:(NSUInteger)number
{
    if (number >= self.tabBar.items.count) {
        NSLog(@"Invalid tab number %lu", (unsigned long)number);
        return;
    }
    
    self.tabBar.selectedItem = self.tabBar.items[number];
}

- (void)deselectTabs
{
    self.tabBar.selectedItem = nil;
}

- (void)setTabsWithJson:(NSString*)json
{
    NSError *jsonError;
    NSDictionary *tabConfig = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"Error parsing JSON: %@", jsonError);
        return;
    }
    if (![tabConfig isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Not JSON object");
        return;
    }

    self.useJavascript = YES;
    
    NSArray *menu = tabConfig[@"items"];
    if ([menu isKindOfClass:[NSArray class]]) {
        [self setTabBarItems:menu];
    }
    
    NSNumber *showTabBar = tabConfig[@"enabled"];
    if ([showTabBar isKindOfClass:[NSNumber class]]) {
        if ([showTabBar boolValue]) {
            [self.wvc showTabBarAnimated:YES];
        } else {
            [self.wvc hideTabBarAnimated:YES];
        }
        self.showTabBar = [showTabBar boolValue];
    }
}
@end
