//
//  GNJSBridgeInterface.h
//  GoNativeIOS
//
//  Created by Anuj Sevak on 2021-11-10.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

#import <WebKit/WebKit.h>
#import "LEANWebViewController.h"
#import "LEANRootViewController.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * GNJSBridgeName = @"JSBridge";

@interface GNJSBridgeInterface : NSObject <WKScriptMessageHandler>
@end

NS_ASSUME_NONNULL_END
