//
//  LEANAppDelegate.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Parse/Parse.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import "LEANAppDelegate.h"
#import "GoNativeAppConfig.h"
#import "LEANWebViewIntercept.h"
#import "LEANUrlCache.h"
#import "LEANPushManager.h"
#import "LEANRootViewController.h"
#import "LEANConfigUpdater.h"
#import "LEANSimulator.h"
#import "GNRegistrationManager.h"

#define LOCAL_NOTIFICATION_FILE @"localNotifications.plist"

@interface LEANAppDelegate() <UIAlertViewDelegate>
@property UIAlertView *alertView;
@property NSURL *url;
@end

@implementation LEANAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    
    // Register launch
    [LEANConfigUpdater registerEvent:@"launch" data:nil];
    
    // proxy handler to intercept HTML for custom CSS and viewport
    [LEANWebViewIntercept register];
    
    // set up Parse SDK
    NSString *parseInstallationId;
    if (appConfig.parseEnabled) {
        [Parse setApplicationId:appConfig.parseApplicationId clientKey:appConfig.parseClientKey];
        parseInstallationId = [[PFInstallation currentInstallation] installationId];
    }
    
    // OneSignal
    if (appConfig.oneSignalEnabled) {
        self.oneSignal = [[OneSignal alloc] initWithLaunchOptions:launchOptions appId:appConfig.oneSignalAppId handleNotification:^(NSString *message, NSDictionary *additionalData, BOOL isActive) {
            
            NSString *urlString = additionalData[@"u"];
            if (![urlString isKindOfClass:[NSString class]]) urlString = additionalData[@"targetUrl"];
            NSURL *url = nil;
            if ([urlString isKindOfClass:[NSString class]]) {
                url = [NSURL URLWithString:urlString];
            }

            BOOL webviewOnTop = NO;
            UIViewController *rvc = self.window.rootViewController;
            if ([rvc isKindOfClass:[LEANRootViewController class]]) {
                webviewOnTop = [(LEANRootViewController*)rvc webviewOnTop];
            }

            if (isActive) {
                // Show an alert, and include a "view" button if there is a url and the webview is currently the top view.
                if (url && webviewOnTop) {
                    self.alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"View", nil];
                    self.url = url;
                } else {
                    self.alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                }
                
                [self.alertView show];

            } else {
                if (url && webviewOnTop) {
                    // for when the app is launched from scratch from a push notification
                    [(LEANRootViewController*)rvc setInitialUrl:url];
                    
                    // for when the app was backgrounded
                    [(LEANRootViewController*)rvc loadUrl:url];
                }
            }
        }];
    }
    
    // registration service
    GNRegistrationManager *registration = [GNRegistrationManager sharedManager];
    [registration processConfig:appConfig.registrationEndpoints];
    if (parseInstallationId) {
        [registration setParseInstallationId:parseInstallationId];
    }
    if (appConfig.oneSignalEnabled) {
        [self.oneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
            [registration setOneSignalUserId:userId];
        }];
    }
    
    // Register for remote push notifications
    if (appConfig.pushNotifications || appConfig.parsePushEnabled || registration.pushEnabled) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound) categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    
    // Parse analytics
    if (appConfig.parseAnalyticsEnabled) {
        [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
    }
    
    // If launched from push notification and it contains a url, set the initialUrl.
    id notification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (!notification) {
        // also check local notification
        UILocalNotification *localNotification = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];
        if (localNotification) notification = localNotification.userInfo;
    }
    if ([notification isKindOfClass:[NSDictionary class]]) {
        NSString *targetUrl = notification[@"u"];
        if (![targetUrl isKindOfClass:[NSString class]]) {
            targetUrl = notification[@"targetUrl"];
        }
        
        if ([targetUrl isKindOfClass:[NSString class]]) {
            NSURL *url = [NSURL URLWithString:targetUrl];
            if (url) {
                UIViewController *rvc = self.window.rootViewController;
                if ([rvc isKindOfClass:[LEANRootViewController class]]) {
                    [(LEANRootViewController*)rvc setInitialUrl:url];
                }
            }
        }
    }
    
    // download new config
    [[[LEANConfigUpdater alloc] init] updateConfig];
    
    [self configureApplication];
    [self clearBadge];
    
    // listen for reachability
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    // Facebook SDK
    if (appConfig.facebookEnabled) {
        [[FBSDKApplicationDelegate sharedInstance] application:application
                                 didFinishLaunchingWithOptions:launchOptions];
    }
    
    // disable sleep if requested
    if (appConfig.keepScreenOn) {
        application.idleTimerDisabled = YES;
    }
    
    return YES;
}

- (void)configureApplication
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];

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
    
    [LEANSimulator checkStatus];
}

- (void)clearBadge {
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];

    if (appConfig.pushNotifications || appConfig.parsePushEnabled) {
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
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    if (appConfig.pushNotifications) {
        // Gonative push service
        [LEANPushManager sharedManager].token = deviceToken;
    }
    if (appConfig.parsePushEnabled) {
        // Parse push service
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation setDeviceTokenFromData:deviceToken];
        [currentInstallation saveInBackground];
    }
    
    [[GNRegistrationManager sharedManager] setPushRegistrationToken:deviceToken];
}


- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Error registering for push notifications: %@", err);
}

// This method gets called when the app is in these states
//  1) app is foreground. We will create a UIAlertView
//  2) app is inactive, i.e. app was launched but user switched to another app. This method will get called if
//     the user taps a push notification. We will load the targetUrl if it is specified.
//  3) app is background, i.e. app is not foreground, and we got a push notification with aps:{content-available:1}.
//     We will create a local notification and present it immediately.
// Note that this method does not get called if an app is loaded from scratch, either because it has been force quit
// or because it has been automatically purged from memory due to not being used for a while.
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    // Do not handle if from OneSignal, as they provide their own handler via some crazy runtime injection.
    if ([userInfo[@"custom"] isKindOfClass:[NSDictionary class]]) {
        completionHandler(UIBackgroundFetchResultNewData);
        return;
    }
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    if (!appConfig.pushNotifications && !appConfig.parsePushEnabled) {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }
    
    NSString *urlString = userInfo[@"u"];
    if (![urlString isKindOfClass:[NSString class]]) urlString = userInfo[@"targetUrl"];
    NSURL *url = nil;
    if ([urlString isKindOfClass:[NSString class]]) {
        url = [NSURL URLWithString:urlString];
    }
    
    NSString *message = userInfo[@"aps"][@"alert"];
    // we can't call it "alert" here because apple(or maybe parse) will remove it from the JSON
    if (!message) message = userInfo[@"message"];
    if (!message) {
        NSLog(@"No alert message in push notification");
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }
    
    id notificationId = userInfo[@"n_id"];
    if (!notificationId) notificationId = userInfo[@"notificationId"];
    
    UIViewController *rvc = self.window.rootViewController;
    BOOL webviewOnTop = NO;
    if ([rvc isKindOfClass:[LEANRootViewController class]]) {
        webviewOnTop = [(LEANRootViewController*)rvc webviewOnTop];
    }
    
    if (application.applicationState == UIApplicationStateActive) {
        // App was in foreground.
        // Show an alert, and include a "view" button if there is a url and the webview is currently the top view.
        if (url && webviewOnTop) {
            self.alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"View", nil];
            self.url = url;
        } else {
            self.alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        }
        
        [self.alertView show];

        [self clearAllNotificationsForApplication:application];
    }
    else if (application.applicationState == UIApplicationStateBackground) {
        // schedule a local notification if the push notification was not handled by iOS
        BOOL handledByOS = userInfo[@"aps"][@"alert"] ? YES : NO;
        if (!handledByOS) {
            // delete all existing alerts with the same notificationId
            if (notificationId) [self clearNotificationWithId:notificationId];
            
            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
            localNotification.alertBody = message;
            localNotification.soundName = UILocalNotificationDefaultSoundName;
            NSMutableDictionary *localInfo = [NSMutableDictionary dictionary];
            if (urlString) localInfo[@"targetUrl"] = urlString;
            if (notificationId) localInfo[@"notificationId"] = notificationId;
            localNotification.userInfo = localInfo;
            [application presentLocalNotificationNow:localNotification];
            
            // save it so it can be cleared later
            if (notificationId) [self saveLocalNotification:localNotification];
        }
    }
    else if (application.applicationState == UIApplicationStateInactive && url && webviewOnTop) {
        // app was in background and user tapped on notification
        if (url && webviewOnTop) {
            [(LEANRootViewController*)rvc loadUrl:url];
        }
        
        if (appConfig.parsePushEnabled) {
            [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
        }

        [self clearAllNotificationsForApplication:application];
    }
    
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)clearAllNotificationsForApplication:(UIApplication *)application
{
    application.applicationIconBadgeNumber = 1;
    // setting badge number to 0 clears all notifications
    application.applicationIconBadgeNumber = 0;
    [application cancelAllLocalNotifications];

    [[NSFileManager defaultManager] removeItemAtPath:[self notificationFile] error:nil];
}

- (NSString*)notificationFile
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *library = [paths objectAtIndex:0];
    NSString *notificationFile = [library stringByAppendingPathComponent:LOCAL_NOTIFICATION_FILE];
    return notificationFile;
}

// We need to save local notifications that have ids to be able to cancel them later
// iOS lets us cancel local notifications that have been fired, but not get a list of them.
- (void)saveLocalNotification:(UILocalNotification*)notification
{
    // only save notifications with a notificationId that can be used as a dictionary key
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) return;
    id notificationId = userInfo[@"notificationId"];
    if (![notificationId conformsToProtocol:@protocol(NSCopying)]) return;
    
    // read from disk
    NSString *notificationFile = [self notificationFile];
    NSMutableDictionary *savedNotifications = [NSKeyedUnarchiver unarchiveObjectWithFile:notificationFile];
    if (!savedNotifications) savedNotifications = [NSMutableDictionary dictionaryWithObject:notification forKey:notificationId];
    else [savedNotifications setObject:notification forKey:notificationId];
    
    // write to disk
    [NSKeyedArchiver archiveRootObject:savedNotifications toFile:notificationFile];
}

- (void)clearNotificationWithId:(id)notificationId
{
    if (![notificationId conformsToProtocol:@protocol(NSCopying)]) return;
    
    // read from disk
    NSMutableDictionary *savedNotifications = [NSKeyedUnarchiver unarchiveObjectWithFile:[self notificationFile]];
    if (!savedNotifications) return;
    
    UILocalNotification *notification = savedNotifications[notificationId];
    if (notification) {
        [[UIApplication sharedApplication] cancelLocalNotification:notification];
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) return;
    
    NSString *urlString = userInfo[@"targetUrl"];
    if (!urlString) return;
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    UIViewController *rvc = self.window.rootViewController;
    BOOL webviewOnTop = NO;
    if ([rvc isKindOfClass:[LEANRootViewController class]]) {
        webviewOnTop = [(LEANRootViewController*)rvc webviewOnTop];
    }
    
    if (application.applicationState == UIApplicationStateInactive && url && webviewOnTop) {
        // app was in background and user tapped on notification
        [(LEANRootViewController*)rvc loadUrl:url];
    }
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
    if ([LEANSimulator openURL:url]) {
        return YES;
    }
    
    // Facebook SDK
    if ([GoNativeAppConfig sharedAppConfig].facebookEnabled) {
        return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                              openURL:url
                                                    sourceApplication:sourceApplication
                                                           annotation:annotation];
    }
    return NO;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if ([GoNativeAppConfig sharedAppConfig].isSimulator) {
        [LEANSimulator checkSimulatorSetting];
    }
    
    if ([GoNativeAppConfig sharedAppConfig].facebookEnabled) {
        [FBSDKAppEvents activateApp];
    }
}

- (void)application:(UIApplication *)application didChangeStatusBarOrientation:(UIInterfaceOrientation)oldStatusBarOrientation
{
    [LEANSimulator didChangeStatusBarOrientation];
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application
  supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    GoNativeScreenOrientation orientation = [GoNativeAppConfig sharedAppConfig].forceScreenOrientation;
    if (orientation == GoNativeScreenOrientationPortrait) {
        return UIInterfaceOrientationMaskPortrait;
    }
    else if (orientation == GoNativeScreenOrientationLandscape) {
        return UIInterfaceOrientationMaskLandscape;
    }
    else return UIInterfaceOrientationMaskAllButUpsideDown;
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
    [self clearBadge];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler
{
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        UIViewController *rvc = self.window.rootViewController;
        if ([rvc isKindOfClass:[LEANRootViewController class]]) {
            LEANRootViewController *vc = (LEANRootViewController*)rvc;
            [vc loadUrl:userActivity.webpageURL];
            return YES;
        }
    }
    
    return NO;
}
@end
