//
//  LEANMenuViewController.m
//  GoNativeIOS
//
//  Created by Weiyin He on 2/7/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANMenuViewController.h"
#import "LEANNavigationController.h"
#import "LEANWebViewController.h"
#import "LEANRootViewController.h"
#import "GoNativeAppConfig.h"
#import "LEANLoginManager.h"
#import "FontAwesome/NSString+FontAwesome.h"
#import "FontAwesome/UIFont+FontAwesome.h"
#import "LEANUrlInspector.h"
#import "LEANTabManager.h"
#import "LEANProfilePicker.h"
#import "LEANUtilities.h"

@interface LEANMenuViewController ()

@property id menuItems;
@property NSMutableArray *groupExpanded;

@property LEANWebViewController *wvc;
@property LEANProfilePicker *profilePicker;

@property UIImage *collapsedIndicator;
@property UIImage *expandedIndicator;
@property UIButton *settingsButton;

@property UIView *headerView;
@property UISegmentedControl *segmentedControl;
@property NSArray *segmentedControlItems;

@property BOOL groupsHaveIcons;
@property BOOL childrenHaveIcons;
@property NSString *lastUpdatedStatus;

@end

@implementation LEANMenuViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.opaque = NO;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.sectionHeaderHeight = 0;
    self.tableView.sectionFooterHeight = 0;
    
    NSArray *arr = [[NSBundle mainBundle] loadNibNamed:@"HeaderView" owner:nil options:nil];

    UIView *headerView = arr[0];
    self.headerView = headerView;
    headerView.autoresizingMask = UIViewAutoresizingNone;
    UIButton *headerButton = (UIButton*)[headerView viewWithTag:1];
    [headerButton addTarget:self action:@selector(picturePressed:) forControlEvents:UIControlEventTouchUpInside];
    if ([GoNativeAppConfig sharedAppConfig].sidebarIcon) {
        [headerButton setImage:[GoNativeAppConfig sharedAppConfig].sidebarIcon forState:UIControlStateNormal];
    }
    else if ([GoNativeAppConfig sharedAppConfig].appIcon) {
        [headerButton setImage:[GoNativeAppConfig sharedAppConfig].appIcon forState:UIControlStateNormal];
    }
        
    self.segmentedControl = (UISegmentedControl*)[headerView viewWithTag:3];
    [self setupSegmentedControl];
    
    self.tableView.tableHeaderView = headerView;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    
    // actually update the menus
    [self updateMenuWithStatus:@"default"];

    if ([GoNativeAppConfig sharedAppConfig].loginDetectionURL) {
        // subscribe to login notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveLoginNotification:) name:kLEANLoginManagerNotificationName object:nil];
        [[LEANLoginManager sharedManager] checkIfNotAlreadyChecking];
    }

    // pre-load images. Color them too.
    self.collapsedIndicator = [[UIImage imageNamed:@"chevronDown"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.expandedIndicator = [[UIImage imageNamed:@"chevronUp"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedMenu object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedSegmented object:nil];

    // profile picker
    self.profilePicker = [[LEANProfilePicker alloc] init];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveNotification:(NSNotification*)notification
{
    // dynamic menu update
    if ([[notification name] isEqualToString:kLEANAppConfigNotificationProcessedMenu]) {
        [self updateMenuWithStatus:self.lastUpdatedStatus];
    }
    else if ([[notification name] isEqualToString:kLEANAppConfigNotificationProcessedSegmented]) {
        [self updateSegmentedControl];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // webviewcontroller reference
    LEANNavigationController* nav = (LEANNavigationController*)self.frostedViewController.contentViewController;
    self.wvc = (LEANWebViewController*)nav.viewControllers[0];
}

- (void)didReceiveLoginNotification:(NSNotification*)notification
{
    LEANLoginManager *loginManager = [notification object];
    [self updateMenuWithStatus:loginManager.loginStatus];
}

- (void)updateMenuWithStatus:(NSString *)status
{
    if (!status) status = @"default";
    
    self.lastUpdatedStatus = status;
    
    self.menuItems = [GoNativeAppConfig sharedAppConfig].menus[status];
    
    // see if any menu items have icons. Used for layout indentation.
    self.groupsHaveIcons = NO;
    self.childrenHaveIcons = NO;
    for (id item in self.menuItems) {
        if (item[@"icon"] && item[@"icon"] != [NSNull null]) {
            self.groupsHaveIcons = YES;
        }
        
        if ([item[@"isGrouping"] boolValue]) {
            for (id sublink in item[@"subLinks"]) {
                if (sublink[@"icon"] && sublink[@"icon"] != [NSNull null]) {
                    self.childrenHaveIcons = YES;
                    break;
                }
            }
        }
    }
    
    // groups are initially collapsed
    self.groupExpanded = [[NSMutableArray alloc] initWithCapacity:[self.menuItems count]];
    for (int i = 0; i < [self.menuItems count]; i++) {
        self.groupExpanded[i] = [NSNumber numberWithBool:NO];
    }
    
    [self.tableView reloadData];
}

- (void)logOut
{
    [self.wvc logout];
    [self updateMenuWithStatus:@"default"];
}

- (void)showSettings:(BOOL)showSettings
{
    [self.settingsButton setUserInteractionEnabled:showSettings];
    [UIView animateWithDuration:0.3 animations:^(void){
        self.settingsButton.alpha = showSettings ? 1.0 : 0.0;
    }];
}

- (IBAction)picturePressed:(id)sender {
    [self.wvc loadUrl:[GoNativeAppConfig sharedAppConfig].initialURL];
    [self.frostedViewController hideMenuViewController];
}

- (void)parseProfilePickerJSON:(NSString *)json
{
    [self.profilePicker parseJson:json];
    [self showSettings:self.profilePicker.hasProfiles];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.menuItems count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([self.groupExpanded[section] boolValue]) {
        return 1 + [self.menuItems[section][@"subLinks"] count];
    }
    else
        return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellNib;
    UITableViewCell *cell;
    UIImageView *imageView;
    UILabel *label;
    if (indexPath.row == 0) {
        if (self.groupsHaveIcons) cellNib = @"MenuGroupIcon";
        else cellNib = @"MenuGroupNoIcon";
    } else {
        if (self.groupsHaveIcons || self.childrenHaveIcons) cellNib = @"MenuChildIcon";
        else cellNib = @"MenuChildNoIcon";
    }
    
    cell = [tableView dequeueReusableCellWithIdentifier:cellNib];
    if (nil == cell) {
        cell = [[NSBundle mainBundle] loadNibNamed:cellNib owner:nil options:nil][0];
        cell.backgroundColor = [UIColor clearColor]; // shouldn't need this, but background is white on ipad if I don't do this.
        UIView* separatorLineView = [[UIView alloc] initWithFrame:CGRectMake(15, 0, 240, 1)];
        separatorLineView.backgroundColor = [UIColor colorWithHue:0 saturation:0 brightness:.7 alpha:.5];
        separatorLineView.tag = 99;
        [cell.contentView addSubview:separatorLineView];
    }
    
    label = (UILabel*)[cell.contentView viewWithTag:1];
    imageView = (UIImageView*)[cell.contentView viewWithTag:2];
    
    // get data
    id menuItem;
    if (indexPath.row == 0) {
        menuItem = self.menuItems[indexPath.section];
    } else {
        menuItem = self.menuItems[indexPath.section][@"subLinks"][indexPath.row - 1];
    }
    
    // text
    label.text = [menuItem[@"label"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([GoNativeAppConfig sharedAppConfig].iosSidebarFont) {
        label.font = [GoNativeAppConfig sharedAppConfig].iosSidebarFont;
    }
    
    // expand/collapse indicator
    if ([menuItem[@"isGrouping"] boolValue]) {
        if ([self.groupExpanded[indexPath.section] boolValue]) {
            cell.accessoryView = [[UIImageView alloc] initWithImage:self.expandedIndicator];
        } else {
            cell.accessoryView = [[UIImageView alloc] initWithImage:self.collapsedIndicator];
        }
    } else
        cell.accessoryView = nil;
    
    // icon
    UILabel *icon;
    if (menuItem[@"icon"] && [menuItem[@"icon"] isKindOfClass:[NSString class]]) {
        if ([menuItem[@"icon"] hasPrefix:@"fa-"]) {
            // add fontawesome icon to imageView
            icon = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, imageView.bounds.size.width, imageView.bounds.size.height)];
            icon.textAlignment = NSTextAlignmentCenter;
            icon.font = [UIFont fontAwesomeFontOfSize:[UIFont systemFontSize]];
            icon.text = [NSString fontAwesomeIconStringForIconIdentifier:menuItem[@"icon"]];
            [imageView addSubview:icon];
        } else {
            UIImage *image = [UIImage imageNamed:menuItem[@"icon"]];
            imageView.image = image;
        }
    } else {
        imageView.image = nil;
        [[imageView subviews]
         makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
                              
    // configure text color
    if ([GoNativeAppConfig sharedAppConfig].iosSidebarTextColor) {
        label.textColor = [GoNativeAppConfig sharedAppConfig].iosSidebarTextColor;
        icon.textColor = [GoNativeAppConfig sharedAppConfig].iosSidebarTextColor;
        cell.tintColor = [GoNativeAppConfig sharedAppConfig].iosSidebarTextColor;
    }
    else if ([GoNativeAppConfig sharedAppConfig].tintColor) {
        label.textColor = [GoNativeAppConfig sharedAppConfig].tintColor;
        icon.textColor = [GoNativeAppConfig sharedAppConfig].tintColor;
        cell.tintColor = [GoNativeAppConfig sharedAppConfig].tintColor;
    }
    
    // hide separator line from first cell
    if (indexPath.section == 0 && indexPath.row == 0) {
        [cell.contentView viewWithTag:99].hidden = YES;
    } else {
        [cell.contentView viewWithTag:99].hidden = NO;
    }
    
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *url = nil;
    NSString *javascript = nil;
    BOOL isLogout;
    
    // if is first row, then check if it is grouped.
    if (indexPath.row == 0) {
        if ([self.menuItems[indexPath.section][@"isGrouping"] boolValue]) {
            self.groupExpanded[indexPath.section] = [NSNumber numberWithBool:![self.groupExpanded[indexPath.section] boolValue]];
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else {
            NSDictionary *item = self.menuItems[indexPath.section];
            url = item[@"url"];
            javascript = item[@"javascript"];
            isLogout = [item[@"isLogout"] boolValue];
        }
    } else {
        // regular child
        NSDictionary *item = self.menuItems[indexPath.section][@"subLinks"][indexPath.row - 1];
        url = item[@"url"];
        javascript = item[@"javascript"];
        isLogout = [item[@"isLogout"] boolValue];
    }
    
    if (url != nil) {
        // check for GONATIVE_USERID string.
        url = [url stringByReplacingOccurrencesOfString:@"GONATIVE_USERID" withString:[LEANUrlInspector sharedInspector].userId];
        
        if ([url hasPrefix:@"javascript:"]) {
            NSString *js = [url substringFromIndex: [@"javascript:" length]];
            [self.wvc runJavascript:js];
        } else {
            // try selecting the corresponding tab (if exists);
            if (self.wvc.tabManager) {
                [self.wvc.tabManager selectTabWithUrl:url javascript:javascript];
            }
            
            if ([javascript length] > 0) {
                [self.wvc loadUrl:[LEANUtilities urlWithString:url] andJavascript:javascript];
            } else {
                [self.wvc loadUrl:[LEANUtilities urlWithString:url]];
            }
        }
        [self.frostedViewController hideMenuViewController];
        
        if (isLogout) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.wvc logout];
            });
        }
    }
}

#pragma mark - Segmented control
-(void)setupSegmentedControl
{
    [self.segmentedControl addTarget:self action:@selector(segmentedControlChanged:) forControlEvents:UIControlEventValueChanged];
    [self updateSegmentedControl];
    
}

-(void)updateSegmentedControl
{
    self.segmentedControlItems = [GoNativeAppConfig sharedAppConfig].segmentedControlItems;
    BOOL showSegmentedControl = self.segmentedControlItems && [self.segmentedControlItems count] > 0;
    if (showSegmentedControl) {
        if (self.segmentedControl.hidden) {
            // expand header view
            self.segmentedControl.hidden = NO;
            CGRect oldFrame = self.headerView.frame;
            oldFrame.size.height += 50;
            self.headerView.frame = oldFrame;
            [self.tableView setTableHeaderView:self.headerView];
        }
        
        [self.segmentedControl removeAllSegments];
        for (NSInteger i = 0; i < [self.segmentedControlItems count]; i++) {
            NSDictionary *item = self.segmentedControlItems[i];
            
            NSString *label = nil;
            BOOL selected = NO;
            
            if ([item isKindOfClass:[NSDictionary class]]) {
                label = item[@"label"];
                selected = [item[@"selected"] boolValue];
            }
            
            if (![label isKindOfClass:[NSString class]]) {
                label = @"Invalid";
            }
            
            [self.segmentedControl insertSegmentWithTitle:label atIndex:i animated:NO];
            if (selected) {
                self.segmentedControl.selectedSegmentIndex = i;
            }
        }
        
    }
    else {
        if (!self.segmentedControl.hidden) {
            self.segmentedControl.hidden = YES;
            
            // shrink the header view
            CGRect oldFrame = self.headerView.frame;
            oldFrame.size.height -= 50;
            self.headerView.frame = oldFrame;
            [self.tableView setTableHeaderView:self.headerView];
        }
    }
}

-(IBAction)segmentedControlChanged:(id)sender
{
    UISegmentedControl *control = sender;
    NSInteger selectedIndex = control.selectedSegmentIndex;
    if (selectedIndex < 0 || selectedIndex >= [self.segmentedControlItems count]) return;
    
    NSDictionary *item = self.segmentedControlItems[selectedIndex];
    if (![item isKindOfClass:[NSDictionary class]]) return;

    NSString *url = item[@"url"];
    NSString *javascript = item[@"javascript"];
    
    if ([url isKindOfClass:[NSString class]]) {
        if ([url hasPrefix:@"javascript:"]) {
            NSString *js = [url substringFromIndex: [@"javascript:" length]];
            [self.wvc runJavascript:js];
        } else {
            if ([javascript isKindOfClass:[NSString class]] && [javascript length] > 0) {
                [self.wvc loadUrl:[NSURL URLWithString:url] andJavascript:javascript];
            } else {
                [self.wvc loadUrl:[NSURL URLWithString:url]];
            }
        }
    }
    
    [self.frostedViewController hideMenuViewController];
}
@end


