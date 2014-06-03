//
//  LEANWebViewController.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//


#import "LEANWebViewController.h"
#import "LEANAppDelegate.h"
#import "LEANUtilities.h"
#import "LEANAppConfig.h"
#import "LEANMenuViewController.h"
#import "LEANNavigationController.h"
#import "LEANRootViewController.h"
#import "LEANWebFormController.h"
#import "NSURL+LEANUtilities.h"
#import "LEANCustomAction.h"
#import "LEANUrlInspector.h"
#import "LEANProfilePicker.h"

@interface LEANWebViewController () <UISearchBarDelegate, UIActionSheetDelegate, UIScrollViewDelegate>

@property IBOutlet UIBarButtonItem* backButton;
@property IBOutlet UIBarButtonItem* forwardButton;
@property IBOutlet UINavigationItem* nav;
@property IBOutlet UIBarButtonItem* navButton;
@property IBOutlet UIActivityIndicatorView *activityIndicator;
@property NSArray *defaultToolbarItems;
@property UIBarButtonItem *customActionButton;
@property NSArray *customActions;
@property UIBarButtonItem *searchButton;
@property UISearchBar *searchBar;

@property BOOL willBeLandscape;

@property NSURLRequest *currentRequest;
@property NSString *profilePickerJs;
@property NSTimer *timer;
@property BOOL startedLoading; // for transitions

@property BOOL visitedLoginOrSignup;

@end

@implementation LEANWebViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.checkLoginSignup = YES;
    
    // push login controller if it should be the first thing shown
    if ([LEANAppConfig sharedAppConfig].loginIsFirstPage) {
        LEANWebFormController *wfc = [[LEANWebFormController alloc]
                                      initWithJsonResource:@"login_config"
                                      formUrl:[LEANAppConfig sharedAppConfig].loginURL
                                      errorUrl:[LEANAppConfig sharedAppConfig].loginURLfail
                                      title:[LEANAppConfig sharedAppConfig][@"appName"] isLogin:YES];
        [self.navigationController pushViewController:wfc animated:NO];
    }
    
    // set title
    self.navigationItem.title = [LEANAppConfig sharedAppConfig][@"appName"];
    
    // configure zoomability
    self.webview.scalesPageToFit = [LEANAppConfig sharedAppConfig].allowZoom;
    
    // hide button if no native nav
    if (![[LEANAppConfig sharedAppConfig][@"checkNativeNav"] boolValue]) {
        self.navButton.customView = [[UIView alloc] init];
    }
    
    // profile picker
    if ([[LEANAppConfig sharedAppConfig] hasKey:@"profilePickerJS"] && [[LEANAppConfig sharedAppConfig][@"profilePickerJS"] length] > 0) {
        self.profilePickerJs = [LEANAppConfig sharedAppConfig][@"profilePickerJS"];
        self.profilePicker = [[LEANProfilePicker alloc] init];
    }
    
    
    self.visitedLoginOrSignup = NO;
    
	// set self as webview delegate to handle start/end load events
    self.webview.delegate = self;
    
    // load initial url
    LEANAppConfig *appConfig = [LEANAppConfig sharedAppConfig];
    [self loadUrl:appConfig.initialURL];
    
    //    self.webview.scrollView.contentInset = UIEdgeInsetsMake(-60, 0, 0, 0);
    self.webview.scrollView.bounces = NO;
    
    if ([LEANAppConfig sharedAppConfig][@"searchTemplateURL"]) {
        self.searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchPressed:)];
        self.searchBar = [[UISearchBar alloc] init];
        self.searchBar.showsCancelButton = YES;
        self.searchBar.delegate = self;
    }
    
    [self showNavigationItemButtons];
    [self buildDefaultToobar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:![LEANAppConfig sharedAppConfig].showNavigationBar animated:YES];
}

- (void) buildDefaultToobar
{
    NSMutableArray *array = [self.toolbarItems mutableCopy];
    
    if ([LEANAppConfig sharedAppConfig].showShareButton) {
        UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(buttonPressed:)];
        shareButton.tag = 3;
        [array addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
        [array addObject:shareButton];
    }
    self.defaultToolbarItems = array;
    [self setToolbarItems:array animated:NO];
}

- (void) updateCustomActions
{
    // get custom actions
    self.customActions = [LEANCustomAction actionsForUrl:[[self.webview request] URL]];
   
    if ([self.customActions count] == 0) {
        // remove button
        [self setToolbarItems:self.defaultToolbarItems animated:YES];
        self.customActionButton = nil;
    } else {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        [button addTarget:self action:@selector(showCustomActions:) forControlEvents:UIControlEventTouchUpInside];
        
        self.customActionButton = [[UIBarButtonItem alloc] initWithCustomView:button];
        
        NSMutableArray *array = [self.defaultToolbarItems mutableCopy];
        [array addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
        [array addObject:self.customActionButton];
        [self setToolbarItems:array animated:YES];
    }
}

- (void)showCustomActions:(id)sender
{
    
    /*
    LEANCustomActionController *controller = [[LEANCustomActionController alloc] init];
    controller.view.opaque = NO;
    
    // fade in
    controller.view.alpha = 0.0;
    [self.view addSubview:controller.view];
    [UIView animateWithDuration:0.4 animations:^{
        controller.view.alpha = 1.0;
    }];

    [self.navigationController setToolbarHidden:YES animated:YES]; */
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    for (LEANCustomAction* action in self.customActions) {
        [actionSheet addButtonWithTitle:action.name];
    }
    actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:@"Cancel"];
    
    actionSheet.delegate = self;
    
    [actionSheet showFromBarButtonItem:self.customActionButton animated:YES];
}

- (IBAction) buttonPressed:(id)sender
{
    switch ((long)[((UIBarButtonItem*) sender) tag]) {
        case 1:
            // back
            if (self.webview.canGoBack)
                [self.webview goBack];
            break;
            
        case 2:
            // forward
            if (self.webview.canGoForward)
                [self.webview goForward];
            break;
            
        case 3:
            //action
            [self sharePage];
            break;
            
        case 4:
            //search
            NSLog(@"search");
            break;
            
        case 5:
            //refresh
            if ([self.webview.request URL] && ![[[self.webview.request URL] absoluteString] isEqualToString:@""]) {
                [self.webview reload];
            }
            else {
                [self loadRequest:self.currentRequest];
            }
            break;
        
        default:
            break;
    }
    
}

- (void) searchPressed:(id)sender
{
    self.navigationItem.titleView = self.searchBar;
    [self.navigationItem setLeftBarButtonItems:nil animated:YES];
    [self.navigationItem setRightBarButtonItems:nil animated:YES];
    [self.searchBar becomeFirstResponder];
}

- (void) showNavigationItemButtons
{
    // left: navigation button
    [self.navigationItem setLeftBarButtonItem:self.navButton animated:YES];
    
    NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:2];
    
    // right: search button
    if (self.searchButton) {
        [buttons addObject:self.searchButton];
    }
    
    // right: chromecast button
    LEANAppDelegate *appDelegate = (LEANAppDelegate*)[[UIApplication sharedApplication] delegate];
    if (appDelegate.castController.castButton && !appDelegate.castController.castButton.customView.hidden) {
        [buttons addObject:appDelegate.castController.castButton];
    }
    
    [self.navigationItem setRightBarButtonItems:buttons animated:YES];
}

- (void) sharePage
{
    UIActivityViewController * avc = [[UIActivityViewController alloc]
                                      initWithActivityItems:@[[self.webview.request URL]] applicationActivities:nil];
    
    [self presentViewController:avc animated:YES completion:nil];
    
}

- (void) logout
{
    [self.webview stopLoading];
    
    // clear cookies
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // load initial page
    [self loadUrl:[LEANAppConfig sharedAppConfig].initialURL];
    
    [(LEANMenuViewController*)self.frostedViewController.menuViewController updateMenu:NO];
    
//    [self.webview stringByEvaluatingJavaScriptFromString:
//     [NSString stringWithFormat: @"jQuery('a.logout').click();"]];

}

- (IBAction) showMenu
{
    [self.frostedViewController presentMenuViewController];
}

- (void) loadUrl:(NSURL *)url
{
    [self hideWebview];
    [self.webview loadRequest:[NSURLRequest requestWithURL:url]];
}


- (void) loadRequest:(NSURLRequest*) request
{
    [self hideWebview];
    [self.webview loadRequest:request];
}

- (void) runJavascript:(NSString *) script
{
    [self.webview stringByEvaluatingJavaScriptFromString:script];
}

#pragma mark - Search Bar Delegate
- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // the default url character does not escape '/', so use this function. NSString is toll-free bridged with CFStringRef
    NSString *searchText = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)searchBar.text,NULL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",kCFStringEncodingUTF8 ));
    // the search template can have any allowable url character, but we need to escape unicode characters like '✓' so that the NSURL creation doesn't die.
    NSString *searchTemplate = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)[LEANAppConfig sharedAppConfig][@"searchTemplateURL"],(CFStringRef)@"!*'();:@&=+$,/?%#[]",NULL,kCFStringEncodingUTF8 ));
    NSURL *url = [NSURL URLWithString:[searchTemplate stringByAppendingString:searchText]];
    [self loadUrl:url];
    
    self.navigationItem.titleView = nil;
    [self showNavigationItemButtons];
}

- (void) searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    self.navigationItem.titleView = nil;
    [self showNavigationItemButtons];
}


#pragma mark - UIWebViewDelegate
- (BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = [request URL];
    NSString* hostname = [url host];
    
//    NSLog(@"should start load %d %@", navigationType, url);
    
    [[LEANUrlInspector sharedInspector] inspectUrl:url];
    
    // check redirects
    if ([LEANAppConfig sharedAppConfig].redirects != nil) {
        NSString *to = [[LEANAppConfig sharedAppConfig].redirects valueForKey:[url absoluteString]];
        if (to) {
            url = [NSURL URLWithString:to];
            
//            [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:to]]];
//            return false;
        }
    }
    
    // log out by clearing cookies
    if ([[url absoluteString] caseInsensitiveCompare:@"file://gonative_logout"] == NSOrderedSame) {
        [self logout];
        return false;
    }
    
    // checkLoginSignup might be NO when returning from login screen with loginIsFirstPage
    BOOL checkLoginSignup = self.checkLoginSignup;
    self.checkLoginSignup = YES;
    
    // log in
    if (checkLoginSignup && [[LEANAppConfig sharedAppConfig][@"checkNativeLogin"] boolValue] &&
        [url matchesPathOf:[LEANAppConfig sharedAppConfig].loginURL]) {
        [self showWebview];
        
        if ([LEANAppConfig sharedAppConfig].loginIsFirstPage) {
            if (self.webview.request) {
                // this is not the first page loaded, so was probably called via Logout.
                
                // recheck status as it has probably changed
                [[LEANLoginManager sharedManager] checkLogin];
                
                LEANWebFormController *wfc = [[LEANWebFormController alloc]
                                              initWithJsonResource:@"login_config"
                                              formUrl:[LEANAppConfig sharedAppConfig].loginURL
                                              errorUrl:[LEANAppConfig sharedAppConfig].loginURLfail
                                              title:[LEANAppConfig sharedAppConfig][@"appName"] isLogin:YES];
                [self.navigationController pushViewController:wfc animated:YES];
            } else {
                // this is the first page loaded, which means that the form controller has already been pushed in viewDidLoad. Do nothing.
            }
            
            return NO;
        }
        
        LEANWebFormController *wfc = [[LEANWebFormController alloc]
                                      initWithJsonResource:@"login_config"
                                      formUrl:[LEANAppConfig sharedAppConfig].loginURL
                                      errorUrl:[LEANAppConfig sharedAppConfig].loginURLfail
                                      title:@"Log In" isLogin:YES];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UINavigationController *formSheet = [[UINavigationController alloc] initWithRootViewController:wfc];
            formSheet.modalPresentationStyle = UIModalPresentationFormSheet;
            [self presentViewController:formSheet animated:YES completion:nil];
        } else {
            [self.navigationController pushViewController:wfc animated:YES];
        }
        return NO;
    }
    
    // sign up
    if (checkLoginSignup && [[LEANAppConfig sharedAppConfig][@"checkNativeSignup"] boolValue] &&
        [url matchesPathOf:[LEANAppConfig sharedAppConfig].signupURL]) {
        [self showWebview];

        LEANWebFormController *wfc = [[LEANWebFormController alloc]
                                      initWithJsonResource:@"signup_config"
                                      formUrl:[LEANAppConfig sharedAppConfig].signupURL
                                      errorUrl:[LEANAppConfig sharedAppConfig].signupURLfail
                                      title:@"Sign Up" isLogin:NO];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UINavigationController *formSheet = [[UINavigationController alloc] initWithRootViewController:wfc];
            formSheet.modalPresentationStyle = UIModalPresentationFormSheet;
            [self presentViewController:formSheet animated:YES completion:nil];
        }
        else {
            [self.navigationController pushViewController:wfc animated:YES];
        }
        return NO;
    }
    
    // twitter app
    if ([hostname isEqualToString:@"twitter.com"] && [[[request URL] path] isEqualToString:@"/intent/tweet"])
    {
        NSDictionary* dict = [LEANUtilities dictionaryFromQueryString:[[request URL] query]];
        
        NSURL* url = [NSURL URLWithString:
                      [LEANUtilities addQueryStringToUrlString:@"twitter://post?"
                                                withDictionary:@{@"message": [NSString stringWithFormat:@"%@ %@ @%@",
                                                                              dict[@"text"],
                                                                              dict[@"url"],
                                                                              dict[@"via"]]}]];
        
        if ([[UIApplication sharedApplication] canOpenURL:url])
            [[UIApplication sharedApplication] openURL:url];
        else
            [[UIApplication sharedApplication] openURL:[request URL]];
        
        
        return NO;
    }
    
    // external sites
    if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        NSString *initialHost = [LEANAppConfig sharedAppConfig].initialHost;
        if (![hostname isEqualToString:initialHost] &&
            ![hostname hasSuffix:[@"." stringByAppendingString:initialHost]] &&
            ![[LEANAppConfig sharedAppConfig][@"internalHosts"] containsObject:hostname]) {
            // open in external web browser
            [[UIApplication sharedApplication] openURL:[request URL]];
            return NO;
        }
    }
    
    // save for reload
    self.currentRequest = request;
    // save for html interception
    ((LEANAppDelegate*)[[UIApplication sharedApplication] delegate]).currentRequest = request;
    
    // if not iframe and not loading the same page, hide the webview and show activity indicator.
    if (navigationType != UIWebViewNavigationTypeOther
        && [[[request URL] absoluteString] isEqualToString:[[request mainDocumentURL] absoluteString]]
        && ![[request URL] matchesPathOf:[[webView request] URL]]) {
        [self hideWebview];
    }
    
    [self setNavigationButtonStatus];
    
    return YES;
}

- (void) webViewDidStartLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self.customActionButton setEnabled:NO];
    
    LEANRootViewController *rootVC = (LEANRootViewController*)self.frostedViewController;
    // check orientation
    NSPredicate *forceLandscape = [LEANAppConfig sharedAppConfig].forceLandscapeMatch;
    if (forceLandscape && [forceLandscape evaluateWithObject:[[self.currentRequest URL] absoluteString]]) {
        [rootVC forceOrientations:UIInterfaceOrientationMaskLandscape];
    }
    else {
        [rootVC forceOrientations:UIInterfaceOrientationMaskAllButUpsideDown];
    }
    
    [self.timer invalidate];
    self.timer = [NSTimer timerWithTimeInterval:0.05 target:self selector:@selector(checkReadyStatus) userInfo:nil repeats:YES];
    [self.timer setTolerance:0.02];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void) webViewDidFinishLoad:(UIWebView *)webView
{
    // show the webview
    [self showWebview];
    
    NSURL *url = [webView.request URL];
    [[LEANUrlInspector sharedInspector] inspectUrl:url];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self setNavigationButtonStatus];
    
    [LEANUtilities addJqueryToWebView:webView];
    
    // update navigation title
    if ([[LEANAppConfig sharedAppConfig][@"useWebpageTitle"] boolValue]) {
        NSString *theTitle=[self.webview stringByEvaluatingJavaScriptFromString:@"document.title"];
        self.nav.title = theTitle;
    }
    
    // refresh menu if loading certain URLs
    NSArray *refreshURLs = [LEANAppConfig sharedAppConfig][@"menuRefreshURLs"];
    if ([refreshURLs containsObject:[url absoluteString]]) {
        [[LEANLoginManager sharedManager] checkLogin];
    }
    
    // need to update menu if previous page was login or signup
    if ([[LEANAppConfig sharedAppConfig][@"checkUserAuth"] boolValue]) {
        if (self.visitedLoginOrSignup) {
            [[LEANLoginManager sharedManager] checkLogin];
        }
        
        self.visitedLoginOrSignup = [url matchesPathOf:[LEANAppConfig sharedAppConfig].loginURL] ||
        [url matchesPathOf:[LEANAppConfig sharedAppConfig].signupURL];
    }
    
    // profile picker
    if (self.profilePickerJs) {
        NSString *json = [webView stringByEvaluatingJavaScriptFromString:self.profilePickerJs];
        [self.profilePicker parseJson:json];
        [(LEANMenuViewController*)self.frostedViewController.menuViewController showSettings:[self.profilePicker hasProfiles]];
    }
    
    
    // disable horizontal scrolling
    /*
     CGSize size = webView.scrollView.contentSize;
     size.width = webView.frame.size.width;
     webView.scrollView.contentSize = size;
     */
    
    if ([LEANAppConfig sharedAppConfig].enableChromecast) {
        [self detectVideo];
        // [self performSelector:@selector(detectVideo) withObject:nil afterDelay:1];
    }
    
    [self updateCustomActions];
}

- (void)checkReadyStatus
{
    NSString *status = [self.webview stringByEvaluatingJavaScriptFromString:@"document.readyState"];
    // we keep track of startedLoading because loading is only really finished when we have gone to
    // "loading" or "interactive" before going to complete. When the web page first starts loading,
    // it will be in "complete", then "loading", "interactive", and finally "complete".
    if ([status isEqualToString:@"loading"] || [status isEqualToString:@"interactive"]) {
        self.startedLoading = YES;
    }
    else if (self.startedLoading && [status isEqualToString:@"complete"]) {
        self.startedLoading = NO;
        [self.timer invalidate];
        self.timer = nil;
        [self showWebview];
    }
}

- (void)hideWebview
{
    self.webview.alpha = 0.0;
    self.webview.userInteractionEnabled = NO;
    self.activityIndicator.alpha = 1.0;
    [self.activityIndicator startAnimating];
}

- (void)showWebview
{
    self.startedLoading = NO;
    [self.timer invalidate];
    self.timer = nil;
    
    self.webview.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^(void){
        self.webview.alpha = 1.0;
        self.activityIndicator.alpha = 0.0;
    } completion:^(BOOL finished){
        [self.activityIndicator stopAnimating];
    }];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

    [self showWebview];
    
    if ([[error domain] isEqualToString:@"NSURLErrorDomain"] && [error code] == -1009) {
        [[[UIAlertView alloc] initWithTitle:@"No connection" message:@"The internet connection appears to be offline" delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles: nil] show];
    }
}

- (void)detectVideo
{
    NSString *dataurl = [self.webview stringByEvaluatingJavaScriptFromString:
                         @"jwplayer().config.fallbackDiv.getAttribute('data-url_alt');"];
    NSURL *url;
    NSString *title;
    if (dataurl && ![dataurl isEqualToString:@""]) {
        url = [NSURL URLWithString:dataurl relativeToURL:[self.webview.request URL]];
        title = [self.webview stringByEvaluatingJavaScriptFromString:
                 @"jwplayer().config.fallbackDiv.getAttribute('data-title');"];
    }
    
    LEANAppDelegate *appDelegate = (LEANAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.castController.urlToPlay = url;
    appDelegate.castController.titleToPlay = title;
}

- (void) setNavigationButtonStatus
{
    self.backButton.enabled = self.webview.canGoBack;
    self.forwardButton.enabled = self.webview.canGoForward;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action Sheet Delegate
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex < [self.customActions count]) {
        LEANCustomAction *action = self.customActions[buttonIndex];
        [self.webview stringByEvaluatingJavaScriptFromString:action.javascript];
    }
}

#pragma mark - Scroll View Delegate

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView.contentOffset.y > 0) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [self.navigationController setToolbarHidden:YES animated:YES];
        [scrollView setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
        
    } else {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
        [self.navigationController setToolbarHidden:NO animated:YES];
        [scrollView setContentInset:UIEdgeInsetsMake(64, 0, 44, 0)];
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.willBeLandscape = toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)prefersStatusBarHidden
{
    return self.willBeLandscape;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

@end
