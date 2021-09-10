//
//  LEANLoginManager.m
//  LeanIOS
//
//  Created by Weiyin He on 2/12/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANLoginManager.h"
#import "LEANUtilities.h"
#import "NSURL+LEANUtilities.h"
#import "LEANUrlInspector.h"
#import <WebKit/WebKit.h>

@interface LEANLoginManager () <NSURLSessionDataDelegate, WKNavigationDelegate>
@property BOOL isChecking;
@property NSURLSession *session;
@property NSURLSessionTask *task;
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
            
            NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
            sharedManager.session = [NSURLSession sessionWithConfiguration:config delegate:sharedManager delegateQueue:nil];
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
    [self.task cancel];
    [self.wkWebview stopLoading];
    
    NSURL *url = [GoNativeAppConfig sharedAppConfig].loginDetectionURL;
    if (!url) {
        self.loggedIn = NO;
        [self performSelector:@selector(statusUpdated) withObject:self afterDelay:1.0];
        return;
    }
    
    self.isChecking = YES;
    
    if ([GoNativeAppConfig sharedAppConfig].useWKWebView) {
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
        
        self.task = [self.session dataTaskWithRequest:request];
        [self.task resume];
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
    NSArray *regexes = [GoNativeAppConfig sharedAppConfig].loginDetectRegexes;
    for (NSUInteger i = 0; i < [regexes count]; i++) {
        NSPredicate *predicate = regexes[i];
        BOOL matches = NO;
        @try {
            matches = [predicate evaluateWithObject:urlString];
        }
        @catch (NSException* exception) {
            NSLog(@"Error in login detection regex: %@", exception);
        }

        if (matches) {
            id entry = [GoNativeAppConfig sharedAppConfig].loginDetectLocations[i];
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

- (void)stopChecking
{
    if (self.task) {
        [self.task cancel];
        self.task = nil;
    }
    
    if (self.wkWebview) {
        [self.wkWebview stopLoading];
    }
    self.isChecking = NO;
}

#pragma mark URL Session Delegate
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self failedWithError:error];
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    self.isChecking = NO;
    [self finishedOnUrl:response.URL];
    completionHandler(NSURLSessionResponseCancel);
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
