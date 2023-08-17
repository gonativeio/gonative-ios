//
//  LEANLaunchScreenManager.h
//  Median
//
//  Created by bld on 8/11/23.
//  Copyright © 2023 Median. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANLaunchScreenManager : NSObject
+ (LEANLaunchScreenManager *)sharedManager;
- (void)show;
- (void)hide;
- (void)hideAfterDelay:(double)delay;
@end
