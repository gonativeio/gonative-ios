//
//  LEANToolbarManager.m
//  GoNativeIOS
//
//  Created by Weiyin He on 5/20/15.
//  Copyright (c) 2015 GoNative.io LLC. All rights reserved.
//

#import "LEANToolbarManager.h"
#import "LEANWebViewController.h"
#import "LEANAppConfig.h"

@interface LEANToolbarManager()
@property UIToolbar *toolbar;
@property NSArray *toolbarItems;
@property NSArray *backButtons;
@property LEANWebViewController *wvc;
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
    self.visibility = [LEANAppConfig sharedAppConfig].toolbarVisibility;
    NSMutableArray *toolbarItems = [NSMutableArray array];
    NSMutableArray *backButtons = [NSMutableArray array];
    
    if ([LEANAppConfig sharedAppConfig].toolbarItems) {
        for (NSDictionary *entry in [LEANAppConfig sharedAppConfig].toolbarItems) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            NSString *system = entry[@"system"];
            
            // process items
            UIBarButtonItem *item = nil;
            if ([system isKindOfClass:[NSString class]] && [system isEqualToString:@"back"]) {
                item = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:self action:@selector(backPressed:)];
                item.enabled = NO;
                [backButtons addObject:item];
            }
            
            if (item) {
                // add item
                if ([toolbarItems count] > 0) {
                    // add spacer
                    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
                    spacer.enabled = NO;
                    [toolbarItems addObject:spacer];
                }
                [toolbarItems addObject:item];
            }
        }
    }
    
    self.toolbarItems = toolbarItems;
    self.backButtons = backButtons;
    [self.toolbar setItems:self.toolbarItems animated:YES];
}

- (void)didLoadUrl:(NSURL*)url
{
    // update back buttons
    if ([self.backButtons count] > 0) {
        BOOL canGoBack = [self.wvc canGoBack];
        for (UIBarButtonItem *item in self.backButtons) {
            item.enabled = canGoBack;
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
