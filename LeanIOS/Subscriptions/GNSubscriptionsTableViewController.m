//
//  GNSubscriptionsTableViewController.m
//  GonativeIO
//
//  Created by Weiyin He on 10/20/17.
//  Copyright © 2017 GoNative.io LLC. All rights reserved.
//

#import "GNSubscriptionsTableViewController.h"
#import <OneSignal/OneSignal.h>

@interface GNSubscriptionsTableViewController ()
@property GNSubscriptionsModel *model;

@property NSMutableArray *switchTagToIdentifier;
@end

@implementation GNSubscriptionsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.hidden = YES;
    
    self.switchTagToIdentifier = [NSMutableArray array];
}

-(void)loadModel:(GNSubscriptionsModel*)model
{
    self.model = model;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (!self.model) {
        return 0;
    }
    
    return self.model.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.model.sections[section].items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SubscriptionCell" forIndexPath:indexPath];

    GNSubscriptionItem *item = self.model.sections[indexPath.section].items[indexPath.item];
    cell.textLabel.text = item.name;
    
    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
    switchView.tag = self.switchTagToIdentifier.count;
    self.switchTagToIdentifier[switchView.tag] = item.identifier;
    [switchView setOn:item.isSubscribed];
    [switchView addTarget:self action:@selector(switchUpdatedState:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = switchView;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.model.sections[section].name;
}

- (void)switchUpdatedState:(id)sender
{
    UISwitch *switchView = (UISwitch*)sender;
    NSString *identifier = self.switchTagToIdentifier[switchView.tag];
    if (!identifier) {
        return;
    }
    
    if (switchView.isOn) {
        [OneSignal sendTag:identifier value:@"1"];
    } else {
        [OneSignal deleteTag:identifier];
    }
}

@end
