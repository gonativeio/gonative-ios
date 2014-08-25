//
//  LEANRootViewController.h
//  GoNativeIOS
//
//  Created by Weiyin He on 2/7/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "REFrostedViewController.h"
#import "LEANWebViewController.h"

@interface LEANRootViewController : REFrostedViewController

@property LEANWebViewController *webViewController;

- (void)loadUrl:(NSURL*)url;
- (BOOL)webviewOnTop;
- (void)setInitialUrl:(NSURL *)url; // for initial launch from push notification

@end
