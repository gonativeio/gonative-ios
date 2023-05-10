//
//  LEANTabManager.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/14/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANTabManager.h"
#import "LEANUtilities.h"
#import "GonativeIO-Swift.h"

#define TAB_IMAGE_SIZE_REGULAR 34
#define TAB_IMAGE_SIZE_COMPACT 17

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
        self.javascriptTabs = NO;
        self.tabRegexCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)didLoadUrl:(NSURL *)url
{
    if (self.javascriptTabs) {
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
    
    NSArray *menu = [GoNativeAppConfig sharedAppConfig].tabMenus[menuID];
    
    if (menu) {
        self.currentMenuID = menuID;
        [self setTabBarItems:menu];
    }
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
        float titleOffSetBy = 0;
        if ([iconName isKindOfClass:[NSString class]]) {
            if (iconName && [iconName hasPrefix:@"gonative-"]) {
                iconImage = [UIImage imageNamed:iconName];
            } else {
                // the tint color is automatically applied to the button, so a black icon is enough
                if (self.wvc.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
                    iconImage = [LEANIcons imageForIconIdentifier:iconName size:TAB_IMAGE_SIZE_COMPACT color:[UIColor blackColor]];
                    titleOffSetBy = -15;
                } else {
                    iconImage = [LEANIcons imageForIconIdentifier:iconName size:TAB_IMAGE_SIZE_REGULAR color:[UIColor blackColor]];
                    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
                        titleOffSetBy = -7.5;
                    }
                }
            }
        }
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:label image:iconImage tag:i];
        [item setTitlePositionAdjustment:UIOffsetMake(0, titleOffSetBy)];
        [items addObject:item];
        
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

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    if (previousTraitCollection.verticalSizeClass == self.wvc.traitCollection.verticalSizeClass) return;
    if (!self.menu) return;
    
    // we need to resize icons if the vertical size class has changed
    for (NSUInteger i = 0; i < [self.menu count]; i++) {
        NSString *iconName = self.menu[i][@"icon"];
        UIImage *iconImage;
        if ([iconName isKindOfClass:[NSString class]]) {
            if (iconName && [iconName hasPrefix:@"gonative-"]) {
                // no change in image
                continue;
            } else {
                // the tint color is automatically applied to the button, so a black icon is enough
                if (self.wvc.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
                    iconImage = [LEANIcons imageForIconIdentifier:iconName size:TAB_IMAGE_SIZE_COMPACT color:[UIColor blackColor]];
                    [self.tabBar.items[i] setTitlePositionAdjustment:UIOffsetMake(0, -15)];
                } else {
                    iconImage = [LEANIcons imageForIconIdentifier:iconName size:TAB_IMAGE_SIZE_REGULAR color:[UIColor blackColor]];
                    [self.tabBar.items[i] setTitlePositionAdjustment:UIOffsetMake(0, 0)];
                }
                
                if (self.tabBar.items.count > i) {
                    self.tabBar.items[i].image = iconImage;
                }
            }
        }
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
                [self.wvc loadUrl:[LEANUtilities urlWithString:url] andJavascript:javascript];
            } else {
                [self.wvc loadUrlAfterFilter:[LEANUtilities urlWithString:url]];
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

- (void)setTabsWithJson:(NSDictionary*)json;
{
    NSNumber *showTabBar = json[@"enabled"];
    if (![showTabBar isKindOfClass:[NSNumber class]]) {
       return;
    }
    self.showTabBar = [showTabBar boolValue];

    if (self.showTabBar) {
       NSArray *menu = json[@"items"];
       if ([menu isKindOfClass:[NSArray class]]) {
           [self setTabBarItems:menu];
           [self.wvc showTabBarAnimated:YES];
           self.javascriptTabs = YES;
           self.currentMenuID = nil;
       } else {
           NSString *menuID = json[@"tabMenu"];
           if ([menuID isKindOfClass:[NSString class]] && menuID.length > 0) {
               [self loadTabBarMenu:menuID];
               self.javascriptTabs = NO;
           }
           [self.wvc showTabBarAnimated:YES];
       }
    } else {
       [self.wvc hideTabBarAnimated:YES];
       self.javascriptTabs = YES;
       self.currentMenuID = nil;
    }
}

- (void)handleUrl:(NSURL *)url query:(NSDictionary *)query {
    if ([url.path hasPrefix:@"/select/"]) {
        NSArray *components = url.pathComponents;
        if (components.count == 3) {
            NSInteger tabNumber = [components[2] integerValue];
            if (tabNumber >= 0) {
                [self selectTabNumber:tabNumber];
            }
        }
    }
    else if ([@"/deselect" isEqualToString:url.path]) {
        [self deselectTabs];
    }
    else if ([@"/setTabs" isEqualToString:url.path]) {
        id tabs = query[@"tabs"];
        
        if([tabs isKindOfClass:[NSString class]]) {
            tabs = [NSJSONSerialization JSONObjectWithData:[tabs dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        }
        
        if([tabs isKindOfClass:[NSDictionary class]]) {
            [self setTabsWithJson:tabs];
            self.javascriptTabs = YES;
        }
    }
}

@end
