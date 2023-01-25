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

- (instancetype)initWithWebview:(WKWebView *)webview enabled:(BOOL)enabled {
    self = [super init];
    if (self) {
        self.webview = webview;
        
        if (enabled) {
            [self enableLogging];
        }
    }
    return self;
}

- (void)enableLogging {
    NSString *js = @" "
    "var globalConsole = console; "
    "var console = { "
    "   log: function(data) { "
    "      gonative.webconsolelogs.print({ data, type: 'console.log' }) "
    "   }, "
    "   error: function(data) { "
    "      gonative.webconsolelogs.print({ data, type: 'console.error' }) "
    "   }, "
    "   warn: function(data) { "
    "      gonative.webconsolelogs.print({ data, type: 'console.warn' }) "
    "   }, "
    "   debug: function(data) { "
    "      gonative.webconsolelogs.print({ data, type: 'console.debug' }) "
    "   }, "
    "}; "
    " ";
    [self.webview evaluateJavaScript:js completionHandler:nil];
    NSLog(@"Web console logs enabled");
}

- (void)handleUrl:(NSURL *)url query:(NSDictionary *)query {
    if (![url.host isEqualToString:@"webconsolelogs"] || ![url.path isEqualToString:@"/print"]) {
        return;
    }
    
    @try {
        NSLog(@"[%@] %@", query[@"type"], query[@"data"]);
    } @catch(id exception) {
        // Do nothing
    }
}

@end
