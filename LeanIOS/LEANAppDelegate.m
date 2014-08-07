//
//  LEANAppDelegate.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANAppDelegate.h"
#import "LEANAppConfig.h"
#import "LEANWebViewIntercept.h"
#import "LEANUrlCache.h"
#import "LEANPushManager.h"
#import "LEANRootViewController.h"
#import "LEANConfigUpdater.h"

@interface LEANAppDelegate() <UIAlertViewDelegate>
@property UIAlertView *alertView;
@property NSURL *url;

@end

@implementation LEANAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    // local cache
    [NSURLCache setSharedURLCache:[[LEANUrlCache alloc] init]];
    
    // tint color from app config
    if ([LEANAppConfig sharedAppConfig].tintColor) {
        self.window.tintColor = [LEANAppConfig sharedAppConfig].tintColor;
    }
    
    // start cast controller
    if ([LEANAppConfig sharedAppConfig].enableChromecast) {
        self.castController = [[LEANCastController alloc] init];
        [self.castController performScan:YES];
    }
    
    // modify default user agent to include the suffix
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    NSString *originalAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    NSString *userAgentAdd = [LEANAppConfig sharedAppConfig].userAgentAdd;
    if (!userAgentAdd) userAgentAdd = @"gonative";
    NSString *newAgent = [NSString stringWithFormat:@"%@ %@", originalAgent, userAgentAdd];
    NSDictionary *dictionary = @{@"UserAgent": newAgent};
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    
    // proxy handler to intercept HTML for custom CSS and viewport
    [LEANWebViewIntercept initialize];
    
    // Register for remote push notifications
    if ([LEANAppConfig sharedAppConfig].pushNotifications) {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
    }
    
    // If launched from push notification and it contains a url, set the initialUrl.
    id notification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (notification && notification[@"u"]) {
        NSURL *url = [NSURL URLWithString:notification[@"u"]];
        if (url) {
            UIViewController *rvc = self.window.rootViewController;
            if ([rvc isKindOfClass:[LEANRootViewController class]]) {
                [(LEANRootViewController*)rvc setInitialUrl:url];
            }
        }
    }
    
    // clear notifications
    application.applicationIconBadgeNumber = 1;
    application.applicationIconBadgeNumber = 0;
    
    // download new config
    [[[LEANConfigUpdater alloc] init] updateConfig];
    
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [LEANPushManager sharedPush].token = deviceToken;
}


- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Error registering for push notifications: %@", err);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    NSString *urlString = userInfo[@"u"];
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *message = userInfo[@"aps"][@"alert"];
    
    UIViewController *rvc = self.window.rootViewController;
    BOOL webviewOnTop = NO;
    if ([rvc isKindOfClass:[LEANRootViewController class]]) {
        webviewOnTop = [(LEANRootViewController*)rvc webviewOnTop];
    }
    
    if (application.applicationState == UIApplicationStateActive) {
        // app was in foreground. Show an alert, and include a "view" button if there is a url and the webview is currently the top view.
        if (url && webviewOnTop) {
            self.alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"View", nil];
            self.url = url;
        } else {
            self.alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [self.alertView show];
        }
        
        [self.alertView show];
    } else {
        // app was in background, and user tapped on notification
        if (url && webviewOnTop) {
            [(LEANRootViewController*)rvc loadUrl:url];
        }
    }
    
    // clear notifications
    application.applicationIconBadgeNumber = 1;
    application.applicationIconBadgeNumber = 0;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        UIViewController *rvc = self.window.rootViewController;
        if ([rvc isKindOfClass:[LEANRootViewController class]]) {
            [(LEANRootViewController*)rvc loadUrl:self.url];
        }
    }
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
