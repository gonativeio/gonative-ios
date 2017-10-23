//
//  GNSubscriptionsController.m
//  GonativeIO
//
//  Created by Weiyin He on 10/20/17.
//  Copyright © 2017 GoNative.io LLC. All rights reserved.
//

#import "GNSubscriptionsController.h"
#import "GNSubscriptionsTableViewController.h"
#import "GNSubscriptionsModel.h"
#import "GoNativeAppConfig.h"
#import <OneSignal/OneSignal.h>

@interface GNSubscriptionsController ()
@property IBOutlet UIActivityIndicatorView *activityIndicator;
@property GNSubscriptionsTableViewController *tableVC;
@end

@implementation GNSubscriptionsController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadManifestFromUrl:[GoNativeAppConfig sharedAppConfig].oneSignalTagsJsonUrl];
}

- (void)loadManifestFromUrl:(NSURL*)url;
{
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"An error occurred retrieving %@: %@", url, error);
            [self failedWithUserMessage:@"Error retrieving tag list"];
            return;
        }
        
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSLog(@"Response is not http");
            [self failedWithUserMessage:@"Error retrieving tag list"];
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if (httpResponse.statusCode != 200) {
            NSLog(@"Got status %ld when retrieving %@", (long)httpResponse.statusCode, url);
            [self failedWithUserMessage:@"Error retrieving tag list"];
            return;
        }
        
        GNSubscriptionsModel *model = [GNSubscriptionsModel modelWithJSONData:data];
        if (!model) {
            NSLog(@"Invalid JSON from %@", url);
            [self failedWithUserMessage:@"Error retrieving tag list"];
            return;
        }
        
        // get onesignal info
        [OneSignal getTags:^(NSDictionary *result) {
            for (GNSubscriptionsSection *section in model.sections) {
                for (GNSubscriptionItem *item in section.items) {
                    if (item.identifier && result[item.identifier]) {
                        item.isSubscribed = YES;
                    }
                }
            }
            
            [self.tableVC loadModel:model];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityIndicator stopAnimating];
                self.tableVC.view.hidden = NO;
            });
        } onFailure:^(NSError *error) {
            NSLog(@"Error getting OneSignal tags: %@", error);
            [self failedWithUserMessage:@"Error retrieving tags"];
        }];

    }];
    [task resume];
}

-(void)failedWithUserMessage:(NSString*)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"embedTable"]) {
        self.tableVC = segue.destinationViewController;
    }
}

- (IBAction)closePressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
