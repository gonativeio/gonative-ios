//
//  GNJSBridgeInterface.h
//  GoNativeIOS
//
//  Created by Anuj Sevak on 2021-11-10.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

#import <WebKit/WebKit.h>
#import "LEANWebViewController.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * GNJSBridgeName = @"JSBridge";

@interface GNJSBridgeInterface : NSObject <WKScriptMessageHandler>
@property (weak) LEANWebViewController *wvc;
@end

NS_ASSUME_NONNULL_END
