//
//  LEANJsCustomCodeExecutor.h
//  GonativeIO
//
//  Created by BSC Dev on 07.06.21.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CustomCodeHandler
- (NSDictionary*)execute:(NSDictionary*)params;
@end

@interface LEANJsCustomCodeExecutor : NSObject
+ (NSDictionary*)execute:(NSDictionary*)params;
+ (void)setHandler:(NSObject<CustomCodeHandler>*)customHandler;
@end

NS_ASSUME_NONNULL_END
