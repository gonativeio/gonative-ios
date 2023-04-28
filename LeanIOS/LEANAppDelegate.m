//
//  LEANAppDelegate.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANAppDelegate.h"
#import "LEANWebViewIntercept.h"
#import "LEANUrlCache.h"
#import "LEANRootViewController.h"
#import "LEANConfigUpdater.h"
#import "LEANUtilities.h"
#import "GNConfigPreferences.h"
#import "GonativeIO-Swift.h"
#import <AppTrackingTransparency/ATTrackingManager.h>

@implementation LEANAppDelegate

@synthesize bridge;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // clear keychain item if this is first launch
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"hasLaunched"]) {
        GoNativeKeychain *keyChain = [[GoNativeKeychain alloc] init];
        [keyChain deleteSecret];
        
        [[NSUserDefaults standardUserDefaults] setValue:@YES forKey:@"hasLaunched"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        self.isFirstLaunch = YES;
    } else {
        self.isFirstLaunch = NO;
    }
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    
    // Register launch
    [LEANConfigUpdater registerEvent:@"launch" data:nil];
    
    // proxy handler to intercept HTML for custom CSS and viewport
    [LEANWebViewIntercept register];
    
    // registration service
    self.registration = [GNRegistrationManager sharedManager];
    [self.registration processConfig:appConfig.registrationEndpoints];
    
    
    [self configureApplication];
    
    // listen for reachability
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    // disable sleep if requested
    if (appConfig.keepScreenOn) {
        application.idleTimerDisabled = YES;
    }
    
    self.bridge = [GNBridge new];
    
    [bridge application:application didFinishLaunchingWithOptions:launchOptions];
    
    return YES;
}

- (void)configureApplication
{
    self.window.tintColor = [UIColor colorNamed:@"tintColor"];
}

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"Successfully registered for push notifications");
    [self setApnsToken:[deviceToken base64EncodedStringWithOptions:0]];
    [self.bridge application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Error registering for push notifications: %@", err);
    [self setApnsToken:nil];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    if ([bridge application:app openURL:url options:options])
        return YES;
    
    if ([url.scheme hasSuffix:@".https"] || [url.scheme hasSuffix:@".http"]) {
        UIViewController *rvc = self.window.rootViewController;
        
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        if ([url.scheme hasSuffix:@".https"]) {
            components.scheme = @"https";
        } else if ([url.scheme hasSuffix:@".http"]) {
            components.scheme = @"http";
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [(LEANRootViewController*)rvc loadUrl:[components URL]];
        });
        
        return YES;
    }
    
    return NO;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    if (appConfig.configError) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *message = @"Invalid appConfig json";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"button-ok", @"Button: OK") style:UIAlertActionStyleCancel handler:nil]];
            LEANRootViewController *rvc = (LEANRootViewController*) self.window.rootViewController;
            [rvc presentAlert:alert];
        });
    }
    
    [bridge applicationDidBecomeActive:application];
    if (self.previousInitialUrl) {
        NSString *initialUrl = [[GNConfigPreferences sharedPreferences] getInitialUrl];
        if (![self.previousInitialUrl isEqualToString:initialUrl]) {
            // was changed in Settings
            UIViewController *rvc = self.window.rootViewController;
            if ([rvc isKindOfClass:[LEANRootViewController class]]) {
                LEANRootViewController *vc = (LEANRootViewController*)rvc;
                if (initialUrl && initialUrl.length > 0) {
                    [vc loadUrl:[NSURL URLWithString:initialUrl]];
                } else {
                    [vc loadUrl: [GoNativeAppConfig sharedAppConfig].initialURL];
                }
                self.previousInitialUrl = initialUrl;
            }
        }
    }
    
    if ([self hasTrackingDescription] && (appConfig.iOSRequestATTConsentOnLoad || appConfig.facebookEnabled)) {
        if (@available(iOS 14.5, *)) {
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kLEANAppConfigNotificationAppTrackingStatusChanged object:nil];
            }];
        }
    }
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application
  supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    if (![window.rootViewController isKindOfClass:[LEANRootViewController class]]) {
        // likely to be a full-screen video. Allow all orientations.
        return UIInterfaceOrientationMaskAllButUpsideDown;
    }

    // default implementation, use what the Info.plist specifies
    return [application supportedInterfaceOrientationsForWindow:window];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [bridge applicationWillResignActive:application];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [bridge applicationDidEnterBackground:application];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rvc = self.window.rootViewController;
        if ([rvc isKindOfClass:[LEANRootViewController class]]) {
            NSString *js = [LEANUtilities createJsForCallback:@"gonative_app_resumed" data:nil];
            [(LEANRootViewController *)rvc runJavascript:js];
        }
    });
    
    [bridge applicationWillEnterForeground:application];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [bridge applicationWillTerminate:application];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
{
    if ([bridge application:application continueUserActivity:userActivity]) {
        return YES;
    }
    
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        UIViewController *rvc = self.window.rootViewController;
        if ([rvc isKindOfClass:[LEANRootViewController class]] && userActivity.webpageURL) {
            LEANRootViewController *vc = (LEANRootViewController*)rvc;
            [vc loadUrl:userActivity.webpageURL];
            return YES;
        }
    }
    
    return NO;
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [bridge application:application didReceiveRemoteNotification:userInfo];
}

#pragma mark -

-(BOOL)hasTrackingDescription {
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSUserTrackingUsageDescription"] isKindOfClass:[NSString class]];
}

@end
