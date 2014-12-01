//
//  LEANWebFormController.m
//  LeanIOS
//
//  Created by Weiyin He on 3/1/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANWebFormController.h"
#import "LEANUtilities.h"
#import "LEANWebViewController.h"
#import "LEANRootViewController.h"
#import "LEANMenuViewController.h"
#import "NSURL+LEANUtilities.h"
#import "LEANAppConfig.h"
#import "LEANLoginManager.h"
#import "LEANPushManager.h"
#import <WebKit/WebKit.h>

static NSString *kGenericErrorMessage = @"Problem with form submission. Please check your inputs and try again";

@interface LEANWebFormController () <UIWebViewDelegate, WKNavigationDelegate>

@property id json;
@property NSArray *sections;
@property NSMutableDictionary *indexPathToCell;
@property UIBarButtonItem *submitButton;
@property UIBarButtonItem *cancelButton;

@property NSString *title;
@property NSURL *formUrl;
@property NSURL *errorUrl;
@property NSURL *passwordResetUrl;
@property BOOL isLogin;
@property BOOL checkingLogin;
@property UIWebView *hiddenWebView;
@property NSTimer *checkSubmissionTimer;

// wkwebview stuff
@property WKWebView *hiddenWkWebview;
@property NSMutableArray *javascriptQueue;
@property BOOL isRunningJavacript;

@property BOOL submitted;
@property NSString *tempUserID;
@property UIColor *backgroundColor;


@end

@implementation LEANWebFormController

- (id)initWithJsonObject:(id)json
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.json = json;
        self.title = json[@"title"];
        self.formUrl = [NSURL URLWithString:json[@"interceptUrl"]];
        self.errorUrl = [NSURL URLWithString:json[@"errorUrl"]];
        self.isLogin = [json[@"isLogin"] boolValue];
        
        if (self.isLogin && json[@"passwordResetUrl"]) {
            self.passwordResetUrl = [NSURL URLWithString:json[@"passwordResetUrl"]];
        }
        
        self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
        
        if ([LEANAppConfig sharedAppConfig].useWKWebView) {
            WKWebViewConfiguration *config = [[NSClassFromString(@"WKWebViewConfiguration") alloc] init];
            config.processPool = [LEANUtilities wkProcessPool];
            self.hiddenWkWebview = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:self.view.frame configuration:config];
            self.hiddenWkWebview.navigationDelegate = self;
        } else {
            self.hiddenWebView = [[UIWebView alloc] init];
            self.hiddenWebView.delegate = self;
        }
        
        // if login is first page, wait until after we've checked to load the login url
        // if loaded too early, may break some csrf protected pages.
        if (!self.isLogin || ![LEANAppConfig sharedAppConfig].loginIsFirstPage){
            [self loadRequest:[NSURLRequest requestWithURL:self.formUrl]];
        }
        
        [self loadJsonObject:json];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)config title:(NSString *)title isLogin:(BOOL)isLogin
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.json = config;
        self.title = title;
        self.formUrl = [NSURL URLWithString:config[@"interceptUrl"]];
        self.errorUrl = [NSURL URLWithString:config[@"errorUrl"]];
        self.isLogin = isLogin;
        
        if (self.isLogin && config[@"passwordResetUrl"]) {
            self.passwordResetUrl = [NSURL URLWithString:config[@"passwordResetUrl"]];
        }
        
        self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
        
        if ([LEANAppConfig sharedAppConfig].useWKWebView) {
            WKWebViewConfiguration *config = [[NSClassFromString(@"WKWebViewConfiguration") alloc] init];
            config.processPool = [LEANUtilities wkProcessPool];
            self.hiddenWkWebview = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:self.view.frame configuration:config];
            self.hiddenWkWebview.navigationDelegate = self;

        } else {
            self.hiddenWebView = [[UIWebView alloc] init];
            self.hiddenWebView.delegate = self;
        }
        
        // if login is first page, wait until after we've checked to load the login url
        // if loaded too early, may break some csrf protected pages.
        if (!self.isLogin || ![LEANAppConfig sharedAppConfig].loginIsFirstPage) {
            [self loadRequest:[NSURLRequest requestWithURL:self.formUrl]];
        }
        
        [self loadJsonObject:config];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // show logo in navigation bar
    if ([LEANAppConfig sharedAppConfig].navigationTitleImageRegexes) {
        UIImage *im = [LEANAppConfig sharedAppConfig].navigationTitleIcon;
        if (!im) im = [UIImage imageNamed:@"navbar_logo"];
        
        if (im) {
            CGRect bounds = CGRectMake(0, 0, 30 * im.size.width / im.size.height, 30);
            UIView *backView = [[UIView alloc] initWithFrame:bounds];
            UIImageView *iv = [[UIImageView alloc] initWithImage:im];
            iv.bounds = bounds;
            [backView addSubview:iv];
            iv.center = backView.center;
            self.navigationItem.titleView = backView;
        }
    }
        
    // background color
    self.backgroundColor = [LEANUtilities colorFromHexString:self.json[@"iosBackgroundColor"]];
    if (self.backgroundColor) {
        self.view.backgroundColor = self.backgroundColor;
    }
    
    // Add "done" button to navigation bar
    self.submitButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(submit:)];
    
    // if login is the first page that loads, hide back button. Hide form until login check is done.
    if (self.isLogin && [LEANAppConfig sharedAppConfig].loginIsFirstPage) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANLoginManagerNotificationName object:nil];
        
        [[LEANLoginManager sharedManager] checkIfNotAlreadyChecking];
        
        self.checkingLogin = YES;
        self.navigationItem.hidesBackButton = YES;
        
        // background launch image
        if ([LEANAppConfig sharedAppConfig].loginLaunchBackground) {
            UIImage *image = [UIImage imageNamed:[LEANUtilities getLaunchImageName]];
            UIImageView *background = [[UIImageView alloc] initWithImage:image];
            self.tableView.backgroundView = background;
        }
        
        // add header
        if ([LEANAppConfig sharedAppConfig].loginIconImage) {
            NSArray *arr = [[NSBundle mainBundle] loadNibNamed:@"LoginHeaderView" owner:nil options:nil];
            UIView *headerView = arr[0];
            
            if ([LEANAppConfig sharedAppConfig].appIcon) {
                UIButton *button = (UIButton*)[headerView viewWithTag:1];
                if ([button isKindOfClass:[UIButton class]]) {
                    [button setImage:[LEANAppConfig sharedAppConfig].appIcon forState:UIControlStateNormal];
                }
            }
            
            self.tableView.tableHeaderView = headerView;
        }
    } else {
        self.checkingLogin = NO;
        self.navigationItem.rightBarButtonItem = self.submitButton;
        
    }
    
    // set title
    self.navigationItem.title = self.title;
    
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    // add cancel button for ipad
    if (self.navigationController.modalPresentationStyle == UIModalPresentationFormSheet) {
        self.cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
        self.navigationItem.leftBarButtonItem = self.cancelButton;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.hiddenWebView.delegate = nil;
    self.hiddenWkWebview.navigationDelegate = nil;
}

- (void)didReceiveNotification:(NSNotification*)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    LEANLoginManager *loginManager = [notification object];
    
    if (self.checkingLogin) {
        self.checkingLogin = NO;
        if (loginManager.loggedIn) {
            [self dismiss];
            // load url in main view
            LEANWebViewController *wv = ((LEANRootViewController*)self.frostedViewController).webViewController;
            if (self.json[@"successUrl"] && self.json[@"successUrl"] != [NSNull null]) {
                [wv loadUrl:[NSURL URLWithString:self.json[@"successUrl"]]];
            } else {
                // need to skip login interception on this load.
                wv.checkLoginSignup = NO;
                [wv loadUrl:[LEANAppConfig sharedAppConfig].initialURL];
            }
        } else {
            [self loadRequest:[NSURLRequest requestWithURL:self.formUrl]];
            [self.tableView reloadData];
            self.navigationItem.rightBarButtonItem = self.submitButton;
        }
    }
}

- (void)loadJsonObject:(id)json
{
    self.json = json;
    
    // process fields into sections
    NSMutableArray *sections = [[NSMutableArray alloc] init];
    NSMutableArray *currentSection = [[NSMutableArray alloc] init];
    
    int numCells = 0; // only used for more efficient allocation of indexPathToCell
    
    NSMutableDictionary *lastPasswordField;
    for (id field in self.json[@"formInputs"]) {
        if (![field[@"type"] isEqualToString:@"list"]) {
            if ([field[@"type"] isEqualToString:@"password"]) {
                lastPasswordField = [field mutableCopy];
                [currentSection addObject:lastPasswordField];
                numCells++;
            } else if ([field[@"type"] isEqualToString:@"password (hidden)"]) {
                lastPasswordField[@"selector2"] = field[@"selector"];
            } else {
                [currentSection addObject:field];
                numCells++;
            }
        }
        else {
            if ([currentSection count] > 0) {
                [sections addObject:currentSection];
            }
            
            [sections addObject:field];
            numCells += [field[@"choices"] count];
            
            currentSection = [[NSMutableArray alloc] init];
        }
    }
    
    if ([currentSection count] > 0) {
        [sections addObject:currentSection];
    }
    
    // add forgot password field
    if (self.passwordResetUrl) {
        [sections addObject:@[@{@"type": @"forgot_password"}]];
        numCells++;
    }
    
    self.sections = sections;
    self.indexPathToCell = [[NSMutableDictionary alloc] initWithCapacity:numCells];
    
    [self.tableView reloadData];
}

- (void)loadRequest:(NSURLRequest*)request{
    if (self.hiddenWebView) {
        [self.hiddenWebView loadRequest:request];
    }
    else if(self.hiddenWkWebview) {
        [self.hiddenWkWebview loadRequest:request];
    }
}

- (IBAction)finishedEditingField:(id)sender {
    // try to select next editable field
    if ([sender isKindOfClass:[UITextField class]]) {
        UITextField *field = sender;
        [field resignFirstResponder];
        
        CGPoint pointInTable = [field convertPoint:field.bounds.origin toView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:pointInTable];
        NSIndexPath *nextPath = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
        UITableViewCell *nextCell = [self.tableView cellForRowAtIndexPath:nextPath];
        
        if ([nextCell.contentView.subviews count] > 0){
            UIView *innerView = nextCell.contentView.subviews[0];
            
            if ([innerView.subviews count] >= 2 && [innerView.subviews[1] isKindOfClass:[UITextField class]])
                [innerView.subviews[1] becomeFirstResponder];
        }
    }
}

- (IBAction)showPassword:(UIButton*)sender {
    UITextField *password = sender.superview.subviews[1];
    
    BOOL wasFirstResponder = password.isFirstResponder;
    if (wasFirstResponder) [password resignFirstResponder];
    
    password.secureTextEntry = !password.secureTextEntry;
    
    if (wasFirstResponder) [password becomeFirstResponder];
    
    if (!password.secureTextEntry)
        sender.tintColor = nil;
    else
        sender.tintColor = [UIColor lightGrayColor];
}

- (void)runJavascriptSync:(NSString*)js
{
    if (self.hiddenWebView) {
        [self.hiddenWebView stringByEvaluatingJavaScriptFromString:js];
        return;
    }
    
    // need to manage queue for wkwebview
    if (!self.javascriptQueue) {
        self.javascriptQueue = [NSMutableArray array];
        self.isRunningJavacript = NO;
    }
    
    if ([js isEqualToString:@"execution finished"]) {
        // callback from javascript execution
        self.isRunningJavacript = NO;
        if ([self.javascriptQueue count] > 0) {
            NSString *next = [self.javascriptQueue objectAtIndex:0];
            [self.javascriptQueue removeObjectAtIndex:0];
            [self runJavascriptSync:next];
        }
        
        return;
    }
    
    if (!self.isRunningJavacript) {
        self.isRunningJavacript = YES;
        [self.hiddenWkWebview evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
            [self runJavascriptSync:@"execution finished"];
        }];
    } else {
        [self.javascriptQueue addObject:js];
    }
    
}

- (IBAction)submit:(id)sender {
    if ([self validateFormShowErrors:YES]) {
//        self.view = self.hiddenWebView;
        
        // hide keyboard
        [self.view endEditing:YES];
        self.submitted = YES;
        self.submitButton.enabled = NO;
        
        // fill in web form
        NSInteger fieldNum = 0;
        for (int sectNum = 0; sectNum < [self.sections count]; sectNum++) {
            id sect = self.sections[sectNum];
            if ([sect isKindOfClass:[NSArray class]]) {
                for (int rowNum = 0; rowNum < [sect count]; rowNum++) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowNum inSection:sectNum];
                    id field = self.sections[indexPath.section][indexPath.row];
                    UITableViewCell *cell = [self tableView:self.tableView cellForRowAtIndexPath:indexPath];
                    
                    
                    if ([@[@"email", @"name", @"text", @"number",@"password"] containsObject:field[@"type"]]){
                        // these fields have a text field
                        UIView *innerView = cell.contentView.subviews[0];
                        UITextField *textField = innerView.subviews[1];
                        
                        [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).val(%@);", [LEANUtilities jsWrapString:field[@"selector"]], [LEANUtilities jsWrapString:textField.text]]];
                        if (field[@"selector2"]) {
                            [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).val(%@);", [LEANUtilities jsWrapString:field[@"selector2"]], [LEANUtilities jsWrapString:textField.text]]];
                        }
                        
                        // user id for push notifications
                        if ([field[@"isUserID"] boolValue]) {
                            self.tempUserID = textField.text;
                        }
                        
                    }
                    else if ([field[@"type"] isEqualToString:@"textarea"]){
                        UITextView *textView = (UITextView*)[cell viewWithTag:2];
                        [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).val(%@);", [LEANUtilities jsWrapString:field[@"selector"]], [LEANUtilities jsWrapString:textView.text]]];
                    }
                    else if ([field[@"type"] isEqualToString:@"date"]) {
                        UIDatePicker *datePicker = (UIDatePicker*)[cell viewWithTag:2];
                        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
                        NSDateComponents *components = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit fromDate:datePicker.date];
                        [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).val(%ld);", [LEANUtilities jsWrapString:field[@"yearSelector"]], (long)components.year]];
                        [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).val(%ld);", [LEANUtilities jsWrapString:field[@"monthSelector"]], (long)components.month]];
                        [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).val(%ld);", [LEANUtilities jsWrapString:field[@"daySelector"]], (long)components.day]];
                        
                    }
                    else if ([field[@"type"] isEqualToString:@"options"]){
                        UIView *innerView = cell.contentView.subviews[0];
                        UISegmentedControl *seg = innerView.subviews[1];
                        
                        if (seg.selectedSegmentIndex >= 0) {
                            NSString *selector = field[@"choices"][seg.selectedSegmentIndex][@"selector"];
                            [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).click();", [LEANUtilities jsWrapString:selector]]];
                            [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).prop('selected', true);", [LEANUtilities jsWrapString:selector]]];
                            
                        }
                    }
                    else if ([field[@"type"] isEqualToString:@"checkbox"]){
                        UIView *innerView = cell.contentView.subviews[0];
                        UISwitch *theSwitch = innerView.subviews[1];
                        
                        if (theSwitch.on) {
                            [self runJavascriptSync:[NSString stringWithFormat:@"jQuery(%@).prop('checked', true);", [LEANUtilities jsWrapString:field[@"selector"]]]];
                        }
                        else {
                            [self runJavascriptSync:[NSString stringWithFormat:@"jQuery(%@).prop('checked', false);", [LEANUtilities jsWrapString:field[@"selector"]]]];
                        }
                    }
                    
                    fieldNum++;
                }
            }
            else {
                // list type
                id field = self.sections[sectNum];
                
                for (int i = 0; i < [field[@"choices"] count]; i++) {
                    UITableViewCell *cell = [self tableView:self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:sectNum]];
                    if (cell.accessoryType == UITableViewCellAccessoryCheckmark) {
                        NSString *selector = field[@"choices"][i][@"selector"];
                        [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).click();", [LEANUtilities jsWrapString:selector]]];
                        [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).prop('selected', true);", [LEANUtilities jsWrapString:selector]]];
                    }
                }
                
                fieldNum++;
            }
        }
        
        // submit the form
        if ([self.json[@"submitButtonSelector"] length] > 0) {
            [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).click();", [LEANUtilities jsWrapString:self.json[@"submitButtonSelector"]]]];
        } else {
            [self runJavascriptSync: [NSString stringWithFormat: @"jQuery(%@).submit();", [LEANUtilities jsWrapString:self.json[@"formSelector"]]]];
        }
        
        // for ajax login forms
        if (self.isLogin && [self.json[@"isAjax"] boolValue])
            [self scheduleSubmissionCheckTimer];
    }
}

// ipad only
- (IBAction)cancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)validateFormShowErrors:(BOOL)showErrors
{
    for (int sectNum = 0; sectNum < [self.sections count]; sectNum++) {
        id sect = self.sections[sectNum];
        if ([sect isKindOfClass:[NSArray class]]) {
            for (int rowNum = 0; rowNum < [sect count]; rowNum++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowNum inSection:sectNum];
                if (![self validateFieldAt:indexPath showErrors:showErrors])
                    return NO;
            }
        }
        else {
            // list type
            if(![self validateListAtSection:sectNum showErrors:showErrors])
                return NO;
        }
    }

    return YES;
}

- (BOOL)validateFieldAt:(NSIndexPath*)indexPath showErrors:(BOOL)showErrors
{
    id field = self.sections[indexPath.section][indexPath.row];
    UITableViewCell *cell = [self tableView:self.tableView cellForRowAtIndexPath:indexPath];
    
    if ([@[@"email", @"name", @"text", @"number",@"password",@"textarea"] containsObject:field[@"type"]]){
        // these fields have text
        NSString *text;
        UIResponder *responder;
        if ([field[@"type"] isEqualToString:@"textarea"]) {
            UITextView *textView = (UITextView*)[cell viewWithTag:2];
            text = textView.text;
            responder = textView;
        } else {
            UIView *innerView = cell.contentView.subviews[0];
            UITextField *textField = innerView.subviews[1];
            text = textField.text;
            responder = textField;
        }
        
        // trim text
        text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (field[@"required"] && field[@"required"] != [NSNull null] && [field[@"required"] boolValue] && [text length] == 0) {
            if (showErrors) {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Missing %@", field[@"label"]] delegate:nil cancelButtonTitle:@"OK"otherButtonTitles:nil] show];
                [responder becomeFirstResponder];
                [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
            }
            return NO;
        }
        
        if (field[@"minLength"] && [text length] < [field[@"minLength"] integerValue]) {
            if (showErrors) {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"%@ must be at least %ld characters", field[@"label"], (long)[field[@"minLength"] integerValue]] delegate:nil cancelButtonTitle:@"OK"otherButtonTitles:nil] show];
                [responder becomeFirstResponder];
                [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
            }
            return NO;
        }
        
        if ([field[@"type"] isEqualToString:@"email"] && ![text isEqualToString:@""]  && ![LEANUtilities isValidEmail:text]) {
            if (showErrors) {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"%@ is not a valid email address", field[@"label"]] delegate:nil cancelButtonTitle:@"OK"otherButtonTitles:nil] show];
                [responder becomeFirstResponder];
                [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
            }
            return NO;
        }
    }
    else if ([field[@"type"] isEqualToString:@"options"]){
        UIView *innerView = cell.contentView.subviews[0];
        UISegmentedControl *seg = innerView.subviews[1];
        
        if (field[@"required"] && field[@"required"] != [NSNull null] && [field[@"required"] boolValue] && seg.selectedSegmentIndex == -1) {
            if (showErrors) {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Missing %@", field[@"label"]] delegate:nil cancelButtonTitle:@"OK"otherButtonTitles:nil] show];
                [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
            }
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)validateListAtSection:(NSInteger)section showErrors:(BOOL)showErrors
{
    id field = self.sections[section];
    if (field[@"required"] && field[@"required"] != [NSNull null] && [field[@"required"] boolValue]) {
        BOOL isSelected = NO;
        for (int i = 0; i < [field[@"choices"] count]; i++) {
            UITableViewCell *cell = [self tableView:self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:section]];
            if (cell.accessoryType == UITableViewCellAccessoryCheckmark) {
                isSelected = YES;
                break;
            }
        }
        
        if (!isSelected) {
            if (showErrors) {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Missing %@", field[@"label"]] delegate:nil cancelButtonTitle:@"OK"otherButtonTitles:nil] show];
                [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section] atScrollPosition:UITableViewScrollPositionNone animated:YES];
            }
            return NO;
        }
    }
    
    return YES;
}

- (void)forgotPassword
{
    LEANWebViewController *wv = ((LEANRootViewController*)self.frostedViewController).webViewController;
    [wv loadUrl:self.passwordResetUrl];
    [self dismiss];
}

- (void)dismiss
{
    // only has an effect on ipad, where the current controller is in a navigation controller embedded in a form sheet. On iphone, let the web view controller manage dismissing the form controller
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)scheduleSubmissionCheckTimer
{
    
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(checkSubmissionStatus) userInfo:nil repeats:NO];
    [timer setTolerance:0.5];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    self.checkSubmissionTimer = timer;
}

- (void)checkSubmissionStatus
{
    if (self.submitted) {
        NSString *messageJs = [NSString stringWithFormat:@"jQuery(%@).html();", [LEANUtilities jsWrapString:self.json[@"errorSelector"]]];
        
        if (self.hiddenWebView) {
            NSString *message = [self.hiddenWebView stringByEvaluatingJavaScriptFromString: messageJs];
            if (![message isKindOfClass:[NSString class]]) {
                message = @"";
            } else {
                message = [LEANUtilities stripHTML:message replaceWith:@" "];
            }
            
            NSString *message2 = nil;
            if ([self.json[@"errorSelector2"] isKindOfClass:[NSString class]]) {
                message2 = [self.hiddenWebView stringByEvaluatingJavaScriptFromString: [NSString stringWithFormat:@"jQuery(%@).html();", [LEANUtilities jsWrapString:self.json[@"errorSelector2"]]]];
                if (![message2 isKindOfClass:[NSString class]]) {
                    message2 = @"";
                } else {
                    message2 = [LEANUtilities stripHTML:message2 replaceWith:@" "];
                }
            }
            
            if ([message isEqualToString:@""] && [message2 isEqualToString:@""]) {
                // no error. Continue checking.
                [self scheduleSubmissionCheckTimer];
            } else {
                // error with submission
                [[[UIAlertView alloc] initWithTitle:self.title message:[NSString stringWithFormat:@"%@ %@", message, message2] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
                self.submitted = NO;
                self.submitButton.enabled = YES;
            }
        } else if (self.hiddenWkWebview) {
            [self.hiddenWkWebview evaluateJavaScript:messageJs completionHandler:^(id message, NSError *error) {
                
                if (![message isKindOfClass:[NSString class]]) {
                    message = @"";
                } else {
                    message = [LEANUtilities stripHTML:message replaceWith:@" "];
                }

                void (^message2block)(id, NSError*) = ^(id message2, NSError *error2) {
                    if (![message2 isKindOfClass:[NSString class]]) {
                        message2 = @"";
                    } else {
                        message2 = [LEANUtilities stripHTML:message2 replaceWith:@" "];
                    }
                    
                    if ([message isEqualToString:@""] && [message2 isEqualToString:@""]) {
                        // no error. Continue checking.
                        [self scheduleSubmissionCheckTimer];
                    } else {
                        // error with submission
                        [[[UIAlertView alloc] initWithTitle:self.title message:[NSString stringWithFormat:@"%@ %@", message, message2] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
                        self.submitted = NO;
                        self.submitButton.enabled = YES;
                    }
                };
                
                if ([self.json[@"errorSelector2"] isKindOfClass:[NSString class]]) {
                    NSString *message2js = [NSString stringWithFormat:@"jQuery(%@).html();", [LEANUtilities jsWrapString:self.json[@"errorSelector2"]]];
                    [self.hiddenWkWebview evaluateJavaScript:message2js completionHandler:message2block];

                } else {
                    message2block(nil, nil);
                }

            }];
        }
    }
}


#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.checkingLogin) return 1;
    else return [self.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.checkingLogin)
        return 1;
    
    id sect = self.sections[section];
    if ([sect isKindOfClass:[NSArray class]]) {
        return [sect count];
    }
    else if ([sect[@"type"] isEqualToString:@"list"]) {
        // list type field
        return [sect[@"choices"] count];
    }
    
    // should never reach here
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    id sect = self.sections[section];
    
    if ([sect respondsToSelector:@selector(objectForKeyedSubscript:)] && [sect[@"type"] isEqualToString:@"list"]) {
        return sect[@"label"];
    }
    else {
        return nil;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.checkingLogin) {
        return 88;
    } else {
        
        id sect = self.sections[indexPath.section];
        // regular field section
        if ([sect isKindOfClass:[NSArray class]]) {
            id field = sect[indexPath.row];
            if ([field[@"type"] isEqualToString:@"textarea"]) {
                return 200;
            } else if ([field[@"type"] isEqualToString:@"date"]) {
                return 252;
            }
        }
        
        
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
    backView.backgroundColor = [UIColor clearColor];
    cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.checkingLogin) {
        UITableViewCell *cell = [[NSBundle mainBundle] loadNibNamed:@"CheckingLoginView" owner:self.tableView options:0][0];
        return cell;
    }
    
    UITableViewCell *cell = self.indexPathToCell[indexPath];
    if (cell != nil) {
        return cell;
    }
    
    id sect = self.sections[indexPath.section];
    
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; // no reuse of cells allowed

    
    // regular field section
    if ([sect isKindOfClass:[NSArray class]]) {
        id field = sect[indexPath.row];
        
        UIView *view;
        UILabel *label;
        UITextField *textField;
        
        if ([@[@"email", @"name", @"text", @"number"] containsObject:field[@"type"]]) {
            view = [[NSBundle mainBundle] loadNibNamed:@"TextCellView" owner:nil options:nil][0];
            label = view.subviews[0];
            textField = view.subviews[1];
            
            label.text = field[@"label"];
            if (field[@"placeholder"] && field[@"placeholder"] != [NSNull null]) {
                textField.placeholder = field[@"placeholder"];
            } else textField.placeholder = nil;
            
            
            if ([field[@"type"] isEqualToString:@"email"])
                textField.keyboardType = UIKeyboardTypeEmailAddress;
            else if ([field[@"type"] isEqualToString:@"name"])
                textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            else if ([field[@"type"] isEqualToString:@"number"])
                textField.keyboardType = UIKeyboardTypeNumberPad;
            
            [cell.contentView addSubview:view];
        }
        else if ([field[@"type"] isEqualToString:@"textarea"]) {
            cell = [[NSBundle mainBundle] loadNibNamed:@"TextAreaView" owner:self.tableView options:0][0];
            label = (UILabel*)[cell viewWithTag:1];
            label.text = field[@"label"];
        }
        else if ([field[@"type"] isEqualToString:@"date"]) {
            cell = [[NSBundle mainBundle] loadNibNamed:@"DateCellView" owner:self.tableView options:0][0];
            label = (UILabel*)[cell viewWithTag:1];
            label.text = field[@"label"];
        }
        else if ([field[@"type"] isEqualToString:@"password"]) {
            view = [[NSBundle mainBundle] loadNibNamed:@"PasswordCellView" owner:nil options:nil][0];
            label = view.subviews[0];
            textField = view.subviews[1];
            
            label.text = field[@"label"];
            textField.placeholder = field[@"placeholder"];
            
            // hook up "show password" button
            UIButton *button = view.subviews[2];
            [button addTarget:self action:@selector(showPassword:) forControlEvents:UIControlEventTouchUpInside];
            
            [cell.contentView addSubview:view];
        }
        else if ([field[@"type"] isEqualToString:@"options"]) {
            view = [[NSBundle mainBundle] loadNibNamed:@"OptionCellView" owner:nil options:nil][0];
            label = view.subviews[0];
            UISegmentedControl *seg = view.subviews[1];
            
            label.text = field[@"label"];
            [seg removeAllSegments];
            for (id choice in field[@"choices"]) {
                [seg insertSegmentWithTitle:choice[@"label"] atIndex:[seg numberOfSegments] animated:NO];
            }
            
            [cell.contentView addSubview:view];
        }
        else if ([field[@"type"] isEqualToString:@"checkbox"]) {
            view = [[NSBundle mainBundle] loadNibNamed:@"CheckboxView" owner:nil options:nil][0];
            label = view.subviews[0];
            label.text = field[@"label"];
            if ([field[@"checked"] boolValue]) {
                UISwitch *checkbox = (UISwitch*)[view viewWithTag:2];
                [checkbox setOn:YES];
            }
            [cell.contentView addSubview:view];
        }
        else if ([field[@"type"] isEqualToString:@"forgot_password"]) {
            view = [[NSBundle mainBundle] loadNibNamed:@"ForgotPasswordView" owner:nil options:nil][0];
            UIButton *button = view.subviews[0];
            [button addTarget:self action:@selector(forgotPassword) forControlEvents:UIControlEventTouchUpInside];
            [cell.contentView addSubview:view];
        }
        else {
            cell.textLabel.text = field[@"label"];
        }
        
        // if this section has a text field, then hook up action
        if (textField != nil) {
            [textField addTarget:self action:@selector(finishedEditingField:) forControlEvents:UIControlEventEditingDidEndOnExit];
            
            // if next field is a text field, then make the return key "next"
            if ([sect count] > indexPath.row + 1 && [@[@"email", @"name", @"text", @"number", @"password"] containsObject:sect[indexPath.row+1][@"type"]]) {
                textField.returnKeyType = UIReturnKeyNext;
            }
            
            // if field is required, then auto-enable return key
            if (field[@"required"] && field[@"required"] != [NSNull null] && [field[@"required"] boolValue]) {
                textField.enablesReturnKeyAutomatically = YES;
            }
        }
    }
    // list section
    else if ([sect[@"type"] isEqualToString:@"list"]) {
        UIView *view = [[NSBundle mainBundle] loadNibNamed:@"ListCellView" owner:nil options:nil][0];
        UILabel *label = view.subviews[0];
        
        label.text = sect[@"choices"][indexPath.row][@"label"];
        [cell.contentView addSubview:view];
    }
    
    // add to dictionary to keep strong reference
    [self.indexPathToCell setObject:cell forKey:indexPath];
    
    return cell;
}

#pragma mark - Table View Delegate
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id sect = self.sections[indexPath.section];
    
    // for regular fields, start editing textview, or toggle checkbox
    if ([sect isKindOfClass:[NSArray class]]) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        UIView *innerView = cell.contentView.subviews[0];
        
        // input text field
        if (innerView.subviews.count >= 2 && [innerView.subviews[1] isKindOfClass:[UITextField class]] && [innerView.subviews[1] isEnabled]) {
            
            UITextField *field = (UITextField*) innerView.subviews[1];
            [field becomeFirstResponder];
        }
        // checkbox
        else if (innerView.subviews.count >= 2 && [innerView.subviews[1] isKindOfClass:[UISwitch class]]){
            UISwitch *theSwitch = (UISwitch*) innerView.subviews[1];
            [theSwitch setOn:!theSwitch.on animated:YES];
        }
    }
    
    // for list fields, select from option
    else if ([sect[@"type"] isEqualToString:@"list"]){
        UITableViewCell *cell;
        
        if ([sect[@"selection"] isEqualToString:@"single"]) {
            // clear all other selections
            for (int i = 0; i < [self tableView:self.tableView numberOfRowsInSection:indexPath.section]; i++) {
                cell = [self tableView:self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:indexPath.section]];
                
                if (i == indexPath.row) {
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                }
                else {
                    cell.accessoryType = UITableViewCellAccessoryNone;
                }
            }

        }
        else if ([sect[@"selection"] isEqualToString:@"multiple"]) {
            cell = [self tableView:self.tableView cellForRowAtIndexPath:indexPath];
            if (cell.accessoryType == UITableViewCellAccessoryNone)
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            else
                cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    
    return nil;
}

- (void)webviewFailedWithError:(NSError*)error
{
    NSLog(@"Form failed to load with error: %@", error);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[UIAlertView alloc] initWithTitle:@"Error with form" message:@"Please check your internet connection and try again" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
    });
}

- (void)webviewFinishedOnUrl:(NSURL*)url
{
    // detect and add jquery if necessary
    [LEANUtilities addJqueryToWebView:self.hiddenWebView];
    [LEANUtilities addJqueryToWebView:self.hiddenWkWebview];
    
    BOOL success = NO;
    
    // if redirected to different page, then we are done
    if (![url matchesPathOf:self.formUrl] && ![url matchesPathOf:self.errorUrl] && ![url matchesPathOf:self.passwordResetUrl]) {
        success = YES;
    }
    
    if (self.submitted){
        if ([url matchesPathOf:self.errorUrl]) {
            if (self.hiddenWebView) {
                NSString *message;
                if (self.json[@"errorSelector"]) {
                    message = [self.hiddenWebView stringByEvaluatingJavaScriptFromString: [NSString stringWithFormat:@"jQuery(%@).html();", [LEANUtilities jsWrapString:self.json[@"errorSelector"]]]];
                    message = [LEANUtilities stripHTML:message replaceWith:@" "];
                    message = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                }
                
                if (!message || [message length] == 0) {
                    message = kGenericErrorMessage;
                }
                
                // show error
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[[UIAlertView alloc] initWithTitle:self.title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
                });
                self.submitted = NO;
                self.submitButton.enabled = YES;
            } else if (self.hiddenWkWebview) {
                if (self.json[@"errorSelector"]) {
                    [self.hiddenWkWebview evaluateJavaScript:[NSString stringWithFormat:@"jQuery(%@).html();", [LEANUtilities jsWrapString:self.json[@"errorSelector"]]] completionHandler:^(id result, NSError *error) {
                        
                        self.submitted = NO;
                        self.submitButton.enabled = YES;
                        
                        if (result && [result isKindOfClass:[NSString class]]) {
                            NSString *message = result;
                            message = [LEANUtilities stripHTML:message replaceWith:@" "];
                            message = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[[UIAlertView alloc] initWithTitle:self.title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
                            });
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[[UIAlertView alloc] initWithTitle:self.title message:kGenericErrorMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
                            });
                        }
                    }];
                } else {
                    self.submitted = NO;
                    self.submitButton.enabled = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[[UIAlertView alloc] initWithTitle:self.title message:kGenericErrorMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
                    });
                }
            }
        }
        else {
            // success
            success = YES;
        }
    }
    
    if (success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [LEANPushManager sharedManager].userID = self.tempUserID;
            
            [self.checkSubmissionTimer invalidate];
            self.checkSubmissionTimer = nil;
            [self.hiddenWebView stopLoading];
            [self.hiddenWkWebview stopLoading];
            [self dismiss];
            
            // load url in main view
            if ([self.originatingViewController isKindOfClass:[LEANWebViewController class]]) {
                LEANWebViewController *wv = (LEANWebViewController*)self.originatingViewController;
                if (self.json[@"successUrl"] && self.json[@"successUrl"] != [NSNull null]) {
                    [wv loadUrl:[NSURL URLWithString:self.json[@"successUrl"]]];
                } else {
                    [wv loadUrl:url];
                }
            }
            
            // update menu
            [[LEANLoginManager sharedManager] checkIfNotAlreadyChecking];
        });
    }

}

#pragma mark - Web View Delegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self webviewFailedWithError:error];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self webviewFinishedOnUrl:webView.request.URL];
}

#pragma mark wkwebview delegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self webviewFinishedOnUrl:webView.URL];
}

@end
