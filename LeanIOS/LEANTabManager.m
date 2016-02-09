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
            if ([self.tabBar.items count] > 0) {
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
    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:[menu count]];
    
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
    }
    
    self.menu = menu;
    [self.tabBar setItems:items animated:NO];
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
            if ([regex evaluateWithObject:urlString]) {
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
                [self.wvc loadUrl:[NSURL URLWithString:url] andJavascript:javascript];
            } else {
                [self.wvc loadUrl:[NSURL URLWithString:url]];
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

@end
