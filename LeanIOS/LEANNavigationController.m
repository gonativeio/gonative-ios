//
//  LEANNavigationController.m
//  GoNativeIOS
//
//  Created by Weiyin He on 2/8/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANNavigationController.h"
#import "LEANWebViewController.h"
#import "LEANRootViewController.h"

@interface LEANNavigationController () <UINavigationControllerDelegate>
@end

@implementation LEANNavigationController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];

    // recognize swipe from left edge
    if (appConfig.showNavigationMenu) {
        self.sidebarEnabled = YES;
        UIScreenEdgePanGestureRecognizer *r = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
        if ([UIView userInterfaceLayoutDirectionForSemanticContentAttribute:self.view.semanticContentAttribute] == UIUserInterfaceLayoutDirectionRightToLeft) {
            r.edges = UIRectEdgeRight;
        } else {
            r.edges = UIRectEdgeLeft;
        }
        [self.view addGestureRecognizer:r];
    } else {
        self.sidebarEnabled = NO;
    }
    
    self.delegate = self;
}

-(void)viewDidLayoutSubviews
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    
    // theme and colors
    if ([appConfig.iosTheme isEqualToString:@"dark"]) {
        self.navigationBar.barStyle = UIBarStyleBlack;
        self.view.backgroundColor = [UIColor blackColor];
    } else {
        self.navigationBar.barStyle = UIBarStyleDefault;
        
        if (@available(iOS 12.0, *)) {
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                self.view.backgroundColor = [UIColor blackColor];
            } else {
                self.view.backgroundColor = [UIColor whiteColor];
            }
        } else {
            self.view.backgroundColor = [UIColor whiteColor];
        }
    }

    UIColor *titleColor = [UIColor colorNamed:@"titleColor"];
    UIColor *navBarTintColor = [UIColor colorNamed:@"navigationBarTintColor"];
    NSDictionary *titleTextAttributes = @{NSForegroundColorAttributeName: titleColor};
    self.navigationBar.titleTextAttributes = titleTextAttributes;
    self.navigationBar.barTintColor = navBarTintColor;
    
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        [appearance setBackgroundColor:navBarTintColor];
        [appearance setTitleTextAttributes:titleTextAttributes];
        [self.navigationBar setStandardAppearance:appearance];
        [self.navigationBar setScrollEdgeAppearance:appearance];
    }
    
    [super viewDidLayoutSubviews];
}

- (UIViewController *)childViewControllerForStatusBarStyle {
    return self.visibleViewController;
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
