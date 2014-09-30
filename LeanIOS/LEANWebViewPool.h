//
//  LEANWebViewPool.h
//  GoNativeIOS
//
//  Created by Weiyin He on 8/18/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LEANWebViewPoolDisownPolicy) {
    LEANWebViewPoolDisownPolicyAlways,
    LEANWebViewPoolDisownPolicyReload,
    LEANWebViewPoolDisownPolicyNever
};

static LEANWebViewPoolDisownPolicy kLEANWebViewPoolDisownPolicyDefault = LEANWebViewPoolDisownPolicyReload;

@interface LEANWebViewPool : NSObject
@property NSURLRequest *currentLoadingRequest;

+ (LEANWebViewPool*)sharedPool;

- (void)setup;
- (UIView*)webviewForUrl:(NSURL *)url policy:(LEANWebViewPoolDisownPolicy*)policy;
- (void)disownWebview:(UIView*)webview;
- (void)flushAll;

@end
