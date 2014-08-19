//
//  LEANWebViewPool.h
//  GoNativeIOS
//
//  Created by Weiyin He on 8/18/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANWebViewPool : NSObject

+ (LEANWebViewPool*)sharedPool;

- (UIWebView*)webviewForUrl:(NSURL*)url;


@end
