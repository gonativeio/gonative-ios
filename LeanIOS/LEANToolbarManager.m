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
    
    if ([GoNativeAppConfig sharedAppConfig].toolbarItems) {
        for (NSDictionary *entry in [GoNativeAppConfig sharedAppConfig].toolbarItems) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            NSString *system = entry[@"system"];
            NSString *title = entry[@"title"];
            NSString *icon = entry[@"icon"];
            id urlRegex = entry[@"urlRegex"];
            
            
            UIImage *iconImage;
            if ([icon isEqualToString:@"left"]) {
                iconImage = [UIImage imageNamed:@"leftImage"];
            }
            
            // process items
            UIBarButtonItem *item = nil;
            NSString *itemType = nil;
            NSArray *itemRegexes = [LEANUtilities createRegexArrayFromStrings:urlRegex];
            if ([system isKindOfClass:[NSString class]] && [system isEqualToString:@"back"]) {
                if (iconImage) {
                    item = [[UIBarButtonItem alloc] initWithImage:iconImage style:UIBarButtonItemStylePlain target:self action:@selector(backPressed:)];
                } else {
                    if (!title) title = @"Back";
                    item = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:@selector(backPressed:)];
                }
                
                item.enabled = NO;
                itemType = @"back";
            }
            
            if (item && itemType) {
                // we should not have to set this, but inheriting the tint color seems
                // to not work when using the dark theme, i.e. UIBarStyleBlack
                item.tintColor = [GoNativeAppConfig sharedAppConfig].tintColor;
                
                // add item
                if ([toolbarItems count] > 0) {
                    // add spacer
                    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
                    spacer.enabled = NO;
                    [toolbarItems addObject:spacer];
                    [toolbarItemTypes addObject:@"spacer"];
                    [toolbarItemUrlRegexes addObject:[NSNull null]];
                }
                [toolbarItems addObject:item];
                [toolbarItemTypes addObject:itemType];
                [toolbarItemUrlRegexes addObject:itemRegexes];
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
    // update back buttons
    for (NSInteger i = 0; i < [self.toolbarItems count]; i++) {
        if ([self.toolbarItemTypes[i] isEqualToString:@"back"]) {
            UIBarButtonItem *item = self.toolbarItems[i];
            item.enabled = [self.wvc canGoBack];
        
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

@end
