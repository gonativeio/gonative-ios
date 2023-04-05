//
//  GNBackgroundAudio.h
//  GonativeIO
//
//  Created by Weiyin He on 12/30/19.
//  Copyright © 2019 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GNBackgroundAudio : NSObject
- (void)handleUrl:(NSURL *)url query:(NSDictionary*)query;
- (void)start;
- (void)end;
@end

NS_ASSUME_NONNULL_END
