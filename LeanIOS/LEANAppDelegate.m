//
//  LEANAppDelegate.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <OneSignal/OneSignal.h>
#import "LEANAppDelegate.h"
#import "LEANWebViewIntercept.h"
#import "LEANUrlCache.h"
#import "LEANRootViewController.h"
#import "LEANConfigUpdater.h"
#import "LEANUtilities.h"
#import "GNRegistrationManager.h"
#import "GNConfigPreferences.h"
#import "GonativeIO-Swift.h"
#import <AppTrackingTransparency/ATTrackingManager.h>

@interface LEANAppDelegate() <OSSubscriptionObserver>
@end

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
    
    // OneSignal
    if (appConfig.oneSignalEnabled) {
        
        // init OneSignal
        [OneSignal setRequiresUserPrivacyConsent:appConfig.oneSignalRequiresUserPrivacyConsent];
        [OneSignal initWithLaunchOptions:launchOptions];
        [OneSignal setAppId:appConfig.oneSignalAppId];
        
        // set notification displayed in foreground handler
        id notifWillShowInForegroundHandler = ^(OSNotification *notification, OSNotificationDisplayResponse completion) {
            NSString *message = [notification.body copy];
            NSString *title = notification.title;
            NSString *urlString;
            NSURL *url;
            if (notification.additionalData) {
                urlString = notification.additionalData[@"u"];
                if (![urlString isKindOfClass:[NSString class]]) {
                    urlString = notification.additionalData[@"targetUrl"];
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
            
            if (![@"none" isEqualToString:appConfig.oneSignalInFocusDisplay] &&
                (title || message || url)) {
                // Show an alert, and include a "view" button if there is a url and the webview is currently the top view.
                
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"button-ok", @"Button: OK") style:UIAlertActionStyleCancel handler:nil]];
                if (url && webviewOnTop) {
                    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"button-view", @"Button: View") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [rvc loadUrl:url];
                    }]];
                }
                
                [rvc presentAlert:alert];
            }
            completion(notification);
        };
        [OneSignal setNotificationWillShowInForegroundHandler:notifWillShowInForegroundHandler];
        
        // set notification opened handler
        id notificationOpenedBlock = ^(OSNotificationOpenedResult *result) {
          OSNotification* notification = result.notification;
          if (notification.additionalData) {
              [self handlePushNotificationData:notification.additionalData];
          }
        };
        [OneSignal setNotificationOpenedHandler:notificationOpenedBlock];
        
        // check autoregister
        if (appConfig.oneSignalAutoRegister && ![OneSignal requiresUserPrivacyConsent]){
            if(appConfig.oneSignalIosSoftPrompt){
                OSDeviceState *deviceState = [OneSignal getDeviceState];
                // if device not subscribed, trigger the soft prompt
                if (!deviceState.isSubscribed) [OneSignal addTrigger:@"prompt_ios" withValue:@"true"];
            } else [OneSignal promptForPushNotificationsWithUserResponse:nil];
        }
    }
    
    // registration service
    GNRegistrationManager *registration = [GNRegistrationManager sharedManager];
    [registration processConfig:appConfig.registrationEndpoints];
    if (appConfig.oneSignalEnabled) {
        [OneSignal addSubscriptionObserver:self];
        OSDeviceState *state = [OneSignal getDeviceState];
        [registration setOneSignalUserId:state.userId pushToken:state.pushToken subscribed:state.isSubscribed];
    }
    
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
    self.window.tintColor = [UIColor colorNamed:@"tintColor"];
}

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"Successfully registered for push notifications");
    [self setApnsToken:[deviceToken base64EncodedStringWithOptions:0]];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Error registering for push notifications: %@", err);
    [self setApnsToken:nil];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
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
    
    [bridge application:app openURL:url options:options];
    
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
    [bridge applicationWillResignActive:application];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [bridge applicationDidEnterBackground:application];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [bridge applicationWillEnterForeground:application];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [bridge applicationWillTerminate:application];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
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
    [registration setOneSignalUserId:state.userId pushToken:state.pushToken subscribed:state.isSubscribed];
}

#pragma mark -

-(BOOL)hasTrackingDescription {
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSUserTrackingUsageDescription"] isKindOfClass:[NSString class]];
}

@end
