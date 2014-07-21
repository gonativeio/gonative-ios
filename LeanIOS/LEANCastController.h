//
//  LEANCastController.h
//  LeanIOS
//
//  Created by Weiyin He on 2/20/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEANCastController : NSObject

@property UIBarButtonItem *castButton;
@property NSURL *urlToPlay;
@property NSString *titleToPlay;

- (void)performScan:(BOOL)start;

@end
