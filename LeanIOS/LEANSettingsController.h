//
//  LEANSettingsController.h
//  GoNativeIOS
//
//  Created by Weiyin He on 5/13/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LEANProfilePicker.h"
#import "LEANWebViewController.h"

@interface LEANSettingsController : UITableViewController
@property LEANProfilePicker *profilePicker;
@property LEANWebViewController *wvc;
@property (weak) UIPopoverController *popover;
@end
