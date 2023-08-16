//
//  LEANLaunchScreenManager.m
//  Median
//
//  Created by bld on 8/11/23.
//  Copyright © 2023 Median. All rights reserved.
//

#import "LEANLaunchScreenManager.h"

@interface LEANLaunchScreenManager()
@property UIImageView *launchScreen;
@end

@implementation LEANLaunchScreenManager

+ (LEANLaunchScreenManager *)sharedManager {
    static LEANLaunchScreenManager *shared;
    @synchronized(self) {
        if (!shared) {
            shared = [[LEANLaunchScreenManager alloc] init];
        }
        return shared;
    }
}

- (void)show {
    self.launchScreen = [[UIImageView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.launchScreen.image = [UIImage imageNamed:@"LaunchBackground"];
    self.launchScreen.clipsToBounds = YES;
    
    UIImageView *centerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 200, 400)];
    centerImageView.image = [UIImage imageNamed:@"LaunchCenter"];
    centerImageView.contentMode = UIViewContentModeScaleAspectFit;
    centerImageView.center = CGPointMake(self.launchScreen.bounds.size.width / 2, self.launchScreen.bounds.size.height / 2);
    [self.launchScreen addSubview:centerImageView];
    
    UIWindow *currentWindow = [UIApplication sharedApplication].windows.lastObject;
    [currentWindow addSubview:self.launchScreen];
}

- (void)hide {
    if (self.launchScreen) {
        [self.launchScreen removeFromSuperview];
        self.launchScreen = nil;
    }
}

@end
