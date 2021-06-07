//
//  LEANJsCustomCodeExecutor.m
//  GonativeIO
//
//  Created by BSC Dev on 07.06.21.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

#import "LEANJsCustomCodeExecutor.h"

static NSObject<CustomCodeHandler>* _handler = nil;

// The default CustomVCodeHandler "Echo"
// Simply returns the given NSDictionary
@interface EchoHandler : NSObject<CustomCodeHandler>
@end

@implementation EchoHandler
- (NSDictionary*)execute:(NSDictionary*)params {
    return params;
}
@end


@implementation LEANJsCustomCodeExecutor

/**
 * Sets new CustomCodeHandler to override the default EchoHandler
 * @param customHandler The new Code Handler
 */
+ (void)setHandler:(NSObject<CustomCodeHandler>*)customHandler {
    if(customHandler == nil)
        return;
    _handler = customHandler;
}

/**
 * Code Handler gets triggered by the LEANWebViewController class
 * *
 * @param params An NSDictionary consisting of all URI parameters and their values
 * @return An NSDictionary as defined by the Code Handler
 */
+ (NSDictionary*)execute:(NSDictionary*)params {
    if(_handler == nil) {
        _handler = [[EchoHandler alloc]init];
    }
    
    @try {
        return [_handler execute:params];
    } @catch(NSException *exception) {
        NSLog(@"%@ %@", @"Error executing custom code", exception.reason);
    } @finally {
    }
    
    return nil;
}

@end
