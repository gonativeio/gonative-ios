//
//  GNFileWriterSharer.h
//  GonativeIO
//
//  Created by Weiyin He on 11/16/19.
//  Copyright © 2019 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "LEANWebViewController.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * GNFileWriterSharerName = @"fileWriterSharer";
static NSUInteger GNFileWriterSharerMaxSize = 1024 * 1024 * 1024; // 1 gigabyte


@interface GNFileWriterSharer : NSObject <WKScriptMessageHandler>
@property (weak) UIView *webView;
@property (weak) LEANWebViewController *wvc;
- (void)downloadBlobUrl:(NSURL *)url filename:(NSString *_Nullable)filename;
@end

NS_ASSUME_NONNULL_END
