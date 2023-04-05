//
//  LEANTabManager.h
//  GoNativeIOS
//
//  Created by Weiyin He on 8/14/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LEANWebViewController.h"

@interface LEANTabManager : NSObject
- (instancetype)initWithTabBar:(UITabBar*)tabBar webviewController:(LEANWebViewController*)wvc;
- (void)handleUrl:(NSURL *)url query:(NSDictionary*)query;
- (void)didLoadUrl:(NSURL*)url;
- (void)selectTabWithUrl:(NSString*)url javascript:(NSString*)javascript;
- (void)autoSelectTabForUrl:(NSURL*)url;
- (void)selectTabNumber:(NSUInteger)number;
- (void)deselectTabs;
- (void)setTabsWithJson:(NSDictionary*)json;
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection;

@property BOOL javascriptTabs; // disables auto-loading of tabs from config
@end
