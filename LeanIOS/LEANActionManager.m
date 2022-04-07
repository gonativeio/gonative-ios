//
//  LEANActionManager.m
//  GoNativeIOS
//
//  Created by Weiyin He on 11/25/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANActionManager.h"
#import "GonativeIO-Swift.h"

@interface LEANActionManager ()
@property (weak, nonatomic) LEANWebViewController *wvc;
@property NSString *currentMenuID;
@property NSMutableArray *urls;
@property NSMutableArray *buttons;
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
    NSArray *actionRegexes = [GoNativeAppConfig sharedAppConfig].actionRegexes;
    if (!actionRegexes || !url) return;
    
    NSString *urlString = [url absoluteString];
    
    for (NSUInteger i = 0; i < [actionRegexes count]; i++) {
        NSPredicate *predicate = actionRegexes[i];
        BOOL matches = NO;
        @try {
            matches = [predicate evaluateWithObject:urlString];
        }
        @catch (NSException* exception) {
            NSLog(@"Error in action regex: %@", exception);
        }

        if (matches) {
            [self setMenuID:[GoNativeAppConfig sharedAppConfig].actionIDs[i]];
            return;
        }
    }
    
    [self setMenuID:nil];
}

- (void)setMenuID:(NSString*)menuID
{
    BOOL changed;
    if (self.currentMenuID == nil && menuID == nil) {
        changed = NO;
    } else {
        changed = ![self.currentMenuID isEqualToString:menuID];
    }
    
    if (changed) {
        self.currentMenuID = menuID;
        [self createButtonItems];
    }
}

- (void)createButtonItems
{
    if (!self.currentMenuID) {
        self.items = nil;
        return;
    }
    
    NSMutableArray *newButtonItems = [NSMutableArray array];
    self.urls = [NSMutableArray array];
    self.buttons = [NSMutableArray array];
    
    NSArray *menu = [GoNativeAppConfig sharedAppConfig].actions[self.currentMenuID];
    for (NSDictionary *entry in menu) {
        NSString *system = entry[@"system"];
        if ([system isKindOfClass:[NSString class]] && [system isEqualToString:@"share"]) {
            UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self.wvc action:@selector(sharePage:)];
            [newButtonItems insertObject:button atIndex:0];
        } else {
            NSString *label = entry[@"label"];
            NSString *iconName = entry[@"icon"];
            NSString *url = entry[@"url"];
            // the tint color is automatically applied to the button, so a black icon is enough
            UIImage *iconImage = [LEANIcons imageForIconIdentifier:iconName size:28 color:[UIColor blackColor]];
            
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            [button setImage:iconImage forState:UIControlStateNormal];
            [button addTarget:self action:@selector(itemWasSelected:)
                forControlEvents:UIControlEventTouchUpInside];
            [button setFrame:CGRectMake(0, 0, 36, 30)];
            
            UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
            
            barButtonItem.accessibilityLabel = label;
            [newButtonItems insertObject:barButtonItem atIndex:0];
            [self.buttons insertObject:button atIndex:0];
            if (!url) {
                url = @"";
            }
            [self.urls insertObject:url atIndex:0];
        }
    }
    
    self.items = newButtonItems;
}

- (void)itemWasSelected:(id)sender
{
    NSUInteger index = [self.buttons indexOfObject:sender];
    if (index != NSNotFound && index < [self.urls count]) {
        NSString *url = self.urls[index];
        [self.wvc loadUrlString:url];
    }
}


@end
