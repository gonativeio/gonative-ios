//
//  LEANPushManager.m
//  GoNativeIOS
//
//  Created by Weiyin He on 6/16/14.
//  Copyright (c) 2014 The Lean App. All rights reserved.
//

#import "LEANPushManager.h"
#import "LEANAppConfig.h"
#import "LEANInstallation.h"

@interface LEANPushManager ()
@end

@implementation LEANPushManager

static NSString * kGonativeRegistrationEndpoint = @"https://push.gonative.io/api/register";

+ (LEANPushManager *)sharedManager
{
    static LEANPushManager *sharedPush;
    
    @synchronized(self)
    {
        if (!sharedPush){
            sharedPush = [[LEANPushManager alloc] init];
        }
        return sharedPush;
    }
}

- (void)sendRegistration
{
    if (![LEANAppConfig sharedAppConfig].publicKey) {
        NSLog(@"publicKey is required for push");
        return;
    }
    
    if (!self.token) {
        return;
    }
    
    NSMutableDictionary *toSend = [[LEANInstallation info] mutableCopy];
    toSend[@"token"] = [self.token base64EncodedStringWithOptions:0];
    
    if (self.userID) toSend[@"userID"] = self.userID;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:toSend options:0 error:nil];
//    NSLog(@"sending registration json: %@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    
    NSURL *url = [NSURL URLWithString:kGonativeRegistrationEndpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            NSLog(@"Error sending token: %@", connectionError);
            return;
        }
        
        if (response) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
            
            if (httpResponse.statusCode == 200) {
                // done!
            }
            else {
                NSLog(@"Unsuccessful sending token. Response: %@", httpResponse);
            }
        }
    }];
    
}

@synthesize token = _token;
- (void)setToken:(NSData *)token
{
    _token = token;
    [self sendRegistration];
}

- (NSData*)token
{
    return _token;
}

@synthesize userID = _userID;
- (void)setUserID:(NSString *)userID
{
    if ((_userID && ![_userID isEqualToString:userID]) || _userID != userID) {
        _userID = userID;
        [self sendRegistration];
    }
    _userID = userID;
}

- (NSString*)userID
{
    return _userID;
}


@end
