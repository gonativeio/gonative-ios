//
//  GNCustomHeaders.m
//  GoNativeIOS
//
//  Created by Weiyin He on 5/1/17.
//  Copyright © 2017 GoNative.io LLC. All rights reserved.
//

#import "GNCustomHeaders.h"

static NSString * kOurRequestProperty = @"io.gonative.ios.GNCustomHeaders";

@interface GNCustomHeaders()
@property NSArray<WKBackForwardListItem *> *backHistory;
@property NSArray<WKBackForwardListItem *> *forwardHistory;
@end

@implementation GNCustomHeaders
+(NSDictionary*)getCustomHeaders
{
    NSDictionary *config = [GoNativeAppConfig sharedAppConfig].customHeaders;
    if (!config) {
        return nil;
    }
    
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:config.count];
    
    for (id key in config) {
        if ([key isKindOfClass:[NSString class]] && [key length] > 0) {
            id val = [self interpolateValues:config[key]];
            if (val) {
                result[key] = val;
            }
        }
    }
    
    return result;
}

+(NSString*)interpolateValues:(NSString*)value
{
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    if ([value containsString:@"%DEVICEID%"]) {
        NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        value = [value stringByReplacingOccurrencesOfString:@"%DEVICEID%" withString:deviceId];
    }
    
    if ([value containsString:@"%DEVICENAME64%"]) {
        NSString *deviceName = [[UIDevice currentDevice] name];
        NSData *data = [deviceName dataUsingEncoding:NSUTF8StringEncoding];
        NSString *deviceName64 = [data base64EncodedStringWithOptions:0];
        value = [value stringByReplacingOccurrencesOfString:@"%DEVICENAME64%" withString:deviceName64];
    }
    
    return value;
}

-(NSURLRequest*)modifyRequest:(NSURLRequest*)request
{
    NSMutableURLRequest *modifiedRequest = [request mutableCopy];
    
    NSDictionary *headers = [GNCustomHeaders getCustomHeaders];
    for (NSString *key in headers) {
        [modifiedRequest setValue:headers[key] forHTTPHeaderField:key];
    }
    
    return modifiedRequest;
}

-(BOOL)shouldModifyRequest:(NSURLRequest *)request webview:(WKWebView *)webview
{
    BOOL goingBack = [self isBackNavigationRequest:request webview:webview];
    BOOL goingForward = [self isForwardNavigationRequest:request webview:webview];
    
    if (goingBack || goingForward) {
        return NO;
    }
    
    if (request.HTTPMethod && ![request.HTTPMethod isEqualToString:@"GET"]) {
        return NO;
    }
    
    NSDictionary *headers = [GNCustomHeaders getCustomHeaders];
    if (!headers || headers.count == 0) {
        return NO;
    }
    
    for (NSString *key in headers) {
        if (![request valueForHTTPHeaderField:key]) {
            return YES;
        }
    }
    
    return NO;
}

-(BOOL)isBackNavigationRequest:(NSURLRequest *)request webview:(WKWebView *)webview
{
    NSArray<WKBackForwardListItem *> *newBackHistory = [webview backForwardList].backList;
    NSArray<WKBackForwardListItem *> *prevBackHistory = self.backHistory;
    
    self.backHistory = newBackHistory;
    
    NSString *lastItemUrl = [prevBackHistory lastObject].URL.absoluteString;
    return newBackHistory.count < prevBackHistory.count && [lastItemUrl isEqualToString:request.URL.absoluteString];
}

-(BOOL)isForwardNavigationRequest:(NSURLRequest *)request webview:(WKWebView *)webview
{
    NSArray<WKBackForwardListItem *> *newForwardHistory = [webview backForwardList].forwardList;
    NSArray<WKBackForwardListItem *> *prevForwardHistory = self.forwardHistory;
    
    self.forwardHistory = newForwardHistory;
    
    NSString *lastItemUrl = [prevForwardHistory lastObject].URL.absoluteString;
    return newForwardHistory.count < prevForwardHistory.count && [lastItemUrl isEqualToString:request.URL.absoluteString];
}

@end
