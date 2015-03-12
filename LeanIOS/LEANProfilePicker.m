//
//  LEANProfilePicker.m
//  GoNativeIOS
//
//  Created by Weiyin He on 5/14/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANProfilePicker.h"

@interface LEANProfilePicker ()
@end

@implementation LEANProfilePicker

- (id) init
{
    self = [super init];
    if (self) {
        self.names = [[NSMutableArray alloc] init];
        self.links = [[NSMutableArray alloc] init];
        self.selectedIndex = -1;
    }
    
    return self;
}

- (void)parseJson:(NSString*)json;
{
    id parsed = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if (![parsed isKindOfClass:[NSArray class]]) {
        // don't do anything if not array
        return;
    }
    
    [self.names removeAllObjects];
    [self.links removeAllObjects];
    
    for (int i = 0; i < [parsed count]; i++) {
        id profile = parsed[i];
        if (![profile isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        [self.names addObject:profile[@"name"]];
        [self.links addObject:profile[@"link"]];
        if ([profile[@"selected"] boolValue]) {
            self.selectedIndex = i;
        }
    }

}

- (BOOL)hasProfiles
{
    return [self.names count] > 0;
}

@end
