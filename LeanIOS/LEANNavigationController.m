//
//  LEANNavigationController.m
//  GoNativeIOS
//
//  Created by Weiyin He on 2/8/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANNavigationController.h"
#import "LEANWebViewController.h"
#import "LEANAppConfig.h"

@interface LEANNavigationController () <UINavigationControllerDelegate>

@end

@implementation LEANNavigationController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    LEANAppConfig *appConfig = [LEANAppConfig sharedAppConfig];
    
    // theme
    if ([appConfig.iosTheme isEqualToString:@"dark"]) {
        self.navigationBar.barStyle = UIBarStyleBlack;
    } else {
        self.navigationBar.barStyle = UIBarStyleDefault;
    }
    
    // set title text color
    if (appConfig.titleTextColor) {
        self.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [LEANAppConfig sharedAppConfig].titleTextColor};
    }

    // recognize swipe from left edge
    if (appConfig.showNavigationMenu) {
        UIScreenEdgePanGestureRecognizer *r = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
        r.edges = UIRectEdgeLeft;
        [self.view addGestureRecognizer:r];
    }
    
    self.delegate = self;
}

#pragma mark - UINavigationControllerDelegate
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if ([viewController isKindOfClass:[LEANWebViewController class]] && [LEANAppConfig sharedAppConfig].showToolbar) {
        [navigationController setToolbarHidden:NO animated:YES];
    }
    else {
        [navigationController setToolbarHidden:YES animated:YES];
    }
    
    
}

#pragma mark - Gesture recognizer

- (void)panGestureRecognized:(UIScreenEdgePanGestureRecognizer *)sender
{
    [self.frostedViewController panGestureRecognized:sender];
}


@end
