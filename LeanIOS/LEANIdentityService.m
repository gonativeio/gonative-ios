//
//  LEANIdentityService.m
//  GoNativeIOS
//
//  Created by Weiyin He on 9/7/15.
//  Copyright © 2015 GoNative.io LLC. All rights reserved.
//

#import "LEANIdentityService.h"
#import "GoNativeAppConfig.h"
#import <Parse/Parse.h>

@interface LEANIdentityService()
@property NSData *identityResponseData;
@end

@implementation LEANIdentityService
+(LEANIdentityService*)sharedService
{
    static LEANIdentityService *sharedService;
    @synchronized(self)
    {
        if (!sharedService){
            sharedService = [[LEANIdentityService alloc] init];
        }
        return sharedService;
    }
}

- (void)checkUrl:(NSURL *)url
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    if (!appConfig.checkIdentityUrlRegexes ||
        [appConfig.checkIdentityUrlRegexes count] <= 0 ||
        !appConfig.identityEndpointUrl ||
        !url) {
        return;
    }
    
    NSString *urlString = [url absoluteString];
    
    for (NSPredicate *test in appConfig.checkIdentityUrlRegexes) {
        if ([test evaluateWithObject:urlString]) {
            [self getIdentity];
            break;
        }
    }
}

-(void)getIdentity
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    NSURL *endpoint = appConfig.identityEndpointUrl;
    if (!endpoint) return;
    
    if (!appConfig.parseEnabled || !appConfig.parsePushEnabled) return;
    
    // custom configuration that disables cache
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    [[session dataTaskWithURL:endpoint completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
        if (error) {
            NSLog(@"Error getting identity: %@", error);
            return;
        }
        
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSLog(@"Identity response is not NSHTTPURLResponse");
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if (httpResponse.statusCode != 200) {
            NSLog(@"Identity response status code was %ld", (long)httpResponse.statusCode);
            return;
        }
        
        if (!data || [data length] == 0) {
            NSLog(@"No identity data received");
            return;
        }
        
        if (self.identityResponseData && [data isEqualToData:self.identityResponseData]) {
            // no need to change anything
            return;
        }
        
        // save it for future comparisons
        self.identityResponseData = data;
        
        // let's parse some json
        NSError *jsonError;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (jsonError) {
            NSLog(@"Error parsing JSON for identity: %@", jsonError);
            return;
        }
        
        if (![dict isKindOfClass:[NSDictionary class]]) {
            NSLog(@"Identity data was not JSON object");
            return;
        }
        
        NSMutableDictionary *objectForParse = [NSMutableDictionary dictionary];
        for (NSString *key in [dict allKeys]) {
            id value = dict[key];
            // only allow numbers, strings, nulls, arrays of numbers and strings
            if (![value isKindOfClass:[NSNumber class]] &&
                ![value isKindOfClass:[NSString class]] &&
                ![value isKindOfClass:[NSArray class]] &&
                ![value isKindOfClass:[NSNull class]]) {
                NSLog(@"Type not allowed in identity object key %@", key);
                continue;
            }
            if ([value isKindOfClass:[NSArray class]]) {
                bool arrayValid = YES;
                for (id arrayVal in value) {
                    if (![arrayVal isKindOfClass:[NSNumber class]] &&
                        ![arrayVal isKindOfClass:[NSString class]]) {
                        NSLog(@"Type not allowed in identity array key %@", key);
                        arrayValid = NO;
                        break;
                    }
                }
                if (!arrayValid) continue;
            }
            
            // append GN to key names, in case of conflict with something in parse (like deviceToken)
            NSString *parseKey = [NSString stringWithFormat:@"GN%@", key];
            objectForParse[parseKey] = value;
        }
        
        [self setParseData:objectForParse];
    }] resume];
}

-(void)setParseData:(NSDictionary*)data
{
    PFInstallation *parseInstall = [PFInstallation currentInstallation];
    for (NSString *key in [data allKeys]) {
        parseInstall[key] = data[key];
    }
    
    // delete keys starting with GN that are not in our data
    for (NSString *key in [parseInstall allKeys]) {
        if ([key hasPrefix:@"GN"] &&
            !data[key]) {
            
            [parseInstall removeObjectForKey:key];
        }
    }
    
    [parseInstall saveInBackground];
}
@end
