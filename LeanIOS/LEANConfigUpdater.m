//
//  LEANConfigUpdater.m
//  GoNativeIOS
//
//  Created by Weiyin He on 7/22/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANConfigUpdater.h"
#import "LEANInstallation.h"

@interface LEANConfigUpdater ()

@end

@implementation LEANConfigUpdater

+ (void)registerEvent:(NSString*)event data:(NSDictionary *)data
{
    if (!event || [GoNativeAppConfig sharedAppConfig].disableEventRecorder) {
        return;
    }
    
    NSMutableDictionary *dict = [[LEANInstallation info] mutableCopy];
    dict[@"event"] = event;
    if (data) {
        dict[@"additionalData"] = data;
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    
    NSURL *url = [NSURL URLWithString:@"https://events.gonative.io/api/events/new"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    }];
    [task resume];
}

@end
