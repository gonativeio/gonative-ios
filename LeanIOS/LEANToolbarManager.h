//
//  LEANToolbarManager.h
//  GoNativeIOS
//
//  Created by Weiyin He on 5/20/15.
//  Copyright (c) 2015 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LEANWebViewController.h"

@interface LEANToolbarManager : NSObject
- (instancetype)initWithToolbar:(UIToolbar*)toolbar webviewController:(LEANWebViewController*)wvc;
- (void)handleUrl:(NSURL *)url query:(NSDictionary*)query;
- (void)didLoadUrl:(NSURL*)url;
- (void)setToolbarEnabled:(BOOL)enabled;
@property NSString *urlMimeType;
@end
