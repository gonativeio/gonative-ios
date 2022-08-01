//
//  LeanUtilities.h
//  GoNativeIOS
//
//  Created by Weiyin He on 2/4/14.
//  Copyright (c) 2014 Weiyin He. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface LEANUtilities : NSObject
+ (NSDictionary*) dictionaryFromQueryString: (NSString*) string;
+(NSString*)urlEscapeString:(NSString *)unencodedString;
+(NSString*)urlQueryStringWithDictionary:(NSDictionary*) dictionary;
+(NSString*)addQueryStringToUrlString:(NSString *)urlString withDictionary:(NSDictionary *)dictionary;
+(NSDictionary*)parseQueryParamsWithUrl:(NSURL*)url;
+(NSURL*)urlWithString:(NSString*)string;
+(NSString*)utiFromMimetype:(NSString*)mimeType;
+(BOOL)isValidEmail:(NSString*)email;
+(NSString *)stripHTML:(NSString*)x replaceWith:(NSString*) replacement;
+ (UIColor *)colorFromHexString:(NSString *)hexString;
+(UIColor*)colorWithAlphaFromHexString:(NSString*)hexString;
+ (void)overrideGeolocation:(UIView*)webview;
+ (void)matchStatusBarToBodyBackgroundColor:(WKWebView *)webview enabled:(BOOL)enabled;
+(NSString*)jsWrapString:(NSString*)string;
+(NSString*)capitalizeWords:(NSString*)string;
+(NSString*)getLaunchImageName;
+(void)configureWebView:(UIView*)webview;
+ (WKProcessPool *)wkProcessPool;
+(NSArray<NSPredicate*>*)createRegexArrayFromStrings:(id)input;
+(BOOL)string:(NSString*)string matchesAnyRegex:(NSArray<NSPredicate*>*)regexes;
+(NSString*)createJsForPostTo:(NSString*)url data:(NSDictionary*)data;
+(NSString*)createJsForCallback:(NSString*)functionName data:(NSDictionary*)data;
+(BOOL)checkNativeBridgeUrl:(NSString*)url;
+(BOOL)cookie:(NSHTTPCookie*)cookie matchesUrl:(NSURL*)url;
@end
