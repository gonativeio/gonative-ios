//
//  LEANSettingsController.m
//  GoNativeIOS
//
//  Created by Weiyin He on 5/13/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANSettingsController.h"

@interface LEANSettingsController ()

@end

@implementation LEANSettingsController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.profilePicker) {
        return 1;
    } else {
        return 0;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.profilePicker.names count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"Profiles";
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsCell" forIndexPath:indexPath];
    
    // Configure the cell...
    if (indexPath.row < [self.profilePicker.names count]) {
        cell.textLabel.text = self.profilePicker.names[indexPath.row];
        if (indexPath.row == self.profilePicker.selectedIndex) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else {
        cell.textLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.profilePicker.selectedIndex = indexPath.row;
    [self.tableView reloadData];
    
    if (indexPath.row < [self.profilePicker.links count]) {
        [self.wvc loadUrlString:self.profilePicker.links[indexPath.row]];
    }
    [self dismiss];
}

- (void)dismiss
{
    [self.navigationController popViewControllerAnimated:YES];
    [self.popover dismissPopoverAnimated:YES];
    
}


@end
