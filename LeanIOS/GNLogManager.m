//
//  GNLogManager.m
//  GonativeIO
//
//  Created by bld on 11/29/22.
//  Copyright © 2022 GoNative.io LLC. All rights reserved.
//

#import "GNLogManager.h"

@interface GNLogManager()
@property WKWebView *webview;
@end

@implementation GNLogManager

- (instancetype)initWithWebview:(WKWebView *)webview {
    self = [super init];
    if (self) {
        self.webview = webview;
    }
    return self;
}

- (void)enableLogging {
    NSString *js = @" "
    "var globalConsole = console; "
    "var console = { "
    "   log: function(data) { "
    "      gonative.weblogs.print({ data, type: 'console.log' }) "
    "   }, "
    "   error: function(data) { "
    "      gonative.weblogs.print({ data, type: 'console.error' }) "
    "   }, "
    "   warn: function(data) { "
    "      gonative.weblogs.print({ data, type: 'console.warn' }) "
    "   }, "
    "   debug: function(data) { "
    "      gonative.weblogs.print({ data, type: 'console.debug' }) "
    "   }, "
    "}; "
    " ";
    [self.webview evaluateJavaScript:js completionHandler:nil];
    NSLog(@"WebLogs enabled");
}

- (void)disableLogging {
    NSString *js = @" "
    "console = globalConsole; "
    " ";
    [self.webview evaluateJavaScript:js completionHandler:nil];
    NSLog(@"WebLogs disabled");
}

- (void)handleUrl:(NSURL *)url query:(NSDictionary *)query {
    if (![url.host isEqualToString:@"weblogs"]) {
        return;
    }
    
    if ([url.path isEqualToString:@"/enable"]) {
        [self enableLogging];
        return;
    }
    
    if ([url.path isEqualToString:@"/disable"]) {
        [self disableLogging];
        return;
    }
    
    if ([url.path isEqualToString:@"/print"]) {
        @try {
            NSLog(@"[%@] %@", query[@"type"], query[@"data"]);
        } @catch(id exception) {
            // Do nothing
        }
        return;
    }
}

@end
