//
//  LEANPushManager.h
//  GoNativeIOS
//
//  Created by Weiyin He on 6/16/14.
//  Copyright (c) 2014 The Lean App. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANPushManager : NSObject

@property NSData *token;
@property NSString *userID;

// singleton
+(LEANPushManager*)sharedManager;

- (void)sendRegistration;

@end
