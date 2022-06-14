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
@property NSURL *currentUrl;
@end

@implementation LEANToolbarManager

- (instancetype)initWithToolbar:(UIToolbar*)toolbar webviewController:(LEANWebViewController*)wvc
{
    self = [super init];
    if (self) {
        self.toolbar = toolbar;
        self.wvc = wvc;
        self.backButton = [[LEANToolbarItem alloc] init];
        self.forwardButton = [[LEANToolbarItem alloc] init];
        self.refreshButton = [[LEANToolbarItem alloc] init];
        [self processConfig];
    }
    return self;
}

- (void)processConfig
{
    NSMutableArray *toolbarItems = [NSMutableArray array];

    // loop through items from appConfig
    if ([GoNativeAppConfig sharedAppConfig].toolbarItems) {
        
        // fill the toolbar with spaces first
        UIBarButtonItem *flexibleSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        toolbarItems = [NSMutableArray arrayWithObjects:flexibleSpacer, flexibleSpacer, flexibleSpacer, flexibleSpacer, flexibleSpacer, nil];
        
        BOOL refreshButtonEnabled = NO;
        BOOL forwardButtonEnabled = NO;
        
        // loop through items to add to
        for (NSDictionary *entry in [GoNativeAppConfig sharedAppConfig].toolbarItems) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            
            NSString *system = entry[@"system"];
            NSString *visibility = entry[@"visibility"];
            BOOL enabled = NO;
            
            if ([entry[@"enabled"] isKindOfClass:[NSNumber class]])
                enabled = [entry[@"enabled"] boolValue];

            if ([system isEqualToString:@"back"]) {
                NSString *title = [self getLabelUsingEntry:entry defaultLabel:@"Back"];
                self.backButton.enabled = YES;
                self.backButton.regexes = [self getRegexesFromQuery:entry[@"urlRegex"]];
                self.backButton.visibility = visibility;
                self.backButton.item = [[UIBarButtonItem alloc] initWithCustomView:[self createButtonWithTitle:title forButton:@"Back" andIcon:@"fas fa-chevron-left" centerRefresh:NO]];
                self.backButton.item.enabled = NO;
                [toolbarItems replaceObjectAtIndex:0 withObject:self.backButton.item];
            }
            else if([system isEqualToString:@"refresh"]){
                if (!enabled) continue;
                // to be added later below
                refreshButtonEnabled = YES;
                
                self.refreshButton.enabled = enabled;
                self.refreshButton.regexes = [self getRegexesFromQuery:entry[@"urlRegex"]];
                self.refreshButton.visibility = visibility;
            }
            else if ([system isEqualToString:@"forward"]){
                if (!enabled) continue;
                forwardButtonEnabled = YES;
                
                NSString *title = [self getLabelUsingEntry:entry defaultLabel:@"Forward"];
                self.forwardButton.enabled = enabled;
                self.forwardButton.regexes = [self getRegexesFromQuery:entry[@"urlRegex"]];
                self.forwardButton.visibility = visibility;
                self.forwardButton.item = [[UIBarButtonItem alloc] initWithCustomView:[self createButtonWithTitle:title forButton:@"Forward" andIcon:@"fas fa-chevron-right" centerRefresh:NO]];
                self.forwardButton.item.enabled = NO;
                [toolbarItems replaceObjectAtIndex:4 withObject:self.forwardButton.item];
            }
        }
        
        // refresh button needs different positioning based on the presence of Forward button
        if(refreshButtonEnabled) {
            // center refresh button if forward button is not present
            self.refreshButton.item = [[UIBarButtonItem alloc] initWithCustomView:[self createButtonWithTitle:nil forButton:@"Refresh" andIcon:@"fas fa-redo-alt" centerRefresh:!forwardButtonEnabled]];
            [toolbarItems replaceObjectAtIndex:2 withObject:self.refreshButton.item];
        }
    }
    
    [self.toolbar setItems:toolbarItems animated:YES];
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

- (UIButton*)createButtonWithTitle:(NSString*)title forButton:(NSString*)buttonType andIcon:(NSString*)icon centerRefresh:(BOOL)centerRefreshBool{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    
    // title
    if(title) {
        [button setTitle:title forState:UIControlStateNormal];
        [[button titleLabel] setFont:[UIFont systemFontOfSize:18]];
        [button setTitleColor:[UIColor colorNamed:@"tintColor"] forState:UIControlStateNormal];
    }
    
    // image
    [button setImage:[LEANIcons imageForIconIdentifier:icon size:23 color:[UIColor colorNamed:@"tintColor"]] forState:UIControlStateNormal];
    
    // action
    if([buttonType isEqualToString:@"Back"]){
        [button addTarget:self action:@selector(backPressed:) forControlEvents:UIControlEventTouchUpInside];
    } else if([buttonType isEqualToString:@"Forward"]){
        [button setSemanticContentAttribute:UISemanticContentAttributeForceRightToLeft];
        [button addTarget:self action:@selector(forwardPressed:) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [button addTarget:self action:@selector(refreshPressed:) forControlEvents:UIControlEventTouchUpInside];
        // position refresh to 15 units left
        if(centerRefreshBool) button.imageEdgeInsets = UIEdgeInsetsMake(0, -15, 0, 0);
    }
    return button;
}

- (void)didLoadUrl:(NSURL*)url
{
    self.currentUrl = url;
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    if (!appConfig.toolbarEnabled) return;
    
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
    BOOL backEnabled = [self checkToolbarItem:self.backButton forUrl:urlString enabled:[self.wvc canGoBack]];
    
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

- (void)setToolbarEnabled:(BOOL)enabled {
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    [appConfig setToolbarEnabled:enabled];
    if (enabled && self.currentUrl)
        [self didLoadUrl:self.currentUrl];
    else
        [self.wvc hideToolbarAnimated:YES];
}

- (BOOL)checkToolbarItem:(LEANToolbarItem *)toolbarItem forUrl:(NSString *)urlString enabled:(BOOL)enabled {
    if (!enabled || !toolbarItem.enabled) {
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
    UIView *customView = [toolbarItem.item customView];
    toolbarItem.item.enabled = enabled;
    customView.alpha = enabled ? 1 : 0.3;
    [toolbarItem.item setCustomView:customView];
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



@end
