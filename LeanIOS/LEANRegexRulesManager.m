//
//  LEANRegexRulesManager.m
//  GonativeIO
//
//  Created by bld ai on 6/14/22.
//  Copyright © 2022 GoNative.io LLC. All rights reserved.
//

#import "LEANRegexRulesManager.h"
#import "GonativeIO-Swift.h"

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
    NSArray *regexArray;
    NSArray *isInternalArray;
    [[GoNativeAppConfig sharedAppConfig] initializeRegexRules:&regexArray isInternalArray:&isInternalArray];
    self.regexes = regexArray;
    self.isInternal = isInternalArray;
}

- (void)handleUrl:(NSURL *)url query:(NSDictionary*)query {
    if ([@"/set" isEqualToString:url.path]) {
        [self setRules:query[@"rules"]];
    }
}

- (void)setRules:(NSArray *)rules {
    if (rules != nil && ![rules isKindOfClass:[NSArray class]]) return;
    NSArray *regexArray;
    NSArray *isInternalArray;
    [[GoNativeAppConfig sharedAppConfig] setRegexRules:rules regexArray:&regexArray isInternalArray:&isInternalArray];
    self.regexes = regexArray;
    self.isInternal = isInternalArray;
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
