//
//  LEANToolbarManager.m
//  GoNativeIOS
//
//  Created by Weiyin He on 5/20/15.
//  Copyright (c) 2015 GoNative.io LLC. All rights reserved.
//

#import "LEANToolbarManager.h"
#import "LEANWebViewController.h"
#import "LEANUtilities.h"
#import "GonativeIO-Swift.h"

@interface LEANToolbarItem : NSObject
@property BOOL enabled;
@property NSArray<RegexEnabled *> *regexes;
@property NSString *visibility;
@property UIBarButtonItem *item;
@end

@implementation LEANToolbarItem
@end

@interface LEANToolbarManager()
@property (weak, nonatomic) LEANWebViewController *wvc;
@property UIToolbar *toolbar;
@property LEANToolbarItem *backButton;
@property LEANToolbarItem *refreshButton;
@property LEANToolbarItem *forwardButton;
@end

@implementation LEANToolbarManager

- (instancetype)initWithToolbar:(UIToolbar*)toolbar webviewController:(LEANWebViewController*)wvc
{
    self = [super init];
    if (self) {
        self.toolbar = toolbar;
        self.wvc = wvc;
        [self processConfig];
    }
    return self;
}

- (void)processConfig
{
    NSMutableArray *toolbarItems = [NSMutableArray array];
    
    // initialize buttons
    self.backButton = [[LEANToolbarItem alloc] init];
    self.forwardButton = [[LEANToolbarItem alloc] init];
    self.refreshButton = [[LEANToolbarItem alloc] init];
    
    self.backButton.item = [self createButtonWithTitle:@"Back" forButton:@"Back" andIcon:@"fas fa-chevron-left"];
    self.refreshButton.item = [self createButtonWithTitle:nil forButton:@"Refresh" andIcon:@"fas fa-redo-alt"];
    self.forwardButton.item = [self createButtonWithTitle:@"Forward" forButton:@"Forward" andIcon:@"fas fa-chevron-right"];
    self.backButton.enabled = NO;
    self.refreshButton.enabled = NO;
    self.forwardButton.enabled = NO;
    
    // loop through items from appConfig
    if ([GoNativeAppConfig sharedAppConfig].toolbarItems) {
        for (NSDictionary *entry in [GoNativeAppConfig sharedAppConfig].toolbarItems) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            
            NSString *system = entry[@"system"];
            NSString *visibility = entry[@"visibility"];
            BOOL enabled = NO;
            if ([entry[@"enabled"] isKindOfClass:[NSNumber class]]) {
                enabled = [entry[@"enabled"] boolValue];
            }

            if ([system isEqualToString:@"back"]) {
                NSString *title = [self getLabelUsingEntry:entry defaultLabel:@"Back"];
                self.backButton.item = [self createButtonWithTitle:title forButton:@"Back" andIcon:@"fas fa-chevron-left"];
                self.backButton.enabled = YES;
                self.backButton.regexes = [self getRegexesFromQuery:entry[@"urlRegex"]];
                self.backButton.visibility = visibility;
            }
            else if([system isEqualToString:@"refresh"]){
                self.refreshButton.enabled = enabled;
                self.refreshButton.regexes = [self getRegexesFromQuery:entry[@"urlRegex"]];
                self.refreshButton.visibility = visibility;
            }
            else if ([system isEqualToString:@"forward"]){
                NSString *title = [self getLabelUsingEntry:entry defaultLabel:@"Forward"];
                self.forwardButton.item = [self createButtonWithTitle:title forButton:@"Forward" andIcon:@"fas fa-chevron-right"];
                self.forwardButton.enabled = enabled;
                self.forwardButton.regexes = [self getRegexesFromQuery:entry[@"urlRegex"]];
                self.forwardButton.visibility = visibility;
            }
        }
    }
    
    // create toolbar
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    toolbarItems = [NSMutableArray arrayWithObjects:self.backButton.item, space, self.refreshButton.item, space, self.forwardButton.item, nil];
    
    [self.toolbar setItems:toolbarItems animated:YES];
}

- (UIBarButtonItem *)createButtonWithTitle:(NSString *)title forButton:(NSString *)buttonType andIcon:(NSString *)icon {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    
    // title
    if(title) {
        [button setTitle:title forState:UIControlStateNormal];
        [[button titleLabel] setFont:[UIFont systemFontOfSize:18]];
        [button setTitleColor:[UIColor colorNamed:@"tintColor"] forState:UIControlStateNormal];
    }
    
    // image
    [button setImage:[LEANIcons imageForIconIdentifier:icon size:24 color:[UIColor colorNamed:@"tintColor"]] forState:UIControlStateNormal];
    
    // action
    if ([buttonType isEqualToString:@"Back"]) {
        [button addTarget:self action:@selector(backPressed:) forControlEvents:UIControlEventTouchUpInside];
    } else if ([buttonType isEqualToString:@"Forward"]) {
        [button setSemanticContentAttribute:UISemanticContentAttributeForceRightToLeft];
        [button addTarget:self action:@selector(forwardPressed:) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [button addTarget:self action:@selector(refreshPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    button.alpha = 0;
    button.enabled = NO;
    button.frame = CGRectMake(0, 0, button.intrinsicContentSize.width + 2, 44);
    
    return [[UIBarButtonItem alloc] initWithCustomView:button];
}

- (void)backPressed:(id)sender
{
    [self.wvc goBack];
}

- (void)forwardPressed:(id)sender
{
    [self.wvc goForward];
}

- (void)refreshPressed:(id)sender
{
    [self.wvc refreshPage];
}

- (NSString *)getLabelUsingEntry:(NSDictionary *)entry defaultLabel:(NSString *)defaultLabel {
    NSString *titleType = entry[@"titleType"];
    if ([titleType isKindOfClass:[NSString class]]) {
        if ([titleType isEqualToString:@"noText"]) {
            return @"";
        }
        if ([titleType isEqualToString:@"customText"]) {
            NSString *title = entry[@"title"];
            if ([title isKindOfClass:[NSString class]]) {
                return title;
            }
            return @"";
        }
    }
    return defaultLabel;
}

- (NSArray *)getRegexesFromQuery:(NSArray *)query {
    NSMutableArray *regexes = [NSMutableArray array];
    if ([query isKindOfClass:[NSArray class]]) {
        for (NSDictionary *entry in query) {
            if ([entry[@"regex"] isKindOfClass:[NSString class]] &&
                [entry[@"enabled"] isKindOfClass:[NSNumber class]]) {
                
                RegexEnabled *item = [[RegexEnabled alloc] init];
                item.regex = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                item.enabled = [entry[@"enabled"] boolValue];
                [regexes addObject:item];
            }
        }
    }
    return regexes;
}

- (void)didLoadUrl:(NSURL*)url
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    if (!appConfig.toolbarEnabled) {
        BOOL toolbarVisible = [self tryToShowBackButton:url];
        if (toolbarVisible) {
            [self.wvc showToolbarAnimated:YES];
        } else {
            [self.wvc hideToolbarAnimated:YES];
        }
        return;
    }
    
    // 1. Check visibilityByPages
    // 2. Check if back button is active
    // 3. Check visibilityByBackButton
    // 4. Check if refresh button is active
    // 5. Check if forward button is active
    // 6. 1 && 3 && (2 || 4 || 5)
    
    NSString *urlString = [url absoluteString];
    
    BOOL visibilityByPages = YES;
    BOOL visibilityByBackButton = YES;
    
    // Check visibilityByPages
    // if specific pages only
    if (appConfig.toolbarVisibilityByPages == LEANToolbarVisibilityByPagesSpecific) {
        visibilityByPages = [self evaluateUrlString:urlString usingRegexes:appConfig.toolbarRegexes];
    }
    
    // Update back button
    BOOL backEnabled = [self tryToShowBackButton:url];
    if (!backEnabled) {
        backEnabled = [self checkToolbarItem:self.backButton forUrl:urlString enabled:[self.wvc canGoBack]];
    }
    
    // Check visibilityByBackButton
    // if back button active only
    if (appConfig.toolbarVisibilityByBackButton == LEANToolbarVisibilityByBackButtonActive) {
        visibilityByBackButton = backEnabled;
    }
    
    // Update forward button
    BOOL forwardEnabled = [self checkToolbarItem:self.forwardButton forUrl:urlString enabled:[self.wvc canGoForward]];
    
    // Update refresh button
    BOOL refreshEnabled = [self checkToolbarItem:self.refreshButton forUrl:urlString enabled:YES];
    
    BOOL toolbarVisible = visibilityByPages && visibilityByBackButton && (backEnabled || forwardEnabled || refreshEnabled);
    if (toolbarVisible) {
        [self.wvc showToolbarAnimated:YES];
    } else {
        [self.wvc hideToolbarAnimated:YES];
    }
}

- (BOOL)tryToShowBackButton:(NSURL *)url {
    if (![self.wvc canGoBack]) return NO;
    
    if ([self.urlMimeType isEqualToString:@"application/pdf"] || [self.urlMimeType hasPrefix:@"image/"]) {
        [self setToolbarItem:self.backButton enabled:YES];
        return YES;
    }
    
    return NO;
}

- (BOOL)checkToolbarItem:(LEANToolbarItem *)toolbarItem forUrl:(NSString *)urlString enabled:(BOOL)enabled {
    if (!toolbarItem.enabled) {
        return NO;
    }
    
    if (!enabled) {
        [self setToolbarItem:toolbarItem enabled:NO];
        return NO;
    }
    
    if (![toolbarItem.visibility isEqualToString:@"specificPages"]) {
        [self setToolbarItem:toolbarItem enabled:YES];
        return YES;
    }
        
    BOOL value = [self evaluateUrlString:urlString usingRegexes:toolbarItem.regexes];
    [self setToolbarItem:toolbarItem enabled:value];
    return value;
}

- (void)setToolbarItem:(LEANToolbarItem *)toolbarItem enabled:(BOOL)enabled {
    // design the button "disabled"
    toolbarItem.item.enabled = enabled;
    toolbarItem.item.customView.alpha = enabled ? 1 : 0.3;
}

- (BOOL)evaluateUrlString:(NSString *)urlString usingRegexes:(NSArray *)regexes {
    for (RegexEnabled *regexObject in regexes) {
        @try {
            BOOL matches = [regexObject.regex evaluateWithObject:urlString];
            if (matches) return regexObject.enabled;
        }
        @catch (NSException* exception) {
            NSLog(@"Error in toolbar regexes: %@", exception);
        }
    }
    return NO;
}

- (void)updateToolbarButtons {
    BOOL backEnabled = NO;
    if (self.backButton.enabled) {
        [self setToolbarItem:self.backButton enabled:[self.wvc canGoBack]];
        backEnabled = [self.wvc canGoBack];
    }
    
    BOOL forwardEnabled = NO;
    if (self.forwardButton.enabled) {
        [self setToolbarItem:self.forwardButton enabled:[self.wvc canGoForward]];
        forwardEnabled = [self.wvc canGoForward];
    }
    
    BOOL refreshEnabled = self.refreshButton.enabled;
    if (self.refreshButton.enabled) {
        [self setToolbarItem:self.refreshButton enabled:YES];
    }
    
    if (backEnabled || forwardEnabled || refreshEnabled) {
        [self.wvc showToolbarAnimated:YES];
    } else {
        [self.wvc hideToolbarAnimated:YES];
    }
}

- (void)setToolbarEnabled:(BOOL)enabled {
    if (!enabled) {
        [self.wvc hideToolbarAnimated:YES];
    } else {
        [self updateToolbarButtons];
    }
}

- (void)handleUrl:(NSURL *)url query:(NSDictionary *)query {
    if ([url.path isEqualToString:@"/contextualNavToolbar/set"]) {
        [self setToolbarEnabled:[query[@"enabled"] boolValue]];
    }
    return;
}

@end
