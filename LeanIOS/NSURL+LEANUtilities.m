//
//  NSURL+LEANUtilities.m
//  LeanIOS
//
//  Created by Weiyin He on 3/15/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "NSURL+LEANUtilities.h"

@implementation NSURL (LEANUtilities)

// compare two URLs to see if they match. Agnostic to query strings and paths that start with "//".
// Also agnostic to "www." in hostname.
- (BOOL)matchesPathOf:(NSURL*)url2
{
    NSString *path1 = [self path];
    NSString *path2 = [url2 path];
    if ([path1 hasPrefix:@"//"]) {
        path1 = [path1 stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
    }
    if ([path2 hasPrefix:@"//"]){
        path2 = [path2 stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
    }
    
    NSString *host1 = [self host];
    NSString *host2 = [url2 host];
    if ([host1 hasPrefix:@"www."])
        host1 = [host1 stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:@""];
    if ([host2 hasPrefix:@"www."])
        host2 = [host2 stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:@""];

    return [host1 isEqualToString:host2] && [path1 isEqualToString:path2];
}

- (BOOL)matchesIgnoreAnchor:(NSURL*)url2
{
    // consider it a match if both fields are null
    if (self.scheme || url2.scheme) {
        if (![self.scheme isEqualToString:url2.scheme]) return NO;
    }
    if (self.host || url2.host) {
        if (![self.host isEqualToString:url2.host]) return NO;
    }
    if (self.path || url2.path) {
        if (![self.path isEqualToString:url2.path]) return NO;
    }
    if (self.query || url2.query) {
        if (![self.query isEqualToString:url2.query]) return NO;
    }
    
    return YES;
}

@end
