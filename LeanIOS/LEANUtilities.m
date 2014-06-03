//
//  LEANUtilities.m
//  GoNativeIOS
//
//  Created by Weiyin He on 2/4/14.
//  Copyright (c) 2014 Weiyin He. All rights reserved.
//

#import "LEANUtilities.h"

@implementation LEANUtilities

+ (NSDictionary*) dictionaryFromQueryString: (NSString*) string
{
    NSMutableDictionary *dictParameters = [[NSMutableDictionary alloc] init];
    NSArray *arrParameters = [string componentsSeparatedByString:@"&"];
    for (int i = 0; i < [arrParameters count]; i++) {
        NSArray *arrKeyValue = [arrParameters[i] componentsSeparatedByString:@"="];
        if ([arrKeyValue count] >= 2) {
            NSMutableString *strKey = [NSMutableString stringWithCapacity:0];
            [strKey setString:[[arrKeyValue[0] lowercaseString] stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
            NSMutableString *strValue   = [NSMutableString stringWithCapacity:0];
            [strValue setString:[[arrKeyValue[1]  stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
            if (strKey.length > 0) dictParameters[strKey] = strValue;
        }
    }
    
    return dictParameters;
}

+(NSString*)urlEscapeString:(NSString *)unencodedString
{
    CFStringRef originalStringRef = (__bridge_retained CFStringRef)unencodedString;
    NSString *s = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,originalStringRef, NULL, NULL,kCFStringEncodingUTF8);
    CFRelease(originalStringRef);
    return s;
}

+(NSString*)urlQueryStringWithDictionary:(NSDictionary*) dictionary{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    BOOL first = YES;
    for (id key in dictionary){
        NSString *keyString = [key description];
        NSString *valueString = [dictionary[key] description];
        
        if (first) {
            [result appendFormat:@"%@=%@", [self urlEscapeString:keyString], [self urlEscapeString:valueString]];
            first = NO;
        }
        else {
            [result appendFormat:@"&%@=%@", [self urlEscapeString:keyString], [self urlEscapeString:valueString]];
        }
    }
    
    return result;
}


+(NSString*)addQueryStringToUrlString:(NSString *)urlString withDictionary:(NSDictionary *)dictionary
{
    NSMutableString *urlWithQuerystring = [[NSMutableString alloc] initWithString:urlString];
    
    for (id key in dictionary) {
        NSString *keyString = [key description];
        NSString *valueString = [dictionary[key] description];
        
        if ([urlWithQuerystring rangeOfString:@"?"].location == NSNotFound) {
            [urlWithQuerystring appendFormat:@"?%@=%@", [self urlEscapeString:keyString], [self urlEscapeString:valueString]];
        } else {
            [urlWithQuerystring appendFormat:@"&%@=%@", [self urlEscapeString:keyString], [self urlEscapeString:valueString]];
        }
    }
    return urlWithQuerystring;
}

+(BOOL)isValidEmail:(NSString*)email
{
    BOOL stricterFilter = NO; // Discussion http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/
    NSString *stricterFilterString = @"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}";
    NSString *laxString = @".+@([A-Za-z0-9]+\\.)+[A-Za-z]{2}[A-Za-z]*";
    NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:email];
}

+(NSString *)stripHTML:(NSString*)x replaceWith:(NSString*) replacement {
    if (replacement == nil) {
        replacement = @"";
    }
    
    NSRange r;
    NSString *s = [NSString stringWithString:x];
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:replacement];
    return s;
}

// Assumes input like "#00FF00" (#RRGGBB).
+ (UIColor *)colorFromHexString:(NSString *)hexString {
    if (!hexString || ![hexString hasPrefix:@"#"]) {
        return nil;
    }
    
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

// injects jquery into webviews using packaged jquery file
+ (void)addJqueryToWebView:(UIWebView*)webView {
    if (![webView stringByEvaluatingJavaScriptFromString:@"window.jQuery"]) {
        NSURL *jquery = [[NSBundle mainBundle] URLForResource:@"jquery-2.1.0.min" withExtension:@"js"];
        NSString *js = [NSString stringWithFormat:
                        @"var gonativejs = document.createElement(\"script\");"
                        "gonativejs.type = \"text/javascript\";"
                        "gonativejs.src = decodeURIComponent(\"%@\");"
                        "document.body.appendChild(gonativejs);",
                        [[jquery absoluteString] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        [webView stringByEvaluatingJavaScriptFromString:js];
    }
}

+(NSString*)jsWrapString:(NSString*)string
{
    return [NSString stringWithFormat:@"decodeURIComponent(\"%@\")", [string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

@end
