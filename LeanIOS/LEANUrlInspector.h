//
//  LEANUrlInspector.h
//  GoNativeIOS
//
//  Created by Weiyin He on 4/22/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANUrlInspector : NSObject

@property NSString *userId;

- (void)setup;
+ (LEANUrlInspector*)sharedInspector;
- (void)inspectUrl:(NSURL*)url;
@end
