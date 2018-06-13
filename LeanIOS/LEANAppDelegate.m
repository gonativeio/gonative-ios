//
//  LEANAppDelegate.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <OneSignal/OneSignal.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import "LEANAppDelegate.h"
#import "GoNativeAppConfig.h"
#import "LEANWebViewIntercept.h"
#import "LEANUrlCache.h"
#import "LEANRootViewController.h"
#import "LEANConfigUpdater.h"
#import "LEANUtilities.h"
#import "GNRegistrationManager.h"
#import "GNConfigPreferences.h"
#import "GonativeIO-Swift.h"

@interface LEANAppDelegate() <OSSubscriptionObserver>
@end

@implementation LEANAppDelegate

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
    if (appConfig.configError) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *message = @"Invalid appConfig json";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            LEANRootViewController *rvc = (LEANRootViewController*) self.window.rootViewController;
            [rvc presentAlert:alert];
        });
    }
    
    // Register launch
    [LEANConfigUpdater registerEvent:@"launch" data:nil];
    
    // proxy handler to intercept HTML for custom CSS and viewport
    [LEANWebViewIntercept register];
    
    // OneSignal
    if (appConfig.oneSignalEnabled) {
        [OneSignal setRequiresUserPrivacyConsent:appConfig.oneSignalRequiresUserPrivacyConsent];
        [OneSignal initWithLaunchOptions:launchOptions appId:appConfig.oneSignalAppId handleNotificationReceived:^(OSNotification *notification) {

            OSNotificationPayload *payload = notification.payload;
            NSString *message = [payload.body copy];
            NSString *title = notification.payload.title;
            
            NSString *urlString;
            NSURL *url;
            if (payload.additionalData) {
                urlString = payload.additionalData[@"u"];
                if (![urlString isKindOfClass:[NSString class]]) {
                    urlString = payload.additionalData[@"targetUrl"];
                }
                if ([urlString isKindOfClass:[NSString class]]) {
                    url = [LEANUtilities urlWithString:urlString];
                }
            }
            
            BOOL webviewOnTop = NO;
            LEANRootViewController *rvc = (LEANRootViewController*) self.window.rootViewController;
            if (![rvc isKindOfClass:[LEANRootViewController class]]) {
                rvc = nil;
            } else {
                webviewOnTop = [rvc webviewOnTop];
            }
            
            if (notification.isAppInFocus && ![@"none" isEqualToString:appConfig.oneSignalInFocusDisplay]) {
                // Show an alert, and include a "view" button if there is a url and the webview is currently the top view.
                
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                if (url && webviewOnTop) {
                    [alert addAction:[UIAlertAction actionWithTitle:@"View" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [rvc loadUrl:url];
                    }]];
                }
                
                [rvc presentAlert:alert];
            }
        } handleNotificationAction:^(OSNotificationOpenedResult *result) {
            OSNotificationPayload *payload = result.notification.payload;
            if (payload.additionalData) {
                [self handlePushNotificationData:payload.additionalData];
            }
            
        } settings:@{kOSSettingsKeyAutoPrompt: @false,
                     kOSSettingsKeyInFocusDisplayOption: [NSNumber numberWithInteger:OSNotificationDisplayTypeNone]}];
        
        if (appConfig.oneSignalAutoRegister && ![OneSignal requiresUserPrivacyConsent]) {
            [OneSignal promptForPushNotificationsWithUserResponse:nil];
        }
    }
    
    // registration service
    GNRegistrationManager *registration = [GNRegistrationManager sharedManager];
    [registration processConfig:appConfig.registrationEndpoints];
    if (appConfig.oneSignalEnabled) {
        [OneSignal addSubscriptionObserver:self];
        OSPermissionSubscriptionState *state = [OneSignal getPermissionSubscriptionState];
        [registration setOneSignalUserId:state.subscriptionStatus.userId pushToken:state.subscriptionStatus.pushToken subscribed:state.subscriptionStatus.subscribed];
    }
    
    [self configureApplication];
    
    // listen for reachability
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    // Facebook SDK
    if (appConfig.facebookEnabled) {
        [[FBSDKApplicationDelegate sharedInstance] application:application
                                 didFinishLaunchingWithOptions:launchOptions];
        if (launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
            [FBSDKAppLinkUtility fetchDeferredAppLink:^(NSURL *url, NSError *error) {
                if (error) {
                    NSLog(@"Received error while fetching deferred app link %@", error);
                }
                if (url) {
                    [[UIApplication sharedApplication] openURL:url];
                }
            }];
        }
    }
    
    // disable sleep if requested
    if (appConfig.keepScreenOn) {
        application.idleTimerDisabled = YES;
    }
    
    return YES;
}

-(void)handlePushNotificationData:(NSDictionary*)data
{
    if (!data) return;
    
    NSString *urlString;
    NSURL *url;
    urlString = data[@"u"];
    if (![urlString isKindOfClass:[NSString class]]) {
        urlString = data[@"targetUrl"];
    }
    if ([urlString isKindOfClass:[NSString class]]) {
        url = [LEANUtilities urlWithString:urlString];
    }
    
    BOOL webviewOnTop = NO;
    UIViewController *rvc = self.window.rootViewController;
    if ([rvc isKindOfClass:[LEANRootViewController class]]) {
        webviewOnTop = [(LEANRootViewController*)rvc webviewOnTop];
    }
    
    if (url && webviewOnTop) {
        // for when the app is launched from scratch from a push notification
        [(LEANRootViewController*)rvc setInitialUrl:url];
        
        // for when the app was backgrounded
        [(LEANRootViewController*)rvc loadUrl:url];
    }
}

- (void)configureApplication
{
    UIColor *defaultTintColor = [UIColor colorWithRed:104.0/255 green:104.0/255 blue:112.0/255 alpha:1.0];
    self.window.tintColor = defaultTintColor;
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Error registering for push notifications: %@", err);
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
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
    if ([GoNativeAppConfig sharedAppConfig].facebookEnabled) {
        [FBSDKAppEvents activateApp];
    }
    
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
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application
  supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    if (![window.rootViewController isKindOfClass:[LEANRootViewController class]]) {
        // likely to be a full-screen video. Allow all orientations.
        return UIInterfaceOrientationMaskAllButUpsideDown;
    }

    // use appConfig.forceScreenOrientation
    GoNativeScreenOrientation orientation = [GoNativeAppConfig sharedAppConfig].forceScreenOrientation;
    if (orientation == GoNativeScreenOrientationPortrait) {
        return UIInterfaceOrientationMaskPortrait;
    }
    else if (orientation == GoNativeScreenOrientationLandscape) {
        return UIInterfaceOrientationMaskLandscape;
    }
    else {
        // default implementation, use what the Info.plist specifies
        return [application supportedInterfaceOrientationsForWindow:window];
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

#pragma mark OneSignalSubscriptionObserver
-(void)onOSSubscriptionChanged:(OSSubscriptionStateChanges *)stateChanges
{
    GNRegistrationManager *registration = [GNRegistrationManager sharedManager];
    OSSubscriptionState *state = stateChanges.to;
    [registration setOneSignalUserId:state.userId pushToken:state.pushToken subscribed:state.subscribed];
}

@end
