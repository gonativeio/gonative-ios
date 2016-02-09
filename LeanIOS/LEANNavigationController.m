//
//  LEANNavigationController.m
//  GoNativeIOS
//
//  Created by Weiyin He on 2/8/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANNavigationController.h"
#import "LEANWebViewController.h"
#import "GoNativeAppConfig.h"

@interface LEANNavigationController () <UINavigationControllerDelegate>
@end

@implementation LEANNavigationController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    
    // theme
    if ([appConfig.iosTheme isEqualToString:@"dark"]) {
        self.navigationBar.barStyle = UIBarStyleBlack;
    } else {
        self.navigationBar.barStyle = UIBarStyleDefault;
    }
    
    // set title text color
    if (appConfig.titleTextColor) {
        self.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [GoNativeAppConfig sharedAppConfig].titleTextColor};
    }

    // recognize swipe from left edge
    if (appConfig.showNavigationMenu) {
        self.sidebarEnabled = YES;
        UIScreenEdgePanGestureRecognizer *r = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
        r.edges = UIRectEdgeLeft;
        [self.view addGestureRecognizer:r];
    } else {
        self.sidebarEnabled = NO;
    }
    
    self.delegate = self;
}

#pragma mark - UINavigationControllerDelegate
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if ([viewController isKindOfClass:[LEANWebViewController class]] && [GoNativeAppConfig sharedAppConfig].showToolbar) {
        [navigationController setToolbarHidden:NO animated:YES];
    }
    else {
        [navigationController setToolbarHidden:YES animated:YES];
    }
    
    
}

#pragma mark - Gesture recognizer

- (void)panGestureRecognized:(UIScreenEdgePanGestureRecognizer *)sender
{
    if (self.sidebarEnabled) {
        [self.frostedViewController panGestureRecognized:sender];
    }
}


@end
