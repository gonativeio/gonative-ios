//
//  LEANLoginManager.m
//  LeanIOS
//
//  Created by Weiyin He on 2/12/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANLoginManager.h"
#import "LEANUtilities.h"
#import "LEANAppConfig.h"
#import "NSURL+LEANUtilities.h"
#import "LEANUrlInspector.h"

@interface LEANLoginManager () <NSURLConnectionDataDelegate>
@property BOOL isChecking;
@property NSURLConnection *connection;
@property NSURL *currentUrl;
@end


@implementation LEANLoginManager

+ (LEANLoginManager *)sharedManager
{
    static LEANLoginManager *sharedManager;
    
    @synchronized(self)
    {
        if (!sharedManager){
            sharedManager = [[LEANLoginManager alloc] init];
            
            sharedManager.loggedIn = NO;
            [sharedManager checkLogin];
        }
        return sharedManager;
    }
}


- (void)statusUpdated
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANLoginManagerNotificationName object:self];
}

-(void) checkLogin
{
    [self.connection cancel];
    self.isChecking = YES;
    
    NSURL *url = [LEANAppConfig sharedAppConfig].loginDetectionURL;
    if (!url) {
        NSLog(@"Warning: trying to check login without a loginDetectionURL");
        self.loggedIn = NO;
        [self performSelector:@selector(statusUpdated) withObject:self afterDelay:1.0];
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSString *userAgent = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserAgent"];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
    [request setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];

    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

-(void) checkIfNotAlreadyChecking
{
    if (!self.isChecking) {
        [self checkLogin];
    }
}

#pragma mark URL Connection Data Delegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        self.isChecking = NO;
        [connection cancel];
        
        // iterate through loginDetectionRegexes
        NSArray *regexes = [LEANAppConfig sharedAppConfig].loginDetectRegexes;
        NSString *urlString = [self.currentUrl absoluteString];
        for (NSUInteger i = 0; i < [regexes count]; i++) {
            NSPredicate *predicate = regexes[i];
            if ([predicate evaluateWithObject:urlString]) {
                id entry = [LEANAppConfig sharedAppConfig].loginDetectLocations[i];
                self.loggedIn = [entry[@"loggedIn"] boolValue];
                self.loginStatus = entry[@"status"];
                if (!self.loginStatus) self.loginStatus = self.loggedIn ? @"loggedIn" : @"default";
                
                [self statusUpdated];
                return;
            }
        }
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
    // follow all redirects.
    self.currentUrl = [request URL];
    return request;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.isChecking = NO;
    self.loginStatus = @"default";
    self.loggedIn = NO;
    [self statusUpdated];
}


@end
