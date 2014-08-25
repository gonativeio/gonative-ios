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
@property NSMutableDictionary *urlToDisownPolicy;
@property NSMutableArray *urlSets;
@property NSMutableSet *urlsToLoad;
@property UIWebView *currentLoadingWebview;
@property NSString *currentLoadingUrl;
@property NSURL *lastUrlRequested;
@property BOOL isViewControllerLoading;

@end


@implementation LEANWebViewPool


+ (LEANWebViewPool *)sharedPool
{
    static LEANWebViewPool *sharedPool;
    
    @synchronized(self)
    {
        if (!sharedPool) {
            sharedPool = [[LEANWebViewPool alloc] init];
            [sharedPool setup];
        }
        return sharedPool;
    }
}

- (void)setup
{
    self.urlToWebview = [NSMutableDictionary dictionary];
    self.urlToDisownPolicy = [NSMutableDictionary dictionary];
    self.urlSets = [NSMutableArray array];
    self.urlsToLoad = [NSMutableSet set];
    self.isViewControllerLoading = YES;
    
    // first remove to make sure we don't get duplicate notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // subscribe to notification about webview loading
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANWebViewControllerUserStartedLoading object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANWebViewControllerUserFinishedLoading object:nil];
    
    // subscribe to dynamic config change notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedWebViewPools object:nil];
    
    [self processConfig];
}

- (void)processConfig
{
    NSArray *config = [LEANAppConfig sharedAppConfig].webviewPools;
    if (![config isKindOfClass:[NSArray class]]) {
        return;
    }
    
    for (NSDictionary *entry in config) {
        if ([entry[@"urls"] isKindOfClass:[NSArray class]]) {
            NSMutableSet *urlSet = [NSMutableSet set];
            for (id urlEntry in entry[@"urls"]) {
                NSString *urlString = nil;
                LEANWebViewPoolDisownPolicy policy = kLEANWebViewPoolDisownPolicyDefault;
                
                if ([urlEntry isKindOfClass:[NSString class]]) {
                    urlString = urlEntry;
                } else if ([urlEntry isKindOfClass:[NSDictionary class]] && [urlEntry[@"url"] isKindOfClass:[NSString class]]) {
                    
                    urlString = urlEntry[@"url"];
                    
                    NSString *policyString = urlEntry[@"disown"];
                    
                    if ([policyString isKindOfClass:[NSString class]]) {
                        if ([policyString isEqualToString:@"reload"]) {
                            policy = LEANWebViewPoolDisownPolicyReload;
                        } else if ([policyString isEqualToString:@"never"]) {
                            policy = LEANWebViewPoolDisownPolicyNever;
                        } else if ([policyString isEqualToString:@"always"]) {
                            policy = LEANWebViewPoolDisownPolicyAlways;
                        }
                    }
                }
                
                if (urlString) {
                    [urlSet addObject:urlString];
                    self.urlToDisownPolicy[urlString] = @(policy);
                }
                
            }
            
            [self.urlSets addObject:urlSet];
        }
    }
    
    // if config changed, we may have to load webviews corresponding to the previously requested url
    if (self.lastUrlRequested) {
        [self webviewForUrl:self.lastUrlRequested policy:nil];
    }
    
    [self resumeLoading];
}

- (void)disownWebview:(UIWebView *)webview
{
    NSArray *keys = [self.urlToWebview allKeysForObject:webview];
    [self.urlToWebview removeObjectsForKeys:keys];
    [self.urlsToLoad addObjectsFromArray:keys];
}

- (void)didReceiveNotification:(NSNotification*)notification
{
    if ([[notification name] isEqualToString:kLEANWebViewControllerUserStartedLoading]) {
        self.isViewControllerLoading = YES;
        [self.currentLoadingWebview stopLoading];
    }
    else if ([[notification name] isEqualToString:kLEANWebViewControllerUserFinishedLoading]) {
        self.isViewControllerLoading = NO;
        [self resumeLoading];
    }
    else if ([[notification name] isEqualToString:kLEANAppConfigNotificationProcessedWebViewPools]) {
        [self processConfig];
    }
}

- (void)resumeLoading
{
    if (self.isViewControllerLoading) {
        return;
    }
    
    if (self.currentLoadingWebview && self.currentLoadingRequest) {
        [self.currentLoadingWebview loadRequest:self.currentLoadingRequest];
        return;
    }
    
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
        
        [self resumeLoading];
    }
}

- (UIWebView*)webviewForUrl:(NSURL *)url policy:(LEANWebViewPoolDisownPolicy*)policy
{
    self.lastUrlRequested = url;
    NSString *urlString = [url absoluteString];
    
    NSSet *urlSet = [self urlSetForUrl:urlString];
    if (urlSet && [urlSet count] > 0) {
        // do not add the urls already loaded or loading
        NSMutableSet *newUrls = [urlSet mutableCopy];
        if (self.currentLoadingUrl) {
            [newUrls removeObject:self.currentLoadingUrl];
        }
        [newUrls minusSet:[NSSet setWithArray:[self.urlToWebview allKeys]]];
        
        [self.urlsToLoad unionSet:newUrls];
    }
    
    UIWebView *webview = self.urlToWebview[urlString];
    if (webview) {
        // if the policy pointer is provided, output the policy by writing to the pointer
        if (policy) {
            if (self.urlToDisownPolicy[urlString]) {
                *policy = [self.urlToDisownPolicy[urlString] integerValue];
            } else {
                *policy = kLEANWebViewPoolDisownPolicyDefault;
            }
        }
        
        [self resumeLoading];
    } else {
        // if webview is not found, then presumably the webviewcontroller will be loading the page. resumeLoading will happen once the finish notification is received.
    }
    
    return webview;
}

- (NSSet*)urlSetForUrl:(NSString*)url
{
    NSMutableSet *result = [NSMutableSet set];
    for (NSSet *set in self.urlSets) {
        if ([set containsObject:url]) {
            [result unionSet:set];
        }
    }
    return result;
}

@end
