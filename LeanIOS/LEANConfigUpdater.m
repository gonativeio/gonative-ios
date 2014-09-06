//
//  LEANConfigUpdater.m
//  GoNativeIOS
//
//  Created by Weiyin He on 7/22/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANConfigUpdater.h"
#import "LEANAppConfig.h"
#import "LEANInstallation.h"

@interface LEANConfigUpdater ()

@end

@implementation LEANConfigUpdater

- (void)updateConfig
{
    NSString *publicKey = [LEANAppConfig sharedAppConfig].publicKey;
    if (!publicKey) {
        return;
    }
    
    if ([LEANAppConfig sharedAppConfig].isSimulator) {
        publicKey = @"simulator";
    }
    
    NSString *urlString = [NSString stringWithFormat:@"https://gonative.io/static/appConfig/%@.json", publicKey];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDownloadTask *downloadTask =  [session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if (error || httpResponse.statusCode != 200 || !location) {
            return;
        }
        
        // parse json to make sure it's valid
        NSInputStream *inputStream = [NSInputStream inputStreamWithURL:location];
        [inputStream open];
        NSError *jsonError;
        [NSJSONSerialization JSONObjectWithStream:inputStream options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"Invalid appConfig.json downloaded");
            [inputStream close];
            return;
        }
        [inputStream close];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *destination = [LEANAppConfig urlForOtaConfig];
        [fileManager removeItemAtURL:destination error:nil];
        [fileManager moveItemAtURL:location toURL:destination error:nil];
    }];
    [downloadTask resume];
}


+ (void)registerEvent:(NSString*)event data:(NSDictionary *)data
{
    if (!event) {
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
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
    }];
    
}

@end
