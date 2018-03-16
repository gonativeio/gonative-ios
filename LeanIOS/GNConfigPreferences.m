//
//  GNConfigPreferences.m
//  GonativeIO
//
//  Created by Weiyin He on 3/16/18.
//  Copyright © 2018 GoNative.io LLC. All rights reserved.
//

#import "GNConfigPreferences.h"

#define kInitialUrlKey @"io.gonative.ios.initialUrl"

@implementation GNConfigPreferences
+(instancetype)sharedPreferences
{
    static GNConfigPreferences *sharedPreferences;
    @synchronized(self)
    {
        if (!sharedPreferences){
            sharedPreferences = [[GNConfigPreferences alloc] init];
        }
        return sharedPreferences;
    }
}

-(BOOL)handleUrl:(NSURL *)url
{
    if (![@"gonative" isEqualToString:url.scheme] || ![@"config" isEqualToString:url.host]) {
        return NO;
    }
    
    if ([@"/set" isEqualToString:url.path]) {
        NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        for (NSURLQueryItem *item in urlComponents.queryItems) {
            if ([item.name isEqualToString:@"initialUrl"]) {
                [self setInitialUrl:item.value];
            }
        }
    }
    
    return YES;
}

-(void)setInitialUrl:(NSString*)url
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (url && url.length > 0) {
        [defaults setObject:url forKey:kInitialUrlKey];
    } else {
        [defaults removeObjectForKey:kInitialUrlKey];
    }
    [defaults synchronize];
}

-(NSString*)getInitialUrl
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kInitialUrlKey];
}
@end
