//
//  LEANAppConfig.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANAppConfig.h"
#import "LEANUtilities.h"
#import <CommonCrypto/CommonCrypto.h>

@interface LEANAppConfig ()
@property id json;
@end

@implementation LEANAppConfig

+ (LEANAppConfig *)sharedAppConfig
{
    static LEANAppConfig *sharedAppConfig;
    
    @synchronized(self)
    {
        if (!sharedAppConfig){
            sharedAppConfig = [[LEANAppConfig alloc] init];
            
            // read json
            NSError *jsonError;
            NSString *path = [[NSBundle mainBundle] pathForResource:@"appConfig" ofType:@"json"];
            NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:path];
            [inputStream open];
            sharedAppConfig.json = [NSJSONSerialization JSONObjectWithStream:inputStream options:0 error:&jsonError];
            if (jsonError) NSLog(@"Error parsing json: %@", jsonError);
            [inputStream close];
            
            sharedAppConfig.tintColor = [LEANUtilities colorFromHexString:sharedAppConfig[@"iosTintColor"]];
            
            sharedAppConfig.titleTextColor = [LEANUtilities colorFromHexString:sharedAppConfig[@"iosTitleColor"]];
            sharedAppConfig.initialURL = [NSURL URLWithString:sharedAppConfig[@"initialURL"]];
            sharedAppConfig.initialHost = [sharedAppConfig.initialURL host];
            if ([sharedAppConfig.initialHost hasPrefix:@"www."]) {
                sharedAppConfig.initialHost = [sharedAppConfig.initialHost stringByReplacingCharactersInRange:NSMakeRange(0, [@"www." length]) withString:@""];
            }
            sharedAppConfig.loginDetectionURL = [NSURL URLWithString:sharedAppConfig[@"loginDetectionURL"]];
            sharedAppConfig.loginDetectionURLnotloggedin = [NSURL URLWithString:sharedAppConfig[@"loginDetectionURLnotloggedin"]];
            sharedAppConfig.loginURL = [NSURL URLWithString:sharedAppConfig[@"loginURL"]];
            sharedAppConfig.loginURLfail = [NSURL URLWithString:sharedAppConfig[@"loginURLfail"]];
            sharedAppConfig.forgotPasswordURL = [NSURL URLWithString:sharedAppConfig[@"forgotPasswordURL"]];
            sharedAppConfig.forgotPasswordURLfail = [NSURL URLWithString:sharedAppConfig[@"forgotPasswordURLfail"]];
            sharedAppConfig.signupURL = [NSURL URLWithString:sharedAppConfig[@"signupURL"]];
            sharedAppConfig.signupURLfail = [NSURL URLWithString:sharedAppConfig[@"signupURLfail"]];
            sharedAppConfig.loginIsFirstPage = [sharedAppConfig[@"loginIsFirstPage"] boolValue];
            sharedAppConfig.showShareButton = [sharedAppConfig[@"showShareButton"] boolValue];
            sharedAppConfig.enableChromecast = [sharedAppConfig[@"enableChromecast"] boolValue];
            
            if (sharedAppConfig[@"forceLandscapeRegex"]) {
                sharedAppConfig.forceLandscapeMatch = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sharedAppConfig[@"forceLandscapeRegex"]];
            }
            
            if (sharedAppConfig[@"allowZoom"]) {
                sharedAppConfig.allowZoom = [sharedAppConfig[@"allowZoom"] boolValue];
            }
            else
                sharedAppConfig.allowZoom = YES;
            
            

            
            if ([sharedAppConfig hasKey:@"redirects"]) {
                NSUInteger len = [sharedAppConfig[@"redirects"] count];
                sharedAppConfig.redirects = [[NSMutableDictionary alloc] initWithCapacity:len];
                for (id redirect in sharedAppConfig[@"redirects"]) {
                    [sharedAppConfig.redirects setValue:redirect[@"to"] forKey:redirect[@"from"]];
                }
            }
            
            if ([sharedAppConfig hasKey:@"showToolbar"])
                sharedAppConfig.showToolbar = [sharedAppConfig[@"showToolbar"] boolValue];
            else sharedAppConfig.showToolbar = YES;
            
            if ([sharedAppConfig hasKey:@"showNavigationBar"])
                sharedAppConfig.showNavigationBar = [sharedAppConfig[@"showNavigationBar"] boolValue];
            else sharedAppConfig.showNavigationBar = YES;
            
            if ([sharedAppConfig hasKey:@"pushNotifications"])
                sharedAppConfig.pushNotifications = [sharedAppConfig[@"pushNotifications"] boolValue];
            else sharedAppConfig.pushNotifications = NO;
            
            if ([sharedAppConfig hasKey:@"navStructure"]) {
                id urlLevels = sharedAppConfig[@"navStructure"][@"urlLevels"];
                sharedAppConfig.navStructureLevels = [[NSMutableArray alloc] initWithCapacity:[urlLevels count]];
                
                for (id entry in urlLevels) {
                    if ([entry isKindOfClass:[NSDictionary class]] && entry[@"regex"] && entry[@"level"]) {
                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                        NSNumber *level = entry[@"level"];
                        
                        [sharedAppConfig.navStructureLevels addObject:@{@"predicate": predicate, @"level": level}];
                    }
                }
                
                id titles = sharedAppConfig[@"navStructure"][@"titles"];
                sharedAppConfig.navTitles = [[NSMutableArray alloc] initWithCapacity:[titles count]];
                
                for (id entry in titles) {
                    if ([entry isKindOfClass:[NSDictionary class]] && entry[@"regex"]) {
                        NSMutableDictionary *toAdd = [[NSMutableDictionary alloc] init];
                        
                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                        [toAdd setObject:predicate forKey:@"predicate"];
                        
                        
                        if (entry[@"title"]) {
                            [toAdd setObject:entry[@"title"] forKey:@"title"];
                        }
                        
                        if (entry[@"urlRegex"]) {
                            [toAdd setObject:[NSRegularExpression regularExpressionWithPattern:entry[@"urlRegex"] options:0 error:nil] forKey:@"urlRegex"];
                        }
                        
                        if (entry[@"urlChompWords"]) {
                            [toAdd setObject:entry[@"urlChompWords"] forKey:@"urlChompWords"];
                        }
                        
                        [sharedAppConfig.navTitles addObject:toAdd];
                    }
                }
            }
            
            if ([sharedAppConfig hasKey:@"interactiveDelay"]) {
                sharedAppConfig.interactiveDelay = sharedAppConfig[@"interactiveDelay"];
            }
            
            if ([sharedAppConfig hasKey:@"interceptForms"]) {
                sharedAppConfig.interceptForms = sharedAppConfig[@"interceptForms"];
            }
            
            if ([sharedAppConfig hasKey:@"regexInternalExternal"]) {
                id temp = sharedAppConfig[@"regexInternalExternal"];
                
                NSUInteger num = [temp count];
                sharedAppConfig.regexInternalEternal = [[NSMutableArray alloc] initWithCapacity:num];
                sharedAppConfig.regexIsInternal = [[NSMutableArray alloc] initWithCapacity:num];
                for (id entry in temp) {
                    if ([entry isKindOfClass:[NSDictionary class]] && entry[@"regex"] && entry[@"internal"]) {
                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                        NSNumber *internal = entry[@"internal"];
                        if (predicate) {
                            [sharedAppConfig.regexInternalEternal addObject:predicate];
                            [sharedAppConfig.regexIsInternal addObject:internal];
                        }
                    }

                }
            }
            
            if ([sharedAppConfig hasKey:@"loginLaunchBackground"]) {
                sharedAppConfig.loginLaunchBackground = [sharedAppConfig[@"loginLaunchBackground"] boolValue];
            } else sharedAppConfig.loginLaunchBackground = NO;
            
            if ([sharedAppConfig hasKey:@"loginIconImage"]) {
                sharedAppConfig.loginIconImage = [sharedAppConfig[@"loginIconImage"] boolValue];
            } else sharedAppConfig.loginIconImage = YES;
            
            // json menus
            id menus = sharedAppConfig.json[@"menus"];
            if ([menus isKindOfClass:[NSDictionary class]]) {
                sharedAppConfig.menus = [NSMutableDictionary dictionary];
                for (id key in menus) {
                    if ([menus[key][@"items"] isKindOfClass:[NSArray class]]) {
                        [sharedAppConfig.menus setObject:menus[key][@"items"] forKey:key];
                    }
                }
            }
            
            // json login detection
            id loginDetect = sharedAppConfig.json[@"loginDetection"];
            if ([loginDetect isKindOfClass:[NSDictionary class]]) {
                id url = loginDetect[@"url"];
                if ([url isKindOfClass:[NSString class]]) {
                    sharedAppConfig.loginDetectionURL = [NSURL URLWithString:url];
                }
                
                id redirectLocations = loginDetect[@"redirectLocations"];
                if ([redirectLocations isKindOfClass:[NSArray class]]) {
                    sharedAppConfig.loginDetectRegexes = [NSMutableArray array];
                    sharedAppConfig.loginDetectLocations = [NSMutableArray array];
                    for (id entry in redirectLocations) {
                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
                        if (predicate) {
                            [sharedAppConfig.loginDetectRegexes addObject:predicate];
                            [sharedAppConfig.loginDetectLocations addObject:entry];
                        }
                    }
                }
            }
        }
        
        return sharedAppConfig;
    }
}

- (BOOL)hasKey:(id)key
{
    return self.json[key] && self.json[key] != [NSNull null];
}

- (id)objectForKey:(id)aKey;
{
    id ret = self.json[aKey];
    if (ret == [NSNull null]) {
        return nil;
    }
    return ret;
}

- (id)objectForKeyedSubscript:(id)key
{
    return [self objectForKey:key];
}

@end
