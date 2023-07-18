//
//  LEANActionManager.m
//  GoNativeIOS
//
//  Created by Weiyin He on 11/25/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANActionManager.h"
#import "GonativeIO-Swift.h"

#define ICON_SIZE 28

@interface LEANActionManager ()
@property (weak, nonatomic) LEANWebViewController *wvc;
@property NSString *currentMenuID;
@property NSMutableArray *buttons;
@property NSMutableArray *urls;
@property(readwrite, assign) NSString *currentSearchTemplateUrl;
@end

@implementation LEANActionManager

- (instancetype)initWithWebviewController:(LEANWebViewController *)wvc
{
    self = [super init];
    if (self) {
        self.wvc = wvc;
    }
    return self;
}

- (void)didLoadUrl:(NSURL *)url
{
    if (!url) {
        return;
    }
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    NSString *urlString = [url absoluteString];
    
    for (NSUInteger i = 0; i < appConfig.actionSelection.count; i++) {
        ActionSelection *actionSelection = appConfig.actionSelection[i];
        @try {
            if ([actionSelection.regex evaluateWithObject:urlString]) {
                [self setMenuID:actionSelection.identifier];
                return;
            }
        }
        @catch (NSException* exception) {
            NSLog(@"Error in action regex: %@", exception);
        }
    }
    
    [self setMenuID:nil];
}

- (void)setMenuID:(NSString *)menuID
{
    if (![self.currentMenuID isEqualToString:menuID] && (self.currentMenuID != nil || menuID != nil)) {
        self.currentMenuID = menuID;
        [self createButtonItems];
    }
}

- (void)createButtonItems
{
    if (!self.currentMenuID) {
        self.items = nil;
        self.currentSearchTemplateUrl = nil;
        return;
    }
    
    self.items = [NSMutableArray array];
    self.buttons = [NSMutableArray array];
    self.urls = [NSMutableArray array];
    
    NSArray *menu = [GoNativeAppConfig sharedAppConfig].actions[self.currentMenuID];
    for (NSDictionary *entry in menu) {
        NSString *system = entry[@"system"];
        NSString *label = entry[@"label"];
        NSString *icon = entry[@"icon"];
        NSString *url = entry[@"url"];
        
        if ([system isKindOfClass:[NSString class]] && [system isEqualToString:@"share"]) {
            [self createButtonWithIcon:icon defaultIcon:@"md mi-ios-share" label:label action:@selector(sharePage:)];
            continue;
        }
        
        if ([system isKindOfClass:[NSString class]] && [system isEqualToString:@"refresh"]) {
            [self createButtonWithIcon:icon defaultIcon:@"fas fa-redo-alt" label:label action:@selector(refreshPressed:)];
            continue;
        }
        
        if ([system isKindOfClass:[NSString class]] && [system isEqualToString:@"search"]) {
            [self createButtonWithIcon:icon defaultIcon:@"fas fa-search" label:label action:@selector(searchPressed:)];
            self.currentSearchTemplateUrl = entry[@"url"];
            continue;
        }
        
        [self createButtonWithIcon:icon label:label url:url];
    }
}

- (void)createButtonWithIcon:(NSString *)icon defaultIcon:(NSString *)defaultIcon label:(NSString *)label action:(SEL)action {
    if (![icon isKindOfClass:[NSString class]] && icon.length == 0) {
        icon = defaultIcon;
    }
    
    UIColor *titleColor = [UIColor colorNamed:@"titleColor"];
    UIImage *iconImage = [LEANIcons imageForIconIdentifier:icon size:ICON_SIZE color:titleColor];
    UIImage *nonTintedImage = [iconImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:nonTintedImage forState:UIControlStateNormal];
    [button addTarget:self.wvc action:action forControlEvents:UIControlEventTouchUpInside];
    [button setFrame:CGRectMake(0, 0, 36, 30)];
    
    UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    [buttonItem setAccessibilityLabel:label];
    
    [self.items insertObject:buttonItem atIndex:0];
}

- (void)createButtonWithIcon:(NSString *)icon label:(NSString *)label url:(NSString *)url {
    UIColor *titleColor = [UIColor colorNamed:@"titleColor"];
    UIImage *iconImage = [LEANIcons imageForIconIdentifier:icon size:ICON_SIZE color:titleColor];
    UIImage *nonTintedImage = [iconImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:nonTintedImage forState:UIControlStateNormal];
    [button addTarget:self action:@selector(itemWasSelected:) forControlEvents:UIControlEventTouchUpInside];
    [button setFrame:CGRectMake(0, 0, 36, 30)];
    
    UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    [buttonItem setAccessibilityLabel:label];
    
    [self.items insertObject:buttonItem atIndex:0];
    [self.buttons insertObject:button atIndex:0];
    [self.urls insertObject:url ? url : @"" atIndex:0];
}

- (void)itemWasSelected:(id)sender {
    NSUInteger index = [self.buttons indexOfObject:sender];
    
    if (index != NSNotFound && index < self.urls.count) {
        [self.wvc loadUrlString:self.urls[index]];
    }
}


@end
