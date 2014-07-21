//
//  LEANWebViewController.h
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "REFrostedViewController.h"
#import "LEANProfilePicker.h"

@interface LEANWebViewController : UIViewController <UIWebViewDelegate>

@property IBOutlet UIWebView* webview;
@property BOOL checkLoginSignup;
@property LEANProfilePicker *profilePicker;
@property NSURL *initialUrl;

- (IBAction) showMenu;
- (void) loadUrl:(NSURL*) url;
- (void) loadRequest:(NSURLRequest*) request;
- (void) runJavascript:(NSString *) script;
- (void) logout;

@end
