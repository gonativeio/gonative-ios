//
//  LEANAppDelegate.h
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LEANCastController.h"
#import "Reachability.h"

@interface LEANAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property LEANCastController *castController;
@property NSURLRequest *currentRequest;
@property Reachability *internetReachability;
- (void)configureApplication;

@end
