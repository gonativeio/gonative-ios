//
//  LEANUrlCache.h
//  GoNativeIOS
//
//  Created by Weiyin He on 6/4/14.
//  Copyright (c) 2014 The Lean App. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANUrlCache : NSObject
- (BOOL)hasCacheForRequest:(NSURLRequest*)request;
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request;
@end
