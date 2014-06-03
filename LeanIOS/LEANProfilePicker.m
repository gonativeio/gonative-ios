//
//  LEANProfilePicker.m
//  GoNativeIOS
//
//  Created by Weiyin He on 5/14/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANProfilePicker.h"

@interface LEANProfilePicker ()

@property id json;

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
    [self.names removeAllObjects];
    [self.links removeAllObjects];
    
    self.json = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    
    
    for (int i = 0; i < [self.json count]; i++) {
        id profile = self.json[i];
        
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
