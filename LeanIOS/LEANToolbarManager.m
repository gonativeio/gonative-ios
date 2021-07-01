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

    // loop through items from appConfig
    if ([GoNativeAppConfig sharedAppConfig].toolbarItems) {
        
        // fill the toolbar with spaces first
        UIBarButtonItem *flexibleSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        toolbarItems = [NSMutableArray arrayWithObjects:flexibleSpacer, flexibleSpacer, flexibleSpacer, flexibleSpacer, flexibleSpacer, nil];
        toolbarItemTypes = [NSMutableArray arrayWithObjects:@"spacer", @"spacer", @"spacer", @"spacer", @"spacer", nil];
        BOOL refreshButtonEnabled = NO;
        
        void (^addToolbarItemAndRemove) (int, NSObject*, NSString*) = ^(int toolbarIndex, NSObject* item, NSString *itemType){
            [toolbarItems removeObjectAtIndex:toolbarIndex];
            [toolbarItems insertObject:item atIndex:toolbarIndex];
            [toolbarItemTypes removeObjectAtIndex:toolbarIndex];
            [toolbarItemTypes insertObject:itemType atIndex:toolbarIndex];
        };
        
        // loop through items to add to
        for (NSDictionary *entry in [GoNativeAppConfig sharedAppConfig].toolbarItems) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            NSString *system = entry[@"system"];
            NSString *title = entry[@"title"];
            
            // process items
            UIBarButtonItem *item = nil;
            NSString *itemType = nil;
            int toolbarIndex = 0;

            if ([system isEqualToString:@"back"]) {
                if(!title) title = @"Back";
                item = [[UIBarButtonItem alloc] initWithCustomView:[self createButtonWithTitle:title forButton:@"Back" andIcon:@"fas fa-chevron-left" centerRefresh:NO]];
                itemType = @"back";
                toolbarIndex = 0;
                if([system isEqualToString:@"back"]){
                    NSArray *itemRegexes = [LEANUtilities createRegexArrayFromStrings:entry[@"urlRegex"]];
                    [toolbarItemUrlRegexes addObject:itemRegexes];
                }
            } else if([system isEqualToString:@"refresh"]){
                // to be added later below
                refreshButtonEnabled = YES;
            } else if ([system isEqualToString:@"forward"]){
                if(!title) title = @"Forward";
                item = [[UIBarButtonItem alloc] initWithCustomView:[self createButtonWithTitle:title forButton:@"Forward" andIcon:@"fas fa-chevron-right" centerRefresh:NO]];
                itemType = @"forward";
                toolbarIndex = 4;
            } else return;
            item.enabled = NO;
            
            // add items except refresh for now
            if(![system isEqualToString:@"refresh"]) addToolbarItemAndRemove(toolbarIndex, item, itemType);
        }
        
        // refresh button needs different positioning based on the presence of Forward button
        if(refreshButtonEnabled){
            // center refresh button if forward button is not present
            UIBarButtonItem *item;
            if([toolbarItemTypes.lastObject isEqualToString:@"spacer"]){
                // remove extra space from the toolbar
                [toolbarItems removeObjectAtIndex:4];
                [toolbarItemTypes removeObjectAtIndex:4];
                item = [[UIBarButtonItem alloc] initWithCustomView:[self createButtonWithTitle:nil forButton:@"Refresh" andIcon:@"fas fa-redo-alt" centerRefresh:YES]];
            } else {
                item = [[UIBarButtonItem alloc] initWithCustomView:[self createButtonWithTitle:nil forButton:@"Refresh" andIcon:@"fas fa-redo-alt" centerRefresh:NO]];
            }
            // insert refresh button
            [toolbarItems insertObject:item atIndex:2];
            [toolbarItemTypes insertObject:@"refresh" atIndex:2];
            [toolbarItems removeObjectAtIndex:3];
            [toolbarItemTypes removeObjectAtIndex:3];
        }
    }
    
    self.toolbarItems = toolbarItems;
    self.toolbarItemTypes = toolbarItemTypes;
    self.toolbarItemUrlRegexes = toolbarItemUrlRegexes;
    [self.toolbar setItems:self.toolbarItems animated:YES];
}

- (UIButton*)createButtonWithTitle:(NSString*)title forButton:(NSString*)buttonType andIcon:(NSString*)icon centerRefresh:(BOOL)centerRefreshBool{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    
    // title
    if(title) [button setTitle:title forState:UIControlStateNormal];
    if(title) [button setTitleColor:[UIColor colorNamed:@"tintColor"] forState:UIControlStateNormal];
    
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
    // 1. Check canGoBack
    // 2. Check toolbarNavigation.urlRegex (if exist)
    // 3. Check Back button regex (if exists)
    // 1 && (2 || 3)
    
    NSString *urlString = [url absoluteString];
    BOOL backEnabled = NO;
    BOOL backRegexMatches = YES;
    
    // update toolbar buttons
    for (NSInteger i = 0; i < [self.toolbarItems count]; i++) {
        if ([self.toolbarItemTypes[i] isEqualToString:@"back"] || [self.toolbarItemTypes[i] isEqualToString:@"forward"] || [self.toolbarItemTypes[i] isEqualToString:@"refresh"]) {
            
            UIBarButtonItem *item = self.toolbarItems[i];
            if([self.toolbarItemTypes[i] isEqualToString:@"back"]){
                item.enabled = [self.wvc canGoBack];
                backEnabled = item.enabled;
            } else if([self.toolbarItemTypes[i] isEqualToString:@"forward"]){
                item.enabled = [self.wvc canGoForward];
                // design the button "disabled"
                UIView *customView = [item customView];
                if(item.enabled) customView.alpha = 1;
                else customView.alpha = 0.3;
                [item setCustomView:customView];
            } else {
                item.enabled = YES;
            }
            
            // check regex array of Back button
            if([self.toolbarItemTypes[i] isEqualToString:@"back"]){
                NSArray *regexArray = self.toolbarItemUrlRegexes[i];
                if ([regexArray isKindOfClass:[NSArray class]] && [regexArray count] > 0) {
                    backRegexMatches = NO;
                    for (NSPredicate *predicate in regexArray) {
                        BOOL matches = NO;
                        @try {
                            matches = [predicate evaluateWithObject:urlString];
                        }
                        @catch (NSException* exception) {
                            NSLog(@"Error in toolbar regexes: %@", exception);
                        }

                        if (matches) {
                            backRegexMatches = YES;
                            break;
                        }
                    }
                }
            }
        }
    }
    
    // check for toolbar regex match
    BOOL toolbarRegexEnabled = YES;
    for (RegexEnabled *toolbarRegexObject in [[GoNativeAppConfig sharedAppConfig] toolbarRegexes]) {
        toolbarRegexEnabled = NO;
        BOOL matches = NO;
        @try {
            matches = [toolbarRegexObject.regex evaluateWithObject:urlString];
        }
        @catch (NSException* exception) {
            NSLog(@"Error in toolbar regexes: %@", exception);
        }
        if (matches) {
            toolbarRegexEnabled = toolbarRegexObject.enabled;
            break;
        }
    }
    
    // show/hide toolbar
    BOOL makeVisible = NO;
    if (self.visibility == LEANToolbarVisibilityAlways) {
        makeVisible = YES;
    } else if(backEnabled && (backRegexMatches || toolbarRegexEnabled)){
        makeVisible = YES;
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
