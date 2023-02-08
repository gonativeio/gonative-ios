//
//  GNJSBridgeInterface.m
//  GonativeIO
//
//  Created by Anuj Sevak on 2021-11-10.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

#import "GNJSBridgeInterface.h"
#import <Foundation/Foundation.h>

@implementation GNJSBridgeInterface : NSObject

- (LEANWebViewController *)webViewController
{
    // Get current webview controller
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    if ([topController isKindOfClass:[LEANRootViewController class]]) {
        LEANRootViewController *rvc = (LEANRootViewController *)topController;
        
        // Get top most WebViewController
        LEANWebViewController *wvc;
        NSArray<UIViewController *> *viewControllers = rvc.webViewController.navigationController.viewControllers;
        for (int i = 0; i < viewControllers.count; i++) {
            if ([viewControllers[i] isKindOfClass:[LEANWebViewController class]]) {
                wvc = (LEANWebViewController *)viewControllers[i];
            }
        }
        return wvc;
    }
    return nil;
}

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
    LEANWebViewController *wvc = [self webViewController];
    if (![wvc isKindOfClass:[LEANWebViewController class]]) return;
    
    if([message.body isKindOfClass:[NSDictionary class]]){
        [wvc handleJSBridgeFunctions:(NSDictionary*)message.body];
    } else if ([message.body isKindOfClass:[NSString class]]){
        NSURL *url = [NSURL URLWithString:(NSString*) message.body];
        if(!url) return;
        [wvc handleJSBridgeFunctions:url];
    }
}

@end
