//
//  LEANRegexRulesManager.m
//  GonativeIO
//
//  Created by bld ai on 6/14/22.
//  Copyright © 2022 GoNative.io LLC. All rights reserved.
//

#import "LEANRegexRulesManager.h"
#import "GonativeIO-Swift.h"

#define LEAN_REGEX_RULES_MANAGER_REGEXES @"LEANRegexRulesManagerRegexes"
#define LEAN_REGEX_RULES_MANAGER_IS_INTERNAL @"LEANRegexRulesManagerIsInternal"

@interface LEANRegexRulesManager()
@property NSArray *regexes;
@property NSArray *isInternal;
@end

@implementation LEANRegexRulesManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initializeValues];
    }
    return self;
}

- (void)initializeValues {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *stringRegexes = [defaults valueForKey:LEAN_REGEX_RULES_MANAGER_REGEXES];
    NSArray *isInternal = [defaults valueForKey:LEAN_REGEX_RULES_MANAGER_IS_INTERNAL];
    
    if ([stringRegexes isKindOfClass:[NSArray class]] && [isInternal isKindOfClass:[NSArray class]]) {
        NSMutableArray *regexes = [NSMutableArray array];
        NSMutableArray *validIsInternal = [NSMutableArray array];
        
        for (NSUInteger i = 0; i < [stringRegexes count] && i < [isInternal count]; i++) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", stringRegexes[i]];
            NSNumber *internal = isInternal[i];
            if (predicate) {
                [regexes addObject:predicate];
                [validIsInternal addObject:internal];
            }
        }
        
        self.regexes = regexes;
        self.isInternal = validIsInternal;
    } else {
        self.regexes = [NSArray arrayWithArray:[GoNativeAppConfig sharedAppConfig].regexInternalExternal];
        self.isInternal = [NSArray arrayWithArray:[GoNativeAppConfig sharedAppConfig].regexIsInternal];
    }
}

- (void)handleUrl:(NSURL *)url query:(NSDictionary*)query {
    if ([@"/set" isEqualToString:url.path]) {
        [self setRules:query[@"rules"]];
    }
}

- (void)setRules:(NSArray *)rules {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (rules == nil) {
        self.regexes = [NSArray arrayWithArray:[GoNativeAppConfig sharedAppConfig].regexInternalExternal];
        self.isInternal = [NSArray arrayWithArray:[GoNativeAppConfig sharedAppConfig].regexIsInternal];
        
        [defaults removeObjectForKey:LEAN_REGEX_RULES_MANAGER_REGEXES];
        [defaults removeObjectForKey:LEAN_REGEX_RULES_MANAGER_IS_INTERNAL];
        [defaults synchronize];
        return;
    }
    
    if (![rules isKindOfClass:[NSArray class]]) return;
    
    NSMutableArray *stringRegexes = [NSMutableArray array];
    NSMutableArray *regexes = [NSMutableArray array];
    NSMutableArray *isInternal = [NSMutableArray array];
    
    for (id entry in rules) {
        if ([entry isKindOfClass:[NSDictionary class]] && entry[@"regex"] && entry[@"internal"]) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", entry[@"regex"]];
            NSNumber *internal = entry[@"internal"];
            if (predicate) {
                [stringRegexes addObject:entry[@"regex"]];
                [regexes addObject:predicate];
                [isInternal addObject:internal];
            }
        }
    }
    
    self.regexes = regexes;
    self.isInternal = isInternal;
    
    [defaults setValue:stringRegexes forKey:LEAN_REGEX_RULES_MANAGER_REGEXES];
    [defaults setValue:isInternal forKey:LEAN_REGEX_RULES_MANAGER_IS_INTERNAL];
    [defaults synchronize];
}

- (NSDictionary *)matchesWithUrlString:(NSString *)urlString {
    for (NSUInteger i = 0; i < [self.regexes count] && i < [self.isInternal count]; i++) {
        NSPredicate *predicate = self.regexes[i];
        
        if (![predicate isKindOfClass:[NSPredicate class]]) continue;
        
        @try {
            if ([predicate evaluateWithObject:urlString]) {
                BOOL isInternal = [self.isInternal[i] boolValue];
                return @{ @"matches": @YES, @"isInternal": @(isInternal) };
            }
        }
        @catch (NSException* exception) {
            NSLog(@"Error in regex internal external: %@", exception);
        }
    }
    return @{ @"matches": @NO };
}

@end
