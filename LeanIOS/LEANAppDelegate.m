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
#import "LEANSimulator.h"

@interface LEANAppDelegate() <UIAlertViewDelegate>
@property UIAlertView *alertView;
@property NSURL *url;
@end

@implementation LEANAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    LEANAppConfig *appConfig = [LEANAppConfig sharedAppConfig];
    
    // Register launch
    [LEANConfigUpdater registerEvent:@"launch" data:nil];
    
    // proxy handler to intercept HTML for custom CSS and viewport
    [LEANWebViewIntercept initialize];
    
    // Register for remote push notifications
    if (appConfig.pushNotifications) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound) categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        } else {
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
        }
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
    
    // download new config
    [[[LEANConfigUpdater alloc] init] updateConfig];
    
    [self configureApplication];
    
    // listen for reachability
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    return YES;
}

- (void)configureApplication
{
    LEANAppConfig *appConfig = [LEANAppConfig sharedAppConfig];

    // tint color from app config
    if (appConfig.tintColor) {
        self.window.tintColor = appConfig.tintColor;
    }
    
    // start cast controller
    if (appConfig.enableChromecast) {
        self.castController = [[LEANCastController alloc] init];
        [self.castController performScan:YES];
    } else {
        [self.castController performScan:NO];
        self.castController = nil;
    }
    
    // clear notifications
    if (appConfig.pushNotifications) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]) {
            UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
            if (settings.types & UIUserNotificationTypeBadge) {
                [UIApplication sharedApplication].applicationIconBadgeNumber = 1;
                [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
            }
        } else {
            [UIApplication sharedApplication].applicationIconBadgeNumber = 1;
            [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
        }
    }
    
    [LEANSimulator checkStatus];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [LEANPushManager sharedManager].token = deviceToken;
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
    // for push notifications
    if (buttonIndex == 1) {
        UIViewController *rvc = self.window.rootViewController;
        if ([rvc isKindOfClass:[LEANRootViewController class]]) {
            [(LEANRootViewController*)rvc loadUrl:self.url];
        }
    }
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    return [LEANSimulator openURL:url];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if ([LEANAppConfig sharedAppConfig].isSimulator) {
        [LEANSimulator checkSimulatorSetting];
    }
}

- (void)application:(UIApplication *)application didChangeStatusBarOrientation:(UIInterfaceOrientation)oldStatusBarOrientation
{
    [LEANSimulator didChangeStatusBarOrientation];
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

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
