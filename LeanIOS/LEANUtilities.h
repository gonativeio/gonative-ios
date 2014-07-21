//
//  LeanUtilities.h
//  GoNativeIOS
//
//  Created by Weiyin He on 2/4/14.
//  Copyright (c) 2014 Weiyin He. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANUtilities : NSObject
+ (NSDictionary*) dictionaryFromQueryString: (NSString*) string;
+(NSString*)urlEscapeString:(NSString *)unencodedString;
+(NSString*)urlQueryStringWithDictionary:(NSDictionary*) dictionary;
+(NSString*)addQueryStringToUrlString:(NSString *)urlString withDictionary:(NSDictionary *)dictionary;
+(BOOL)isValidEmail:(NSString*)email;
+(NSString *)stripHTML:(NSString*)x replaceWith:(NSString*) replacement;
+ (UIColor *)colorFromHexString:(NSString *)hexString;
+ (void)addJqueryToWebView:(UIWebView*)webView;
+(NSString*)jsWrapString:(NSString*)string;
+(NSString*)capitalizeWords:(NSString*)string;
+(NSString*)getLaunchImageName;
@end
