//
//  LEANToolbarManager.m
//  GoNativeIOS
//
//  Created by Weiyin He on 5/20/15.
//  Copyright (c) 2015 GoNative.io LLC. All rights reserved.
//

#import "LEANToolbarManager.h"
#import "LEANWebViewController.h"
#import "GoNativeAppConfig.h"
#import "LEANUtilities.h"
#import "GonativeIO-Swift.h"

@interface LEANToolbarManager()
@property UIToolbar *toolbar;
@property NSArray *toolbarItems;
@property NSArray *toolbarItemTypes;
@property NSArray *toolbarItemUrlRegexes;
@property (weak, nonatomic) LEANWebViewController *wvc;
@property LEANToolbarVisibility visibility;
@end

@implementation LEANToolbarManager

- (instancetype)initWithToolbar:(UIToolbar*)toolbar webviewController:(LEANWebViewController*)wvc;
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
    self.visibility = [GoNativeAppConfig sharedAppConfig].toolbarVisibility;
    NSMutableArray *toolbarItems = [NSMutableArray array];
    NSMutableArray *toolbarItemTypes = [NSMutableArray array];
    NSMutableArray *toolbarItemUrlRegexes = [NSMutableArray array];
    // add spacer
    void (^addSpacer)(void) =
        ^{
            UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            spacer.enabled = NO;
            [toolbarItems addObject:spacer];
            [toolbarItemTypes addObject:@"spacer"];
            [toolbarItemUrlRegexes addObject:[NSNull null]];
        };
    if ([GoNativeAppConfig sharedAppConfig].toolbarItems) {
        for (NSDictionary *entry in [GoNativeAppConfig sharedAppConfig].toolbarItems) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            NSString *system = entry[@"system"];
            NSString *title = entry[@"title"];
            NSString *icon = entry[@"icon"];
            id urlRegex = entry[@"urlRegex"];
            
            
            UIImage *iconImage;
            if ([icon isEqualToString:@"left"]) {
                iconImage = [LEANIcons imageForIconIdentifier:@"fas fa-arrow-left" size:23];
            } else if([icon isEqualToString:@"right"]){
                iconImage = [LEANIcons imageForIconIdentifier:@"fas fa-arrow-right" size:23];
            } else if([icon isEqualToString:@"refresh"]){
                iconImage = [LEANIcons imageForIconIdentifier:@"fas fa-redo-alt" size:23];
            }
            
            // process items
            UIBarButtonItem *item = nil;
            NSString *itemType = nil;
            NSArray *itemRegexes = [LEANUtilities createRegexArrayFromStrings:urlRegex];
            if ([system isKindOfClass:[NSString class]] && ([system isEqualToString:@"back"] || [system isEqualToString:@"forward"] || [system isEqualToString:@"refresh"])) {
                if ([system isEqualToString:@"back"]) {
                    if(iconImage){
                        item = [[UIBarButtonItem alloc] initWithImage:iconImage style:UIBarButtonItemStylePlain target:self action:@selector(backPressed:)];
                    } else {
                        if (!title) title = @"Back";
                        item = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:@selector(backPressed:)];
                    }
                    itemType = @"back";
                } else if ([system isEqualToString:@"forward"]){
                    if(iconImage){
                        item = [[UIBarButtonItem alloc] initWithImage:iconImage style:UIBarButtonItemStylePlain target:self action:@selector(forwardPressed:)];
                    } else {
                        if (!title) title = @"Forward";
                        item = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:@selector(forwardPressed:)];
                    }
                    itemType = @"forward";
                } else if([system isEqualToString:@"refresh"]){
                    if(iconImage){
                        item = [[UIBarButtonItem alloc] initWithImage:iconImage style:UIBarButtonItemStylePlain target:self action:@selector(refreshPressed:)];
                    } else {
                        if (!title) title = @"Refresh";
                        item = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:@selector(refreshPressed:)];
                        
                    }
                    itemType = @"refresh";
                }
                
                item.enabled = NO;
            }
            
            if (item && itemType) {
                // add item
                if ([toolbarItems count] == 0) addSpacer();
                [toolbarItems addObject:item];
                [toolbarItemTypes addObject:itemType];
                [toolbarItemUrlRegexes addObject:itemRegexes];
                addSpacer();
            }
        }
    }
    
    self.toolbarItems = toolbarItems;
    self.toolbarItemTypes = toolbarItemTypes;
    self.toolbarItemUrlRegexes = toolbarItemUrlRegexes;
    [self.toolbar setItems:self.toolbarItems animated:YES];
}

- (void)didLoadUrl:(NSURL*)url
{
    NSString *urlString = [url absoluteString];
    // update toolbar buttons
    for (NSInteger i = 0; i < [self.toolbarItems count]; i++) {
        if ([self.toolbarItemTypes[i] isEqualToString:@"back"] || [self.toolbarItemTypes[i] isEqualToString:@"forward"] || [self.toolbarItemTypes[i] isEqualToString:@"refresh"]) {
            UIBarButtonItem *item = self.toolbarItems[i];
            if([self.toolbarItemTypes[i] isEqualToString:@"back"]){
                item.enabled = [self.wvc canGoBack];
            } else if([self.toolbarItemTypes[i] isEqualToString:@"forward"]){
                item.enabled = [self.wvc canGoForward];
            } else {
                item.enabled = YES;
            }
            
            // check regex array
            BOOL regexMatches = YES;
            NSArray *regexArray = self.toolbarItemUrlRegexes[i];
            if ([regexArray isKindOfClass:[NSArray class]] && [regexArray count] > 0) {
                regexMatches = NO;
                for (NSPredicate *predicate in regexArray) {
                    BOOL matches = NO;
                    @try {
                        matches = [predicate evaluateWithObject:urlString];
                    }
                    @catch (NSException* exception) {
                        NSLog(@"Error in toolbar regexes: %@", exception);
                    }

                    if (matches) {
                        regexMatches = YES;
                        break;
                    }
                }
            }
            if (!regexMatches) item.enabled = NO;
        }
    }
    
    // show/hide toolbar
    BOOL makeVisible = NO;
    if (self.visibility == LEANToolbarVisibilityAlways) {
        makeVisible = YES;
    } else if (self.visibility == LEANToolbarVisibilityAnyItemEnabled) {
        for (UIBarButtonItem *item in self.toolbarItems) {
            if (item.enabled) {
                makeVisible = YES;
                break;
            }
        }
    }
    
    if (makeVisible) {
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

@end
