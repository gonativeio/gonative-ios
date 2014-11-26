//
//  LEANActionManager.h
//  GoNativeIOS
//
//  Created by Weiyin He on 11/25/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LEANWebViewController.h"

@interface LEANActionManager : NSObject
@property NSArray *items;

- (instancetype)initWithWebviewController:(LEANWebViewController*)wvc;
- (void)didLoadUrl:(NSURL*)url;
@end
