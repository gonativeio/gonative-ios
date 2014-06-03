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
#import "LEANWebFormController.h"

@interface LEANRootViewController ()
@property UIInterfaceOrientationMask forcedOrientations;
@end

@implementation LEANRootViewController

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    if (self = [super initWithNibName:nibName bundle:nibBundle]) {
        self.forcedOrientations = UIInterfaceOrientationMaskAllButUpsideDown;
    }
    return self;
}

- (void)awakeFromNib
{
    self.animationDuration = [[LEANAppConfig sharedAppConfig][@"menuAnimationDuration"] floatValue];
    self.limitMenuViewSize = YES;
    self.menuViewSize = CGSizeMake(270, NAN);
    
    self.contentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"contentController"];
    [self.contentViewController view];
    
    self.menuViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"menuController"];
    
    self.webViewController = ((UINavigationController*)self.contentViewController).viewControllers[0];

    
    // pre-load the menu view
    [self.menuViewController view];
    

}

- (NSUInteger)supportedInterfaceOrientations
{
    return self.forcedOrientations;
}

- (void)forceOrientations:(UIInterfaceOrientationMask)orientations
{
    self.forcedOrientations = orientations;

    // hack to do a rotation if the current orientaiton is not one of the force orientations
    if (~(orientations | (1 << [[UIDevice currentDevice] orientation]))) {
        // force rotation
        UIViewController *anyVC = [[UIViewController alloc] init];
        [anyVC setModalPresentationStyle:UIModalPresentationCurrentContext];
        anyVC.view.frame = CGRectZero;
        [self presentViewController:anyVC animated:NO completion:^(void){
            [anyVC dismissViewControllerAnimated:NO completion:nil];
        }];
    }
}

@end
