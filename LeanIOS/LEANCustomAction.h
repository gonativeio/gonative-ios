//
//  LEANCustomAction.h
//  GoNativeIOS
//
//  Created by Weiyin He on 4/17/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANCustomAction : NSObject
@property NSString *name;
@property NSString *javascript;

+ (NSArray*)actionsForUrl:(NSURL*)url;
@end
