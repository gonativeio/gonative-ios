//
//  LEANInstallation.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/9/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANInstallation.h"
#import "LEANAppDelegate.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <sys/utsname.h>

@implementation LEANInstallation

+ (NSDictionary*)info
{
    NSString *publicKey = [GoNativeAppConfig sharedAppConfig].publicKey;
    if (!publicKey) publicKey = @"";
    
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
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *bundleInfo = mainBundle.infoDictionary;
    
    NSString *bundleId = mainBundle.bundleIdentifier;
    if (!bundleId) bundleId = @"";
    
    NSString *appBuild = bundleInfo[(NSString*)kCFBundleVersionKey];
    if (!appBuild) appBuild = @"";
    
    NSString *appVersion = bundleInfo[@"CFBundleShortVersionString"];
    if (!appVersion) appVersion = @"";
    
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    UIDevice *device = [UIDevice currentDevice];
    NSString *timeZone = [[NSTimeZone localTimeZone] name];
    
    NSMutableDictionary *info = [@{@"platform": @"ios",
                           @"publicKey": publicKey,
                           @"appId": bundleId,
                           @"appVersion": appVersion,
                           @"appBuild": appBuild,
                           @"distribution": distribution,
                           @"language": language,
                           @"os": device.systemName,
                           @"osVersion": device.systemVersion,
                           @"model": device.model,
                           @"timeZone": timeZone,
                           @"hardware": hardware,
                           @"installationId": [device.identifierForVendor UUIDString],
                           @"deviceName": device.name} mutableCopy];
    
    LEANAppDelegate *appDelegate = (LEANAppDelegate*)[UIApplication sharedApplication].delegate;
    info[@"isFirstLaunch"] = [NSNumber numberWithBool:appDelegate.isFirstLaunch];
    
#if !(TARGET_IPHONE_SIMULATOR)
    CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
    NSMutableArray *carrierNames = [NSMutableArray array];
    if (netinfo) {
        NSDictionary<NSString *, CTCarrier *> *carriers = netinfo.serviceSubscriberCellularProviders;
        NSString *carrierName = [[carriers allValues] firstObject].carrierName;
        if (carrierName) {
            info[@"carrierName"] = carrierName;
        }
        
        [carriers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, CTCarrier * _Nonnull obj, BOOL * _Nonnull stop) {
            if (obj.carrierName) {
                [carrierNames addObject:obj.carrierName];
            }
        }];
    }
    info[@"carrierNames"] = carrierNames;
#endif
    
    return info;
}

@end
