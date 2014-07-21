//
//  LEANWebFormController.h
//  LeanIOS
//
//  Created by Weiyin He on 3/1/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LEANWebFormController : UITableViewController
@property (nonatomic, weak) UIViewController *originatingViewController;

- (id)initWithJsonResource:(NSString*)jsonRes formUrl:(NSURL*)formUrl errorUrl:(NSURL*)errorUrl title:(NSString*) title isLogin:(BOOL)isLogin;

- (id)initWithJsonObject:(id)json;


@end
