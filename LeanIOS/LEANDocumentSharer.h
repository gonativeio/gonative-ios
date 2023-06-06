//
//  LEANDocumentSharer.h
//  GoNativeIOS
//
//  Created by Weiyin He on 8/26/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANDocumentSharer : NSObject
+ (LEANDocumentSharer*)sharedSharer;
- (void)downloadImage:(NSURL*)url;
- (BOOL)isSharableRequest:(NSURLRequest*)req;
- (void)shareRequest:(NSURLRequest *)req fromButton:(UIBarButtonItem*) button;
- (void)shareUrl:(NSURL*)url fromView:(UIView*)view;
- (void)shareUrl:(NSURL*)url fromView:(UIView*)view filename:(NSString*)filename;
- (void)receivedRequest:(NSURLRequest*)request;
- (void)receivedResponse:(NSURLResponse*)response;
- (void)receivedWebviewResponse:(NSURLResponse*)response;
- (void)receivedData:(NSData*)data;
- (void)cancel;
- (void)finish;
@end
