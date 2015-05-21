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
- (void)didLoadUrl:(NSURL*)url;
@end
