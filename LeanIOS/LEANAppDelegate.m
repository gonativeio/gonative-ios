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

@implementation LEANAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    // tint color from app config
    if ([[LEANAppConfig sharedAppConfig][@"checkCustomStyling"] boolValue]) {
        self.window.tintColor = [LEANAppConfig sharedAppConfig].tintColor;
    }
    
    // start cast controller
    if ([LEANAppConfig sharedAppConfig].enableChromecast) {
        self.castController = [[LEANCastController alloc] init];
        [self.castController performScan:YES];
    }
    
    // modify default user agent to include the suffix
    UIWebView* webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    NSString* originalAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    NSString* newAgent = [NSString stringWithFormat:@"%@ %@", originalAgent,
                          [LEANAppConfig sharedAppConfig][@"userAgentAdd"]];
    NSDictionary *dictionary = @{@"UserAgent": newAgent};
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    
    // proxy handler for custom CSS
    if ([LEANAppConfig sharedAppConfig][@"customCss"] || [LEANAppConfig sharedAppConfig][@"stringViewport"]) {
        [LEANWebViewIntercept initialize];
    }
    
    return YES;
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
