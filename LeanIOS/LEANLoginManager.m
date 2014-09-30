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
#import <WebKit/WebKit.h>

@interface LEANLoginManager () <NSURLConnectionDataDelegate, WKNavigationDelegate>
@property BOOL isChecking;
@property NSURLConnection *connection;
@property NSURL *currentUrl;
@property WKWebView *wkWebview;
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

- (void)setStatus:(NSString *)newStatus loggedIn:(BOOL)loggedIn
{
    if (!newStatus) {
        newStatus = loggedIn ? @"loggedIn" : @"default";
    }
    
    BOOL changed = NO;
    if (loggedIn != self.loggedIn || ![newStatus isEqualToString:self.loginStatus]) {
        changed = YES;
    }
    
    self.loggedIn = loggedIn;
    self.loginStatus = newStatus;
    [self statusUpdated];
    
    if (changed) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANLoginManagerStatusChangedNotification object:self];
    }
    
}

-(void) checkLogin
{
    [self.connection cancel];
    [self.wkWebview stopLoading];
    
    NSURL *url = [LEANAppConfig sharedAppConfig].loginDetectionURL;
    if (!url) {
        self.loggedIn = NO;
        [self performSelector:@selector(statusUpdated) withObject:self afterDelay:1.0];
        return;
    }
    
    self.isChecking = YES;
    
    if ([LEANAppConfig sharedAppConfig].useWKWebView) {
        if (!self.wkWebview) {
            WKWebViewConfiguration *config = [[NSClassFromString(@"WKWebViewConfiguration") alloc] init];
            config.processPool = [LEANUtilities wkProcessPool];
            self.wkWebview = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:CGRectZero configuration:config];
            self.wkWebview.navigationDelegate = self;
        }
        [self.wkWebview loadRequest:[NSURLRequest requestWithURL:url]];
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        NSString *userAgent = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserAgent"];
        [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
        [request setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
        
        self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    }
}

-(void) checkIfNotAlreadyChecking
{
    if (!self.isChecking) {
        [self checkLogin];
    }
}

- (void)finishedOnUrl:(NSURL*)url
{
    NSString *urlString = [url absoluteString];
    
    // iterate through loginDetectionRegexes
    NSArray *regexes = [LEANAppConfig sharedAppConfig].loginDetectRegexes;
    for (NSUInteger i = 0; i < [regexes count]; i++) {
        NSPredicate *predicate = regexes[i];
        if ([predicate evaluateWithObject:urlString]) {
            id entry = [LEANAppConfig sharedAppConfig].loginDetectLocations[i];
            [self setStatus:entry[@"status"] loggedIn:[entry[@"loggedIn"] boolValue]];
            return;
        }
    }
}

- (void)failedWithError:(NSError*)error
{
    self.isChecking = NO;
    [self setStatus:@"default" loggedIn:NO];
}

#pragma mark URL Connection Data Delegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response isKindOfClass:[NSURLResponse class]]) {
        self.isChecking = NO;
        [connection cancel];
        
        [self finishedOnUrl:self.currentUrl];
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
    [self failedWithError:error];
}

- (void)stopChecking
{
    if (self.connection) {
        [self.connection cancel];
        self.connection = nil;
    }
    
    if (self.wkWebview) {
        [self.wkWebview stopLoading];
    }
    self.currentUrl = nil;
    self.isChecking = NO;
}

# pragma mark WebView navigation delegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    self.isChecking = NO;
    [self finishedOnUrl:webView.URL];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self failedWithError:error];
}


@end
