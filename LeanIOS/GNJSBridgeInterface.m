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
        return [rvc webViewController];
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
