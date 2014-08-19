//
//  LEANWebViewPool.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/18/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANWebViewPool.h"
#import "LEANAppConfig.h"
#import "LEANWebViewController.h"
#import "LEANUtilities.h"

@interface LEANWebViewPool () <UIWebViewDelegate>
@property NSMutableDictionary *urlToWebview;
@property NSMutableArray *urlSets;
@property NSMutableSet *urlsToLoad;
@property UIWebView *currentLoadingWebview;
@property NSString *currentLoadingUrl;

@end


@implementation LEANWebViewPool


+ (LEANWebViewPool *)sharedPool
{
    static LEANWebViewPool *sharedPool;
    
    @synchronized(self)
    {
        if (!sharedPool) {
            sharedPool = [[LEANWebViewPool alloc] init];
        }
        return sharedPool;
    }
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        self.urlToWebview = [NSMutableDictionary dictionary];
        self.urlSets = [NSMutableArray array];
        
        NSArray *config = [LEANAppConfig sharedAppConfig].webviewPools;
        for (NSDictionary *entry in config) {
            if ([entry[@"urls"] isKindOfClass:[NSArray class]]) {
                NSMutableSet *urlSet = [NSMutableSet set];
                for (NSString *url in entry[@"urls"]) {
                    [urlSet addObject:url];
                }
                
                [self.urlSets addObject:urlSet];
            }
        }
        
        self.urlsToLoad = [NSMutableSet set];
        
        // subscribe to notification about webview loading
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANWebViewControllerUserStartedLoading object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANWebViewControllerUserFinishedLoading object:nil];
    }
    return self;
}

- (void)didReceiveNotification:(NSNotification*)notification
{
    if ([[notification name] isEqualToString:kLEANWebViewControllerUserStartedLoading]) {
        [self.currentLoadingWebview stopLoading];
    }
    else if ([[notification name] isEqualToString:kLEANWebViewControllerUserFinishedLoading]) {
        if (self.currentLoadingWebview && self.currentLoadingRequest) {
            [self.currentLoadingWebview loadRequest:self.currentLoadingRequest];
        } else {
            [self loadNextRequest];
        }
    }
}

- (void)loadNextRequest
{
    if ([self.urlsToLoad count] > 0) {
        
        NSString *urlString = [self.urlsToLoad anyObject];
        self.currentLoadingUrl = urlString;
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        UIWebView *webview = [[UIWebView alloc] init];
        [LEANUtilities configureWebView:webview];
        
        webview.delegate = self;
        self.currentLoadingWebview = webview;
        self.currentLoadingRequest = request;
        
        [self.urlsToLoad removeObject:urlString];
        [self.currentLoadingWebview loadRequest:request];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!webView.isLoading) {
        self.urlToWebview[self.currentLoadingUrl] = webView;
        self.currentLoadingUrl = nil;
        self.currentLoadingRequest = nil;
        self.currentLoadingWebview = nil;
        
        [self loadNextRequest];
    }
}

- (UIWebView*)webviewForUrl:(NSURL *)url
{
    NSString *urlString = [url absoluteString];
    UIWebView *webview = self.urlToWebview[urlString];
    if (webview) {
        return webview;
    }
    
    NSSet *urlSet = [self urlSetForUrl:urlString];
    if (urlSet) {
        // remove urls already loaded or loading
        NSMutableSet *newUrls = [urlSet mutableCopy];
        if (self.currentLoadingUrl) {
            [newUrls removeObject:self.currentLoadingUrl];
        }
        [newUrls minusSet:[NSSet setWithArray:[self.urlToWebview allKeys]]];
        
        [self.urlsToLoad unionSet:newUrls];
        
    }
    
    return nil;
}

- (NSSet*)urlSetForUrl:(NSString*)url
{
    for (NSSet *set in self.urlSets) {
        if ([set containsObject:url]) {
            return set;
        }
    }
    return nil;
}

@end
