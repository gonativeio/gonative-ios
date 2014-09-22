//
//  LEANInstallation.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/9/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANInstallation.h"
#import "LEANAppConfig.h"
#import <sys/utsname.h>

@implementation LEANInstallation

+ (NSDictionary*)info
{
    NSString *publicKey = [LEANAppConfig sharedAppConfig].publicKey;
    if (!publicKey) publicKey = @"";
    
    NSString *deviceRegKey = [LEANAppConfig sharedAppConfig].deviceRegKey;
    
    BOOL debug = NO;
#ifdef DEBUG
    debug = YES;
#endif
    
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *hardware = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    if (!hardware) hardware = @"";
    
    
    NSString *distribution;
    if (debug) {
        distribution = @"debug";
    } else if ([[NSUserDefaults standardUserDefaults] objectForKey:@"isAppio"]) {
        distribution = @"appio";
    } else if ([[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"]) {
        distribution = @"adhoc";
    } else {
        distribution = @"appstore";
    }
    
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleId) bundleId = @"";
    
    NSString *appVersion = [[NSBundle mainBundle] infoDictionary][(NSString*)kCFBundleVersionKey];
    if (!appVersion) appVersion = @"";
    
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    UIDevice *device = [UIDevice currentDevice];
    NSString *timeZone = [[NSTimeZone localTimeZone] name];
    
    NSMutableDictionary *info = [@{@"platform": @"ios",
                           @"publicKey": publicKey,
                           @"appId": bundleId,
                           @"appVersion": appVersion,
                           @"distribution": distribution,
                           @"language": language,
                           @"os": device.systemName,
                           @"osVersion": device.systemVersion,
                           @"model": device.model,
                           @"timeZone": timeZone,
                           @"hardware": hardware,
                           @"installationId": [device.identifierForVendor UUIDString]} mutableCopy];
    
    if (deviceRegKey) info[@"deviceRegKey"] = deviceRegKey;
    
    return info;
}

@end
