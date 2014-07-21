//
//  LEANLoginManager.h
//  LeanIOS
//
//  Created by Weiyin He on 2/12/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *kLEANLoginManagerNotificationName = @"io.gonative.ios.LoginManagerNotification";

@interface LEANLoginManager : NSObject
@property BOOL loggedIn;
@property NSString *loginStatus;

// singleton
+(LEANLoginManager*)sharedManager;

// force a check. Interrupts pending check. Use this if it's highly likely the state has changed.
-(void) checkLogin;

// Run a check if there is not one already pending.
-(void) checkIfNotAlreadyChecking;
@end
