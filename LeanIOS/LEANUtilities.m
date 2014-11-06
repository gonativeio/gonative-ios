//
//  LEANUtilities.m
//  GoNativeIOS
//
//  Created by Weiyin He on 2/4/14.
//  Copyright (c) 2014 Weiyin He. All rights reserved.
//

#import "LEANUtilities.h"
#import "LEANAppConfig.h"

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
    NSString *emailRegex = @"\\S+@\\S+\\.\\S+";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:email];
}

+(NSString *)stripHTML:(NSString*)x replaceWith:(NSString*) replacement {
    if (![x isKindOfClass:[NSString class]]) {
        return nil;
    }
    
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
    if (![hexString isKindOfClass:[NSString class]] || ![hexString hasPrefix:@"#"]) {
        return nil;
    }
    
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

// injects jquery into webviews using packaged jquery file
+ (void)addJqueryToWebView:(UIView*)wv {
    NSString *jqueryTest = @"window.jQuery.fn.jquery";
    
    if ([wv isKindOfClass:[UIWebView class]]) {
        UIWebView *webView = (UIWebView*)wv;
        NSString *loaded = [webView stringByEvaluatingJavaScriptFromString:jqueryTest];
        if (!loaded || [loaded length] == 0) {
            NSURL *jquery = [[NSBundle mainBundle] URLForResource:@"jquery-2.1.0.min" withExtension:@"js"];
            NSString *contents = [NSString stringWithContentsOfURL:jquery encoding:NSUTF8StringEncoding error:nil];
            [webView stringByEvaluatingJavaScriptFromString:contents];
            [webView stringByEvaluatingJavaScriptFromString:@"jQuery.noConflict()"];
        }

    } else if ([wv isKindOfClass:NSClassFromString(@"WKWebView")]) {
        WKWebView *webview = (WKWebView*)wv;
        [webview evaluateJavaScript:jqueryTest completionHandler:^(id result, NSError *error) {
            if (![result isKindOfClass:[NSString class]] || [result length] == 0) {
                NSURL *jquery = [[NSBundle mainBundle] URLForResource:@"jquery-2.1.0.min" withExtension:@"js"];
                NSString *contents = [NSString stringWithContentsOfURL:jquery encoding:NSUTF8StringEncoding error:nil];
                [webview evaluateJavaScript:contents completionHandler:^(id result2, NSError *error2) {
                    [webview evaluateJavaScript:@"jQuery.noConflict()" completionHandler:nil];
                }];
            }
        }];
    }
}

+(NSString*)jsWrapString:(NSString*)string
{
    return [NSString stringWithFormat:@"decodeURIComponent(\"%@\")", [string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

+(NSString*)capitalizeWords:(NSString *)string
{
    NSMutableString *result = [string mutableCopy];
    [result enumerateSubstringsInRange:NSMakeRange(0, [result length])
                               options:NSStringEnumerationByWords
                            usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                [result replaceCharactersInRange:NSMakeRange(substringRange.location, 1)
                                                      withString:[[substring substringToIndex:1] uppercaseString]];
                            }];
    
    return result;
}


+(NSString*)getLaunchImageName
{
    
    NSArray* images= @[@"LaunchImage.png", @"LaunchImage@2x.png",@"LaunchImage-700@2x.png",@"LaunchImage-568h@2x.png",@"LaunchImage-700-568h@2x.png",@"LaunchImage-700-Portrait@2x~ipad.png",@"LaunchImage-Portrait@2x~ipad.png",@"LaunchImage-700-Portrait~ipad.png",@"LaunchImage-Portrait~ipad.png",@"LaunchImage-Landscape@2x~ipad.png",@"LaunchImage-700-Landscape@2x~ipad.png",@"LaunchImage-Landscape~ipad.png",@"LaunchImage-700-Landscape~ipad.png"];
    
    UIImage *splashImage;
    
    if ([self isDeviceiPhone])
    {
        if ([self isDeviceiPhone4] && [self isDeviceRetina])
        {
            splashImage = [UIImage imageNamed:images[1]];
            if (splashImage.size.width!=0)
                return images[1];
            else
                return images[2];
        }
        else if ([self isDeviceiPhone5])
        {
            splashImage = [UIImage imageNamed:images[1]];
            if (splashImage.size.width!=0)
                return images[3];
            else
                return images[4];
        }
        else if ([self isDeviceiPhone6])
        {
            return @"LaunchImage-800-667h@2x.png";
        }
        else if ([self isDeviceiPhone6Plus])
        {
            if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
                return @"LaunchImage-800-Portrait-736h@3x.png";
            } else {
                return @"LaunchImage-800-Landscape-736h@3x.png";
            }
        }
        else
            return images[0]; //Non-retina iPhone
    }
    else if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation))//iPad Portrait
    {
        if ([self isDeviceRetina])
        {
            splashImage = [UIImage imageNamed:images[5]];
            if (splashImage.size.width!=0)
                return images[5];
            else
                return images[6];
        }
        else
        {
            splashImage = [UIImage imageNamed:images[7]];
            if (splashImage.size.width!=0)
                return images[7];
            else
                return images[8];
        }
        
    }
    else
    {
        if ([self isDeviceRetina])
        {
            splashImage = [UIImage imageNamed:images[9]];
            if (splashImage.size.width!=0)
                return images[9];
            else
                return images[10];
        }
        else
        {
            splashImage = [UIImage imageNamed:images[11]];
            if (splashImage.size.width!=0)
                return images[11];
            else
                return images[12];
        }
    }
}



+(BOOL)isDeviceiPhone
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
    {
        return TRUE;
    }
    
    return FALSE;
}

+(BOOL)isDeviceiPhone4
{
    if ([[UIScreen mainScreen] bounds].size.height==480)
        return TRUE;
    
    return FALSE;
}


+(BOOL)isDeviceRetina
{
    if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
        ([UIScreen mainScreen].scale == 2.0))        // Retina display
    {
        return TRUE;
    }
    else                                          // non-Retina display
    {
        return FALSE;
    }
}


+(BOOL)isDeviceiPhone5
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && size.width == 320 && size.height == 568;
}

+(BOOL)isDeviceiPhone6
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && size.width == 375 && size.height == 667;
}

+(BOOL)isDeviceiPhone6Plus
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
    ((size.width == 414 && size.height == 736) ||
     (size.width == 736 && size.height == 414));
}

+(void)configureWebView:(UIView*)wv
{
    wv.frame = [[UIScreen mainScreen] bounds];
    if ([[LEANAppConfig sharedAppConfig].iosTheme isEqualToString:@"dark"]) {
        wv.backgroundColor = [UIColor blackColor];
    } else {
        wv.backgroundColor = [UIColor whiteColor];
    }
    wv.opaque = YES;
    
    // we are using autolayout, so disable autoresizingmask stuff
    [wv setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    // disable double-tap that causes page to shift
    [self removeDoubleTapFromView:wv];
    
    if ([wv isKindOfClass:[UIWebView class]]) {
        UIWebView *webview = (UIWebView*)wv;
        webview.scalesPageToFit = YES;
        webview.scrollView.bounces = NO;
    } else if([wv isKindOfClass:NSClassFromString(@"WKWebView")]) {
        WKWebView *webview = (WKWebView*)wv;
        webview.scrollView.bounces = NO;
        
        // user script for customCSS
        NSString *customCss = [LEANAppConfig sharedAppConfig].customCss;
        if ([customCss length] > 0) {
            NSString *scriptSource = [NSString stringWithFormat:@"var gonative_styleElement = document.createElement('style'); document.documentElement.appendChild(gonative_styleElement); gonative_styleElement.textContent = %@;", [LEANUtilities jsWrapString:customCss]];
            
            WKUserScript *userScript = [[NSClassFromString(@"WKUserScript") alloc] initWithSource:scriptSource injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
            [webview.configuration.userContentController addUserScript:userScript];
        }
        
        // user script for viewport
        {
            NSString *stringViewport = [LEANAppConfig sharedAppConfig].stringViewport;
            NSNumber *viewportWidth = [LEANAppConfig sharedAppConfig].forceViewportWidth;
            
            if (viewportWidth) {
                stringViewport = [NSString stringWithFormat:@"width=%@,user-scalable=no", viewportWidth];
            }
            
            if (!stringViewport) {
                stringViewport = @"";
            }
            
            NSString *scriptSource = [NSString stringWithFormat:@"var gonative_setViewport = %@; var gonative_viewportElement = document.querySelector('meta[name=viewport]'); if (gonative_viewportElement) {   if (gonative_setViewport) {         gonative_viewportElement.content = gonative_setViewport;     } else {         gonative_viewportElement.content = gonative_viewportElement.content + ',user-scalable=no';     } } else if (gonative_setViewport) {     gonative_viewportElement = document.createElement('meta');     gonative_viewportElement.name = 'viewport';     gonative_viewportElement.content = gonative_setViewport; document.head.appendChild(gonative_viewportElement);}", [LEANUtilities jsWrapString:stringViewport]];
            
            WKUserScript *userScript = [[NSClassFromString(@"WKUserScript") alloc] initWithSource:scriptSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
            [webview.configuration.userContentController addUserScript:userScript];
        }
    }
}

+(void)removeDoubleTapFromView:(UIView *)view {
    for (UIView *v in view.subviews) {
        if (v != view) [self removeDoubleTapFromView:v];
    }
    
    for (UIGestureRecognizer *gestureRecognizer in view.gestureRecognizers) {
        if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tapRecognizer = (UITapGestureRecognizer*)gestureRecognizer;
            if (tapRecognizer.numberOfTouchesRequired == 1 && tapRecognizer.numberOfTapsRequired == 2)
            {
                [view removeGestureRecognizer:gestureRecognizer];
            }
        }
    }
}

+ (WKProcessPool *)wkProcessPool
{
    static WKProcessPool *processPool;
    
    @synchronized(self)
    {
        if (!processPool){
            processPool = [[NSClassFromString(@"WKProcessPool") alloc] init];
        }
        
        return processPool;
    }
}

@end
