//
//  LEANWebViewPool.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/18/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANWebViewPool.h"
#import "LEANWebViewController.h"
#import "LEANUtilities.h"
#import "LEANLoginManager.h"

@interface LEANWebViewPool () <WKNavigationDelegate>
@property NSMutableDictionary *urlToWebview;
@property NSMutableDictionary *urlToDisownPolicy;
@property NSMutableArray *urlSets;
@property NSMutableSet *urlsToLoad;
@property UIView *currentLoadingWebview;
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
    // explicit message to clear pools
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANWebViewControllerClearPools object:nil];
    
    // subscribe to dynamic config change notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedWebViewPools object:nil];
    
    // login status changing
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANLoginManagerStatusChangedNotification object:nil];
    
    [self processConfig];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)processConfig
{
    NSArray *config = [GoNativeAppConfig sharedAppConfig].webviewPools;
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

- (void)disownWebview:(UIView *)webview
{
    NSArray *keys = [self.urlToWebview allKeysForObject:webview];
    [self.urlToWebview removeObjectsForKeys:keys];
    [self.urlsToLoad addObjectsFromArray:keys];
}

- (void)didReceiveNotification:(NSNotification*)notification
{
    if ([[notification name] isEqualToString:kLEANWebViewControllerUserStartedLoading]) {
        self.isViewControllerLoading = YES;
        [self stopLoading];
    }
    else if ([[notification name] isEqualToString:kLEANWebViewControllerUserFinishedLoading]) {
        self.isViewControllerLoading = NO;
        [self resumeLoading];
    }
    else if ([[notification name] isEqualToString:kLEANAppConfigNotificationProcessedWebViewPools]) {
        [self processConfig];
    } else if ([[notification name] isEqualToString:kLEANLoginManagerStatusChangedNotification] ||
               [[notification name] isEqualToString:kLEANWebViewControllerClearPools]) {
        [self flushAll];
    }
}

- (void)stopLoading
{
    if ([self.currentLoadingWebview isKindOfClass:NSClassFromString(@"WKWebView")]) {
        [(WKWebView*)self.currentLoadingWebview stopLoading];
    }
}

- (void)resumeLoading
{
    if (self.isViewControllerLoading) {
        return;
    }
    
    if ([self.currentLoadingWebview isKindOfClass:NSClassFromString(@"WKWebView")] &&
        [(WKWebView*)self.currentLoadingWebview isLoading]) {
        return;
    }
    
    if (self.currentLoadingWebview && self.currentLoadingRequest) {
        if ([self.currentLoadingWebview isKindOfClass:NSClassFromString(@"WKWebView")]) {
            [(WKWebView*)self.currentLoadingWebview loadRequest:self.currentLoadingRequest];
        }
        return;
    }
    
    if ([self.urlsToLoad count] > 0) {
        NSString *urlString = [self.urlsToLoad anyObject];
        self.currentLoadingUrl = urlString;
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[LEANUtilities urlWithString:urlString]];
        self.currentLoadingRequest = request;
        [self.urlsToLoad removeObject:urlString];
        
        WKWebViewConfiguration *config = [[NSClassFromString(@"WKWebViewConfiguration") alloc] init];
        config.processPool = [LEANUtilities wkProcessPool];
        WKWebView *webview = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:CGRectZero configuration:config];
        [LEANUtilities configureWebView:webview];
        webview.navigationDelegate = self;
        self.currentLoadingWebview = webview;
        [webview loadRequest:request];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self didFinishLoad];
}

- (void)didFinishLoad
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.currentLoadingWebview isKindOfClass:NSClassFromString(@"WKWebView")]) {
            ((WKWebView*)self.currentLoadingWebview).navigationDelegate = nil;
            self.urlToWebview[self.currentLoadingUrl] = self.currentLoadingWebview;
        }
        
        self.currentLoadingUrl = nil;
        self.currentLoadingRequest = nil;
        self.currentLoadingWebview = nil;
        
        [self resumeLoading];
    });
}

- (UIView*)webviewForUrl:(NSURL *)url policy:(LEANWebViewPoolDisownPolicy*)policy
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
    
    UIView *webview = self.urlToWebview[urlString];
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

- (void)flushAll
{
    [self stopLoading];
    
    self.currentLoadingWebview = nil;
    self.currentLoadingUrl = nil;
    self.currentLoadingRequest = nil;
    
    self.lastUrlRequested = nil;
    [self.urlToWebview removeAllObjects];
}

@end
