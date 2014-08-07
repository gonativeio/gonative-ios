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

- (id)initWithJsonObject:(id)json;

- (id)initWithDictionary:(NSDictionary*)config title:(NSString*)title isLogin:(BOOL)isLogin;

@end
