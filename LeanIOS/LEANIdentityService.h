//
//  LEANIdentityService.h
//  GoNativeIOS
//
//  Created by Weiyin He on 9/7/15.
//  Copyright © 2015 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANIdentityService : NSObject
// singleton
+(LEANIdentityService*)sharedService;
- (void)checkUrl:(NSURL*)url;
@end
