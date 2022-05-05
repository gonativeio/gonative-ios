//
//  LEANAppDelegate.h
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Reachability.h"
#import "GNRegistrationManager.h"
@import GoNativeCore;

@interface LEANAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) GNRegistrationManager *registration;
@property Reachability *internetReachability;
@property BOOL isFirstLaunch;
@property NSString *previousInitialUrl;
@property NSString *apnsToken;
@property (strong, nonatomic) GNBridge *bridge;

- (void)configureApplication;

@end
