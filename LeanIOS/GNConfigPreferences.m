//
//  GNConfigPreferences.m
//  GonativeIO
//
//  Created by Weiyin He on 3/16/18.
//  Copyright © 2018 GoNative.io LLC. All rights reserved.
//

#import "GNConfigPreferences.h"
#import "LEANAppDelegate.h"

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

- (void)handleUrl:(NSURL *)url query:(NSDictionary*)query
{
    if ([@"/set" isEqualToString:url.path]) {
        [self setInitialUrl:query[@"initialUrl"]];
    }
}

-(void)setInitialUrl:(NSString*)url
{
    url = [self processUrl:url];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (url && url.length > 0) {
        [defaults setObject:url forKey:kInitialUrlKey];
    } else {
        [defaults removeObjectForKey:kInitialUrlKey];
    }
    [defaults synchronize];
    
    // set in app delegate so that page does not get reloaded
    LEANAppDelegate *appDelegate = (LEANAppDelegate*)[UIApplication sharedApplication].delegate;
    appDelegate.previousInitialUrl = url;
}

-(NSString*)getInitialUrl
{
    NSString *url = [[NSUserDefaults standardUserDefaults] objectForKey:kInitialUrlKey];
    return [self processUrl:url];
}

-(NSString*)processUrl:(NSString*)url
{
    if (!url || url.length == 0) return nil;
    
    // if protocol is not specified, add http://
    if ([url rangeOfString:@"://"].location == NSNotFound) {
        url = [NSString stringWithFormat:@"http://%@", url];
    }
    
    return url;
}
@end
