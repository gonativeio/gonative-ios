//
//  LEANConfigUpdater.m
//  GoNativeIOS
//
//  Created by Weiyin He on 7/22/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANConfigUpdater.h"
#import "LEANAppConfig.h"

@interface LEANConfigUpdater ()

@end

@implementation LEANConfigUpdater

- (void)updateConfig
{
    NSString *publicKey = [LEANAppConfig sharedAppConfig].publicKey;
    if (!publicKey) {
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"https://gonative.io/static/appConfig/%@.json", publicKey];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDownloadTask *downloadTask =  [session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if (httpResponse.statusCode >= 400) {
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

@end
