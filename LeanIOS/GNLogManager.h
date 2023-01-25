//
//  GNLogManager.h
//  GoNativeIOS
//
//  Created by bld on 11/29/22.
//  Copyright © 2022 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface GNLogManager : NSObject
- (instancetype)initWithWebview:(WKWebView *)webview enabled:(BOOL)enabled;
- (void)handleUrl:(NSURL *)url query:(NSDictionary *)query;

@end

NS_ASSUME_NONNULL_END
