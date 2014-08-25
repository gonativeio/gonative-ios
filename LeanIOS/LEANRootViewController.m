//
//  LEANRootViewController.m
//  GoNativeIOS
//
//  Created by Weiyin He on 2/7/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANRootViewController.h"
#import "LEANMenuViewController.h"
#import "LEANAppConfig.h"
#import "LEANWebViewController.h"

@interface LEANRootViewController ()

@end

@implementation LEANRootViewController

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    if (self = [super initWithNibName:nibName bundle:nibBundle]) {
        
    }
    return self;
}

- (void)awakeFromNib
{
    if ([[LEANAppConfig sharedAppConfig].iosTheme isEqualToString:@"dark"]) {
        self.liveBlurBackgroundStyle = REFrostedViewControllerLiveBackgroundStyleDark;
        self.blurTintColor = [UIColor colorWithWhite:0 alpha:0.75f];
    } else {
        self.liveBlurBackgroundStyle = REFrostedViewControllerLiveBackgroundStyleLight;
        self.blurTintColor = nil;
    }
    
    self.animationDuration = [[LEANAppConfig sharedAppConfig].menuAnimationDuration floatValue];
    self.limitMenuViewSize = YES;
    self.menuViewSize = CGSizeMake(270, NAN);
    
    self.contentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"contentController"];
    [self.contentViewController view];
    
    self.menuViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"menuController"];
    
    self.webViewController = ((UINavigationController*)self.contentViewController).viewControllers[0];

    
    // pre-load the menu view
    [self.menuViewController view];
}

- (void)loadUrl:(NSURL *)url
{
    UINavigationController *nav = (UINavigationController*)self.contentViewController;
    UIViewController *topController = nav.topViewController;
    if ([topController isKindOfClass:[LEANWebViewController class]]) {
        [((LEANWebViewController*)topController) loadUrl:url];
    }
}

- (void)setInitialUrl:(NSURL *)url
{
    // designed to be called from push notification
    UINavigationController *nav = (UINavigationController*)self.contentViewController;
    for (UIViewController *vc in nav.viewControllers) {
        if ([vc isKindOfClass:[LEANWebViewController class]]) {
            ((LEANWebViewController*)vc).initialUrl = url;
            break;
        }
    }
}

- (BOOL)webviewOnTop
{
    return [((UINavigationController*)self.contentViewController).topViewController isKindOfClass:[LEANWebViewController class]];
}



@end
