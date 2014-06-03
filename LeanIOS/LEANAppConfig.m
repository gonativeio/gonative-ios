//
//  LEANAppConfig.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANAppConfig.h"
#import "LEANUtilities.h"
#import <CommonCrypto/CommonCrypto.h>

@interface LEANAppConfig ()
@property id json;
@end

@implementation LEANAppConfig

+ (LEANAppConfig *)sharedAppConfig
{
    static LEANAppConfig *sharedAppConfig;
    
    @synchronized(self)
    {
        if (!sharedAppConfig){
            sharedAppConfig = [[LEANAppConfig alloc] init];
            
            NSString *configPath = [[NSBundle mainBundle] pathForResource:@"appConfig" ofType:@"plist"];
            sharedAppConfig.dict = [[NSDictionary alloc] initWithContentsOfFile:configPath];
            
            
            sharedAppConfig.tintColor = [LEANUtilities colorFromHexString:sharedAppConfig[@"iosTintColor"]];
            
            sharedAppConfig.titleTextColor = [LEANUtilities colorFromHexString:sharedAppConfig[@"iosTitleColor"]];
            sharedAppConfig.initialURL = [NSURL URLWithString:sharedAppConfig[@"initialURL"]];
            sharedAppConfig.initialHost = [sharedAppConfig.initialURL host];
            if ([sharedAppConfig.initialHost hasPrefix:@"www."]) {
                sharedAppConfig.initialHost = [sharedAppConfig.initialHost stringByReplacingCharactersInRange:NSMakeRange(0, [@"www." length]) withString:@""];
            }
            sharedAppConfig.loginDetectionURL = [NSURL URLWithString:sharedAppConfig[@"loginDetectionURL"]];
            sharedAppConfig.loginDetectionURLnotloggedin = [NSURL URLWithString:sharedAppConfig[@"loginDetectionURLnotloggedin"]];
            sharedAppConfig.loginURL = [NSURL URLWithString:sharedAppConfig[@"loginURL"]];
            sharedAppConfig.loginURLfail = [NSURL URLWithString:sharedAppConfig[@"loginURLfail"]];
            sharedAppConfig.forgotPasswordURL = [NSURL URLWithString:sharedAppConfig[@"forgotPasswordURL"]];
            sharedAppConfig.forgotPasswordURLfail = [NSURL URLWithString:sharedAppConfig[@"forgotPasswordURLfail"]];
            sharedAppConfig.signupURL = [NSURL URLWithString:sharedAppConfig[@"signupURL"]];
            sharedAppConfig.signupURLfail = [NSURL URLWithString:sharedAppConfig[@"signupURLfail"]];
            sharedAppConfig.loginIsFirstPage = [sharedAppConfig[@"loginIsFirstPage"] boolValue];
            sharedAppConfig.showShareButton = [sharedAppConfig[@"showShareButton"] boolValue];
            sharedAppConfig.enableChromecast = [sharedAppConfig[@"enableChromecast"] boolValue];
            
            if (sharedAppConfig[@"forceLandscapeRegex"]) {
                sharedAppConfig.forceLandscapeMatch = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sharedAppConfig[@"forceLandscapeRegex"]];
            }
            
            if (sharedAppConfig[@"allowZoom"]) {
                sharedAppConfig.allowZoom = [sharedAppConfig[@"allowZoom"] boolValue];
            }
            else
                sharedAppConfig.allowZoom = YES;
            
            
            // read json
            NSString *path = [[NSBundle mainBundle] pathForResource:@"appConfig" ofType:@"json"];
            NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:path];
            [inputStream open];
            sharedAppConfig.json = [NSJSONSerialization JSONObjectWithStream:inputStream options:0 error:nil];
            [inputStream close];
            
            if ([sharedAppConfig hasKey:@"redirects"]) {
                NSUInteger len = [sharedAppConfig[@"redirects"] count];
                sharedAppConfig.redirects = [[NSMutableDictionary alloc] initWithCapacity:len];
                for (id redirect in sharedAppConfig[@"redirects"]) {
                    [sharedAppConfig.redirects setValue:redirect[@"to"] forKey:redirect[@"from"]];
                }
            }
            
            if ([sharedAppConfig hasKey:@"showToolbar"])
                sharedAppConfig.showToolbar = [sharedAppConfig[@"showToolbar"] boolValue];
            else sharedAppConfig.showToolbar = YES;
            
            if ([sharedAppConfig hasKey:@"showNavigationBar"])
                sharedAppConfig.showNavigationBar = [sharedAppConfig[@"showNavigationBar"] boolValue];
            else sharedAppConfig.showNavigationBar = YES;
            
        }
        
        return sharedAppConfig;
    }
}

- (BOOL)hasKey:(id)key
{
    return (self.json[key] && self.json[key] != [NSNull null]) || self.dict[key];
}

- (id)objectForKey:(id)aKey;
{
    // first check json
    if (self.json[aKey]) {
        return self.json[aKey];
    } else
        return [self.dict objectForKey:aKey];
}

- (id)objectForKeyedSubscript:(id)key
{
    return [self objectForKey:key];
}

@end
