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
        self.loggedIn = NO;
        [self statusUpdated];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSArray * cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url];
    NSDictionary * headers = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
    [request setAllHTTPHeaderFields:headers];
    NSString *userAgent = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserAgent"];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];

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
        
        if ([self.currentUrl matchesPathOf:[LEANAppConfig sharedAppConfig].loginDetectionURLnotloggedin]) {
            self.loggedIn = NO;
        }
        else {
            self.loggedIn = YES;
        }
        
        [self statusUpdated];
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
}


@end
