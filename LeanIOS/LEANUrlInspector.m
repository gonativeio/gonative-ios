//
//  LEANUrlInspector.m
//  GoNativeIOS
//
//  Created by Weiyin He on 4/22/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANUrlInspector.h"

@interface LEANUrlInspector ()
@property NSRegularExpression *userIdRegex;
@end

@implementation LEANUrlInspector

+ (LEANUrlInspector *)sharedInspector
{
    static LEANUrlInspector *sharedInspector;
    
    @synchronized(self)
    {
        if (!sharedInspector){
            sharedInspector = [[LEANUrlInspector alloc] init];
            [sharedInspector setup];
        }
        
        return sharedInspector;
    }
}

- (void)setup
{
    self.userId = @"";
    if ([GoNativeAppConfig sharedAppConfig].userIdRegex) {
        self.userIdRegex = [NSRegularExpression regularExpressionWithPattern:[GoNativeAppConfig sharedAppConfig].userIdRegex options:0 error:nil];
    } else {
        self.userIdRegex = nil;
    }
}

- (void)inspectUrl:(NSURL *)url
{
    NSString *urlString = [url absoluteString];
    
    NSTextCheckingResult *result = [self.userIdRegex firstMatchInString:urlString options:0 range:NSMakeRange(0, [urlString length])];
    
    // first range is the entire regex. Second range is the (selection)
    if ([result numberOfRanges] >= 2) {
        self.userId = [urlString substringWithRange:[result rangeAtIndex:1]];
    }
}

@end
