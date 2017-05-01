//
//  GNCustomHeaders.m
//  GoNativeIOS
//
//  Created by Weiyin He on 5/1/17.
//  Copyright © 2017 GoNative.io LLC. All rights reserved.
//

#import "GNCustomHeaders.h"
#import "GoNativeAppConfig.h"

@implementation GNCustomHeaders
+(NSDictionary*)getCustomHeaders
{
    NSDictionary *config = [GoNativeAppConfig sharedAppConfig].customHeaders;
    if (!config) {
        return nil;
    }
    
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:config.count];
    
    for (id key in config) {
        if ([key isKindOfClass:[NSString class]] && [key length] > 0) {
            id val = [self interpolateValues:config[key]];
            if (val) {
                result[key] = val;
            }
        }
    }
    
    return result;
}

+(NSString*)interpolateValues:(NSString*)value
{
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    if ([value containsString:@"%DEVICEID%"]) {
        NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        value = [value stringByReplacingOccurrencesOfString:@"%DEVICEID%" withString:deviceId];
    }
    
    if ([value containsString:@"%DEVICENAME64%"]) {
        NSString *deviceName = [[UIDevice currentDevice] name];
        NSData *data = [deviceName dataUsingEncoding:NSUTF8StringEncoding];
        NSString *deviceName64 = [data base64EncodedStringWithOptions:0];
        value = [value stringByReplacingOccurrencesOfString:@"%DEVICENAME64%" withString:deviceName64];
    }
    
    return value;
}
@end
