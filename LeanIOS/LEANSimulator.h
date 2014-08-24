//
//  LEANSimulator.h
//  GoNativeIOS
//
//  Created by Weiyin He on 8/21/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANSimulator : NSObject
+(BOOL)openURL:(NSURL*)url;
+(void)checkSimulatorSetting;
+(void)checkStatus;
+(void)didChangeStatusBarOrientation;
@end
