//
//  LEANWebViewController.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <MessageUI/MessageUI.h>
#import <CoreLocation/CoreLocation.h>
#import <PassKit/PassKit.h>

#import <OneSignal/OneSignal.h>

#import "LEANWebViewController.h"
#import "LEANAppDelegate.h"
#import "LEANUtilities.h"
#import "GNCustomHeaders.h"
#import "GoNativeAppConfig.h"
#import "LEANMenuViewController.h"
#import "LEANNavigationController.h"
#import "LEANRootViewController.h"
#import "NSURL+LEANUtilities.h"
#import "LEANUrlInspector.h"
#import "LEANProfilePicker.h"
#import "LEANInstallation.h"
#import "LEANTabManager.h"
#import "LEANToolbarManager.h"
#import "LEANWebViewPool.h"
#import "LEANDocumentSharer.h"
#import "Reachability.h"
#import "LEANActionManager.h"
#import "GNRegistrationManager.h"
#import "LEANWebViewIntercept.h"
#import "Subscriptions/GNSubscriptionsController.h"
#import "GNConfigPreferences.h"
#import "GonativeIO-Swift.h"

@interface LEANWebViewController () <UISearchBarDelegate, UIActionSheetDelegate, UIScrollViewDelegate, UITabBarDelegate, WKNavigationDelegate, WKUIDelegate, MFMailComposeViewControllerDelegate, CLLocationManagerDelegate>

@property IBOutlet UIWebView* webview;
@property WKWebView *wkWebview;

@property IBOutlet UIBarButtonItem* backButton;
@property IBOutlet UIBarButtonItem* forwardButton;
@property IBOutlet UINavigationItem* nav;
@property IBOutlet UIBarButtonItem* navButton;
@property IBOutlet UIActivityIndicatorView *activityIndicator;
@property IBOutlet UITabBar *tabBar;
@property IBOutlet UIToolbar *toolbar;
@property IBOutlet NSLayoutConstraint *tabBarBottomConstraint;
@property IBOutlet NSLayoutConstraint *toolbarBottomConstraint;
@property NSArray *defaultLeftNavBarItems;
@property NSArray *defaultToolbarItems;
@property UIBarButtonItem *customActionButton;
@property NSArray *customActions;
@property UIBarButtonItem *searchButton;
@property UISearchBar *searchBar;
@property UIView *statusBarBackground;
@property UIBarButtonItem *shareButton;
@property UIBarButtonItem *refreshButton;
@property UIRefreshControl *pullRefreshControl;

@property BOOL keyboardVisible;
@property CGRect keyboardRect; // in window coordinates

@property NSURLRequest *currentRequest;
@property NSInteger urlLevel; // -1 for unknown
@property NSString *profilePickerJs;
@property NSTimer *timer;
@property BOOL startedLoading; // for transitions, keeps track of whether document.readystate has switched to "loading"
@property BOOL didLoadPage; // keep track of whether any page has loaded. If network reconnects, then will attempt reload if there is no page loaded
@property BOOL isPoolWebview;
@property UIView *defaultTitleView;
@property UIView *navigationTitleImageView;
@property CGFloat hideWebviewAlpha;
@property BOOL statusBarOverlay;

@property NSString *postLoadJavascript;
@property NSString *postLoadJavascriptForRefresh;

@property (nonatomic, copy) void (^locationPermissionBlock)(void);

@property BOOL visitedLoginOrSignup;

@property LEANActionManager *actionManager;
@property LEANToolbarManager *toolbarManager;
@property CLLocationManager *locationManager;
@property NSString *connectivityCallback;
@property BOOL javascriptTabs;

@property NSNumber* statusBarStyle; // set via native bridge, only works if no navigation bar
@property IBOutlet NSLayoutConstraint *topGuideConstraint; // modify constant to place content under status bar

@end

@implementation LEANWebViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.checkLoginSignup = YES;
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    
    self.hideWebviewAlpha = [appConfig.hideWebviewAlpha floatValue];
    self.statusBarOverlay = NO;
    
    self.tabManager = [[LEANTabManager alloc] initWithTabBar:self.tabBar webviewController:self];
    self.javascriptTabs = NO;
    self.toolbarManager = [[LEANToolbarManager alloc] initWithToolbar:self.toolbar webviewController:self];
    
    // set title to application title
    if ([appConfig.navTitles count] == 0) {
        self.navigationItem.title = appConfig.appName;
    }
    
    // dark theme
    if ([appConfig.iosTheme isEqualToString:@"dark"]) {
        self.view.backgroundColor = [UIColor blackColor];
        self.tabBar.barStyle = UIBarStyleBlack;
        self.toolbar.barStyle = UIBarStyleBlack;
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
        self.tabBar.barStyle = UIBarStyleDefault;
        self.toolbar.barStyle = UIBarStyleDefault;
    }
    
    // configure zoomability
    self.webview.scalesPageToFit = appConfig.allowZoom;
    
    // hide button if no native nav
    if (!appConfig.showNavigationMenu) {
        self.navButton.customView = [[UIView alloc] init];
    }
    
    // add nav button
    if (appConfig.showNavigationMenu &&  [self isRootWebView]) {
        self.navButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"navImage"] style:UIBarButtonItemStylePlain target:self action:@selector(showMenu)];
        self.navigationItem.leftBarButtonItems = @[self.navButton];
    }
    self.defaultLeftNavBarItems = self.navigationItem.leftBarButtonItems;
    
    // profile picker
    if (appConfig.profilePickerJS && [appConfig.profilePickerJS length] > 0) {
        self.profilePickerJs = appConfig.profilePickerJS;
    }
    
    self.visitedLoginOrSignup = NO;
    
    if (self.initialWebview) {
        [self switchToWebView:self.initialWebview showImmediately:YES];
        self.initialWebview = nil;
        
        // nav title image
        [self checkNavigationTitleImageForUrl:self.wkWebview.URL];
        
    } else {
        // switch to wkwebview if on ios8
        if (appConfig.useWKWebView) {
            WKWebViewConfiguration *config = [[NSClassFromString(@"WKWebViewConfiguration") alloc] init];
            config.processPool = [LEANUtilities wkProcessPool];
            WKWebView *wv = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:self.webview.frame configuration:config];
            [LEANUtilities configureWebView:wv];
            [self switchToWebView:wv showImmediately:NO];
        } else {
            // set self as webview delegate to handle start/end load events
            self.webview.delegate = self;
            [LEANUtilities configureWebView:self.webview];
        }
        
        // load initial url
        self.urlLevel = -1;
        if (!self.initialUrl) {
            NSString *initialUrlPref = [[GNConfigPreferences sharedPreferences] getInitialUrl];
            if (initialUrlPref && initialUrlPref.length > 0) {
                self.initialUrl = [NSURL URLWithString:initialUrlPref];
                [[GNConfigPreferences sharedPreferences] setInitialUrl:initialUrlPref];
            }
        }
        if (!self.initialUrl && appConfig.initialURL) {
            self.initialUrl = appConfig.initialURL;
        }
        [self loadUrl:self.initialUrl];
        
        // nav title image
        [self checkNavigationTitleImageForUrl:self.initialUrl];

    }
    
    // hidden nav bar
    if (!appConfig.showNavigationBar && [self isRootWebView]) {
        UIToolbar *bar = [[UIToolbar alloc] init];
        if ([appConfig.iosTheme isEqualToString:@"dark"]) {
            bar.barStyle = UIBarStyleBlack;
        }
        self.statusBarBackground = bar;
        [self.view addSubview:self.statusBarBackground];
    }
    
    if (appConfig.searchTemplateURL) {
        self.searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchPressed:)];
        self.searchBar = [[UISearchBar alloc] init];
        self.searchBar.showsCancelButton = NO;
        self.searchBar.delegate = self;
    }
    
    if (appConfig.showRefreshButton) {
        self.refreshButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"refresh"] style:UIBarButtonItemStylePlain target:self action:@selector(refreshPressed:)];
    }
    
    [self showNavigationItemButtonsAnimated:NO];
    [self buildDefaultToobar];
    self.keyboardVisible = NO;
    self.keyboardRect = CGRectZero;
    [self adjustInsets];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedTabNavigation object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedNavigationTitles object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kReachabilityChangedNotification object:nil];
    
    // keyboard change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardHidden:) name:UIKeyboardWillHideNotification object:nil];
    
    // to help fix status bar issues when rotating in full-screen video
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.wkWebview) {
        @try {
            [self.wkWebview removeObserver:self forKeyPath:@"URL"];
            [self.wkWebview removeObserver:self forKeyPath:@"canGoBack"];
        }
        @catch (NSException * __unused exception) {
        }
    }
}

- (void)didReceiveNotification:(NSNotification*)notification
{
    NSString *name = [notification name];
    if ([name isEqualToString:kLEANAppConfigNotificationProcessedTabNavigation]) {
        [self checkNavigationForUrl:self.currentRequest.URL];
    }
    else if ([name isEqualToString:UIApplicationDidBecomeActiveNotification]) {
        [self retryFailedPage];
    }
    else if ([name isEqualToString:kReachabilityChangedNotification]) {
        [self retryFailedPage];
        if (self.connectivityCallback) {
            NSDictionary *status = [self getConnectivity];
            NSString *js = [LEANUtilities createJsForCallback:self.connectivityCallback data:status];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self runJavascript:js];
            });
        }
    }
    else if ([name isEqualToString:kLEANAppConfigNotificationProcessedNavigationTitles]) {
        NSURL *url = nil;
        if (self.webview) url = self.webview.request.URL;
        else if (self.wkWebview) url = self.wkWebview.URL;
        
        if (url) {
            NSString *newTitle = [LEANWebViewController titleForUrl:url];
            if (newTitle) {
                self.navigationItem.title = newTitle;
            }
        }
    }
}

- (void)keyboardShown:(NSNotification*)notification
{
    NSDictionary* info = [notification userInfo];
    CGRect kbRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.keyboardRect = kbRect;
    self.keyboardVisible = YES;
    [self adjustInsets];
}

- (void)keyboardHidden:(NSNotification*)notification
{
    self.keyboardVisible = NO;
    [self adjustInsets];
}

- (void)retryFailedPage
{
    // return if we are not the top view controller
    if (![self isViewLoaded] || !self.view.window) return;
    
    // if there is a page loaded, user can just retry navigation
    if (self.didLoadPage) return;
    
    // return if currently loading a page
    if (self.webview && self.webview.loading) return;
    if (self.wkWebview && self.wkWebview.isLoading) return;
    
    NetworkStatus status = [((LEANAppDelegate*)[UIApplication sharedApplication].delegate).internetReachability currentReachabilityStatus];
    
    if (status != NotReachable && self.currentRequest) {
        NSLog(@"Networking reconnect. Retrying previous failed request.");
        [self loadRequest:self.currentRequest];
    }
}

- (void)addPullToRefresh
{
    if (!self.pullRefreshControl) {
        self.pullRefreshControl = [[UIRefreshControl alloc] init];
        [self.pullRefreshControl addTarget:self action:@selector(pullToRefresh:) forControlEvents:UIControlEventValueChanged];
        self.pullRefreshControl.tintColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
    }
    
    [self.wkWebview.scrollView addSubview:self.pullRefreshControl];
    [self.webview.scrollView addSubview:self.pullRefreshControl];
    
    self.wkWebview.scrollView.bounces = YES;
    self.webview.scrollView.bounces = YES;
}

- (void)removePullRefresh
{
    self.webview.scrollView.bounces = NO;
    self.wkWebview.scrollView.bounces = NO;
    [self.pullRefreshControl removeFromSuperview];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([GoNativeAppConfig sharedAppConfig].pullToRefresh) {
        [self addPullToRefresh];
    }
    
    if ([self isRootWebView]) {
        [self.navigationController setNavigationBarHidden:![GoNativeAppConfig sharedAppConfig].showNavigationBar animated:YES];
    } else if ([GoNativeAppConfig sharedAppConfig].showNavigationBarWithNavigationLevels) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    
    [self adjustInsets];
    
    NSURL *url = self.webview.request.URL;
    if (!url) {
        url = self.wkWebview.URL;
    }
    if (url) {
        [self checkNavigationForUrl:url];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.pullRefreshControl removeFromSuperview];
    
    if (self.isMovingFromParentViewController) {
        self.webview.delegate = nil;
        [self.webview stopLoading];
        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserFinishedLoading object:self];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }
    [super viewWillDisappear:animated];
}

- (void) buildDefaultToobar
{
    NSMutableArray *array = [self.toolbarItems mutableCopy];
    
    if ([GoNativeAppConfig sharedAppConfig].showShareButton) {
        UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(buttonPressed:)];
        shareButton.tag = 3;
        [array addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
        [array addObject:shareButton];
    }
    self.defaultToolbarItems = array;
    [self setToolbarItems:array animated:NO];
}

-(void)setSidebarEnabled:(BOOL)enabled
{
    if (![self isRootWebView]) return;
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    if (!appConfig.showNavigationMenu) return;
    
    LEANNavigationController *navController = (LEANNavigationController*)self.navigationController;
    [navController setSidebarEnabled:enabled];
    
    if (enabled) {
        self.navButton.customView = nil;
    } else {
        self.navButton.customView = [[UIView alloc] init];
        [navController.frostedViewController hideMenuViewController];
    }
}

- (void)checkPreNavigationForUrl:(NSURL*)url
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self checkNavigationTitleImageForUrl:url];
        if (!self.javascriptTabs) {
            [self.tabManager autoSelectTabForUrl:url];
        }
        
        GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
        [self setSidebarEnabled:[appConfig shouldShowSidebarForUrl:[url absoluteString]]];
    });
}

- (void)checkNavigationForUrl:(NSURL*) url;
{
    if (!self.javascriptTabs) {
        if (![GoNativeAppConfig sharedAppConfig].tabMenus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideTabBarAnimated:YES];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tabManager didLoadUrl:url];
            });
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.toolbarManager didLoadUrl:url];
    });
}

- (void)checkActionsForUrl:(NSURL*) url;
{
    if (!self.actionManager) {
        self.actionManager = [[LEANActionManager alloc] initWithWebviewController:self];
    }
    
    [self.actionManager didLoadUrl:url];
}

- (void)checkNavigationTitleImageForUrl:(NSURL*)url
{
    // show logo in navigation bar
    if ([[GoNativeAppConfig sharedAppConfig] shouldShowNavigationTitleImageForUrl:[url absoluteString]]) {
        // create the view if necesary
        if (!self.navigationTitleImageView) {
            UIImage *im = [GoNativeAppConfig sharedAppConfig].navigationTitleIcon;
            if (!im) im = [UIImage imageNamed:@"navbar_logo"];
            
            if (im) {
                CGRect bounds = CGRectMake(0, 0, 30 * im.size.width / im.size.height, 30);
                UIView *backView = [[UIView alloc] initWithFrame:bounds];
                UIImageView *iv = [[UIImageView alloc] initWithImage:im];
                iv.bounds = bounds;
                [backView addSubview:iv];
                iv.center = backView.center;
                self.navigationTitleImageView = backView;
            }
        }
        
        // set the view
        self.defaultTitleView = self.navigationTitleImageView;
        self.navigationItem.titleView = self.navigationTitleImageView;
    } else {
        self.defaultTitleView = nil;
        self.navigationItem.titleView = nil;
    }
}

- (void)hideTabBarAnimated:(BOOL)animated
{
    [self hideBottomBar:self.tabBar constraint:self.tabBarBottomConstraint animated:animated];
}

- (void)hideToolbarAnimated:(BOOL)animated
{
    [self hideBottomBar:self.toolbar constraint:self.toolbarBottomConstraint animated:animated];
}

- (void)showTabBarAnimated:(BOOL)animated
{
    [self showBottomBar:self.tabBar constraint:self.tabBarBottomConstraint animated:animated];
}

- (void)showToolbarAnimated:(BOOL)animated
{
    [self showBottomBar:self.toolbar constraint:self.toolbarBottomConstraint animated:animated];
}

- (void)showBottomBar:(UIView*)bar constraint:(NSLayoutConstraint*)constraint animated:(BOOL)animated
{
    if (!bar.hidden) return;
    
    [self.view layoutIfNeeded];
    bar.hidden = NO;
    constraint.constant = 0;
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^(void){
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            [self adjustInsets];
        }];
    } else {
        [self.view layoutIfNeeded];
        [self adjustInsets];
    }
}

- (void)hideBottomBar:(UIView*)bar constraint:(NSLayoutConstraint*)constraint animated:(BOOL)animated
{
    [self.view layoutIfNeeded];
    CGFloat barHeight = MIN(bar.bounds.size.width, bar.bounds.size.height);
    constraint.constant = -barHeight;

    if (bar.hidden) {
        [self.view layoutIfNeeded];
        return;
    }
    
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^(void){
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            bar.hidden = YES;
            [self adjustInsets];
        }];
    } else {
        [self.view layoutIfNeeded];
        bar.hidden = YES;
        [self adjustInsets];
    }
}

- (void)adjustInsets
{
    // This function used to adjust the content inset of the webview's scrollview, but we
    // have moved away from that strategy. Now we just let autolayout constraints resize
    // the webview frame, and set masksToBounds=false
}

- (void)applyStatusBarOverlay
{
    if (self.statusBarOverlay) {
        if (@available(iOS 11.0, *)) {
            // need a larger offset than 20 for iPhone X
            self.topGuideConstraint.constant = -self.view.safeAreaInsets.top;
        } else {
            self.topGuideConstraint.constant = -20.0;
        }
    } else {
        self.topGuideConstraint.constant = 0;
    }
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
            [self sharePageWithUrl:nil sender:sender];
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
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(searchCanceled)];
    
    [self.navigationItem setLeftBarButtonItems:nil animated:YES];
    [self.navigationItem setRightBarButtonItems:@[cancelButton] animated:YES];
    [self.searchBar becomeFirstResponder];
}

- (void) sharePressed:(UIBarButtonItem*)sender
{
    [[LEANDocumentSharer sharedSharer] shareRequest:self.currentRequest fromButton:sender];
}

- (void) showNavigationItemButtonsAnimated:(BOOL)animated
{
    //left
    [self.navigationItem setLeftBarButtonItems:self.defaultLeftNavBarItems animated:animated];
    
    NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:4];
    
    // right: actions
    if (self.actionManager) {
        [buttons addObjectsFromArray:self.actionManager.items];
    }
    
    // right: search button
    if (self.searchButton) {
        [buttons addObject:self.searchButton];
    }
    
    // right: refresh button
    if (self.refreshButton) {
        [buttons addObject:self.refreshButton];
    }
    
    // right: document share button
    if (self.shareButton) {
        [buttons addObject:self.shareButton];
    }
    
    
    [self.navigationItem setRightBarButtonItems:buttons animated:animated];
}

- (void) sharePage:(id)sender
{
    [self sharePageWithUrl:nil sender:sender];
}

- (void) sharePageWithUrl:(NSString*)url sender:(id)sender;
{
    NSURL *shareUrl;
    if (url) {
        shareUrl = [NSURL URLWithString:url relativeToURL:[self.currentRequest URL]];
    } else {
        shareUrl = [self.currentRequest URL];
    }
    
    UIActivityViewController * avc = [[UIActivityViewController alloc]
                                      initWithActivityItems:@[shareUrl] applicationActivities:nil];
    
    // For iPads starting in iOS 8, we need to specify where the pop over should occur from.
    if ( [avc respondsToSelector:@selector(popoverPresentationController)] ) {
        if ([sender isKindOfClass:[UIBarButtonItem class]]) {
            avc.popoverPresentationController.barButtonItem = sender;
        } else if ([sender isKindOfClass:[UIView class]]) {
            avc.popoverPresentationController.sourceView = sender;
        } else {
            avc.popoverPresentationController.sourceView = self.view;
        }
    }
    
    [self presentViewController:avc animated:YES completion:nil];
}

- (void)refreshPressed:(id)sender
{
    [self refreshPage];
}

-(void)pullToRefresh:(UIRefreshControl*) refresh
{
    [self refreshPage];
    [refresh endRefreshing];
}

- (void)refreshPage
{
    [self.wkWebview reload];
    [self.webview reload];
}

- (void) logout
{
    [self.webview stopLoading];
    [self.wkWebview stopLoading];
    // stop webview pools
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserStartedLoading object:self];
    [[LEANWebViewPool sharedPool] flushAll];
    // stop login detection
    [[LEANLoginManager sharedManager] stopChecking];
    
    // clear cookies
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // load initial page in bottom webview
    [self.navigationController popToRootViewControllerAnimated:NO];
    [self.navigationController.viewControllers[0] loadUrl:[GoNativeAppConfig sharedAppConfig].initialURL];
    
    [(LEANMenuViewController*)self.frostedViewController.menuViewController updateMenuWithStatus:@"default"];
}

- (IBAction) showMenu
{
    [self.frostedViewController presentMenuViewController];
}

- (BOOL)canGoBack
{
    if (self.webview) {
        return [self.webview canGoBack];
    } else if (self.wkWebview) {
        return [self.wkWebview canGoBack];
    } else {
        return NO;
    }
}

- (void)goBack
{
    if (self.webview && [self.webview canGoBack]) {
        [self.webview goBack];
    } else if (self.wkWebview && [self.wkWebview canGoBack]) {
        [self.wkWebview goBack];
    }
}

- (void) loadUrlString:(NSString*)url
{
    if ([url length] == 0) {
        return;
    }
    
    if ([url hasPrefix:@"javascript:"]) {
        NSString *js = [url substringFromIndex: [@"javascript:" length]];
        [self runJavascript:js];
    } else {
        [self loadUrl:[NSURL URLWithString:url]];
    }
}

- (void) loadUrl:(NSURL *)url
{
    [self loadRequest:[NSURLRequest requestWithURL:url]];
}


- (void) loadRequest:(NSURLRequest*) request
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserStartedLoading object:self];
    [self.webview loadRequest:request];
    [self.wkWebview loadRequest:request];
    self.postLoadJavascript = nil;
    self.postLoadJavascriptForRefresh = nil;
}

- (void) loadUrl:(NSURL *)url andJavascript:(NSString *)js
{
    NSURL *currentUrl = nil;
    if (self.webview) {
        currentUrl = self.webview.request.URL;
    } else if (self.wkWebview) {
        currentUrl = self.wkWebview.URL;
    }
    
    if ([[currentUrl absoluteString] isEqualToString:[url absoluteString]]) {
        [self hideWebview];
        [self runJavascript:js];
        self.postLoadJavascriptForRefresh = js;
        [self showWebview];
    } else {
        self.postLoadJavascript = js;
        self.postLoadJavascriptForRefresh = js;
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserStartedLoading object:self];
        [self.webview loadRequest:request];
        [self.wkWebview loadRequest:request];
    }
}

- (void) loadRequest:(NSURLRequest *)request andJavascript:(NSString*)js
{
    self.postLoadJavascript = js;
    self.postLoadJavascriptForRefresh = js;
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserStartedLoading object:self];
    [self.webview loadRequest:request];
    [self.wkWebview loadRequest:request];
}

- (void) runJavascript:(NSString *) script
{
    [self.webview stringByEvaluatingJavaScriptFromString:script];
    [self.wkWebview evaluateJavaScript:script completionHandler:nil];
}

// is this is the first LEANWebViewController in the navigation stack?
- (BOOL) isRootWebView
{
    for (UIViewController *vc in self.navigationController.viewControllers) {
        if ([vc isKindOfClass:[LEANWebViewController class]]) {
            return vc == self;
        }
    }
    
    return NO;
}

+ (NSInteger) urlLevelForUrl:(NSURL*)url;
{
    NSArray *entries = [GoNativeAppConfig sharedAppConfig].navStructureLevels;
    if (entries) {
        NSString *urlString = [url absoluteString];
        for (NSDictionary *entry in entries) {
            NSPredicate *predicate = entry[@"predicate"];
            BOOL matches = NO;
            @try {
                matches = [predicate evaluateWithObject:urlString];
            }
            @catch (NSException* exception) {
                NSLog(@"Regex error in regexInternalExternal: %@", exception);
            }

            if (matches) {
                return [entry[@"level"] integerValue];
            }
        }
    }

    // return -1 for unknown
    return -1;
}

+ (NSString*) titleForUrl:(NSURL*)url
{
    NSArray *entries = [GoNativeAppConfig sharedAppConfig].navTitles;
    NSString *title;
    
    if (entries) {
        NSString *urlString = [url absoluteString];
        for (NSDictionary *entry in entries) {
            NSPredicate *predicate = entry[@"predicate"];
            if ([predicate evaluateWithObject:urlString]) {
                if (entry[@"title"]) {
                    title = entry[@"title"];
                }
                
                if (!title && entry[@"urlRegex"]) {
                    NSRegularExpression *regex = entry[@"urlRegex"];
                    NSTextCheckingResult *match = [regex firstMatchInString:urlString options:0 range:NSMakeRange(0, [urlString length])];
                    if ([match range].location != NSNotFound) {
                        NSString *temp = [urlString substringWithRange:[match rangeAtIndex:1]];
                        
                        // dashes to spaces, capitalize
                        temp = [temp stringByReplacingOccurrencesOfString:@"-" withString:@" "];
                        title = [LEANUtilities capitalizeWords:temp];
                    }
                    
                    // remove words from end of title
                    if (title && [entry[@"urlChompWords"] intValue] > 0) {
                        __block NSInteger numWords = 0;
                        __block NSRange lastWordRange = NSMakeRange(0, [title length]);
                        [title enumerateSubstringsInRange:NSMakeRange(0, [title length]) options:NSStringEnumerationByWords | NSStringEnumerationReverse usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                            
                            numWords++;
                            if (numWords >= [entry[@"urlChompWords"] intValue]) {
                                lastWordRange = substringRange;
                                *stop = YES;
                            }
                        }];
                        
                        title = [title substringToIndex:lastWordRange.location];
                        title = [title stringByTrimmingCharactersInSet:
                                 [NSCharacterSet whitespaceCharacterSet]];
                    }
                }
                
                break;
            }
        }
    }
    
    return title;
}

#pragma mark - Search Bar Delegate
- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSString *searchText = [searchBar.text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *searchTemplate = [GoNativeAppConfig sharedAppConfig].searchTemplateURL;
    NSURL *url = [NSURL URLWithString:[searchTemplate stringByAppendingString:searchText]];

    [self loadUrl:url];
    
    self.navigationItem.titleView = self.defaultTitleView;
    [self showNavigationItemButtonsAnimated:YES];
}

- (void) searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self searchCanceled];
}

- (void) searchCanceled
{
    self.navigationItem.titleView = self.defaultTitleView;
    [self showNavigationItemButtonsAnimated:YES];
}


#pragma mark - UIWebViewDelegate
- (BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    BOOL isMainFrame = [[[request URL] absoluteString] isEqualToString:[[request mainDocumentURL] absoluteString]];
    BOOL isUserAction = navigationType == UIWebViewNavigationTypeLinkClicked || navigationType ==UIWebViewNavigationTypeFormSubmitted;
    return [self shouldLoadRequest:request isMainFrame:isMainFrame isUserAction:isUserAction hideWebview:YES];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    // is target="_blank" and we are allowing window open? Always accept, skipping logic. This makes
    // target="_blank" behave like window.open
    if (navigationAction.targetFrame == nil && [GoNativeAppConfig sharedAppConfig].enableWindowOpen) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    BOOL isUserAction = navigationAction.navigationType == WKNavigationTypeLinkActivated || navigationAction.navigationType == WKNavigationTypeFormSubmitted;
    BOOL shouldLoad = [self shouldLoadRequest:navigationAction.request isMainFrame:navigationAction.targetFrame.isMainFrame isUserAction:isUserAction hideWebview:YES];
    if (!shouldLoad) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    NSDictionary *customHeaders = [GNCustomHeaders getCustomHeaders];
    if (navigationAction.targetFrame.isMainFrame && customHeaders && [GNCustomHeaders shouldModifyRequest:navigationAction.request]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        NSURLRequest *modifiedRequest = [GNCustomHeaders modifyRequest:navigationAction.request];
        [self.wkWebview loadRequest:modifiedRequest];
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    if (navigationResponse.canShowMIMEType) {
        decisionHandler(WKNavigationResponsePolicyAllow);
        return;
    }

    decisionHandler(WKNavigationResponsePolicyCancel);
    
    if ([@"application/vnd.apple.pkpass" isEqualToString:navigationResponse.response.MIMEType]) {
        NSURL *url = navigationResponse.response.URL;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideWebview];
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

            void (^downloadPass)(void) = ^void() {
                NSURLSessionDataTask *task =  [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showWebview];
                    });
                    
                    if (!error && [response isKindOfClass:[NSHTTPURLResponse class]]) {
                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                        if (httpResponse.statusCode == 200) {
                            NSError *passError;
                            PKPass *pass = [[PKPass alloc] initWithData:data error:&passError];
                            if (passError) {
                                NSLog(@"Error parsing pass from %@: %@", url, passError);
                            } else {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    PKAddPassesViewController *apvc = [[PKAddPassesViewController alloc] initWithPass:pass];
                                    [[self getTopPresentedViewController] presentViewController:apvc animated:YES completion:nil];
                                });
                            }
                        } else {
                            NSLog(@"Got status %ld when downloading pass from %@", (long)httpResponse.statusCode, url);
                        }
                    } else {
                        NSLog(@"Error getting pass (%@): %@", url, error);
                    }
                }];
                [task resume];
            };
            
            // If using WKWebView on iOS11+, get cookies from WKHTTPCookieStore
            BOOL gettingWKWebviewCookies = NO;
            if ([GoNativeAppConfig sharedAppConfig].useWKWebView) {
                if (@available(iOS 11.0, *)) {
                    gettingWKWebviewCookies = YES;
                    WKHTTPCookieStore *cookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
                    [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
                        NSMutableArray *cookiesToSend = [NSMutableArray array];
                        for (NSHTTPCookie *cookie in cookies) {
                            if ([LEANUtilities cookie:cookie matchesUrl:url]) {
                                [cookiesToSend addObject:cookie];
                            }
                        }
                        NSDictionary *headerFields = [NSHTTPCookie requestHeaderFieldsWithCookies:cookiesToSend];
                        NSString *cookieHeader = headerFields[@"Cookie"];
                        if (cookieHeader) {
                            [request addValue:cookieHeader forHTTPHeaderField:@"Cookie"];
                        }
                        downloadPass();
                    }];
                }
            }
            if (!gettingWKWebviewCookies) {
                downloadPass();
            }
        });
    }
}

- (BOOL)shouldLoadRequest:(NSURLRequest*)request isMainFrame:(BOOL)isMainFrame isUserAction:(BOOL)isUserAction hideWebview:(BOOL)hideWebview
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    NSURL *url = [request URL];
    NSString *urlString = [url absoluteString];
    NSString* hostname = [url host];
    
//    NSLog(@"should start load %@ main %d action %d", url, isMainFrame, isUserAction);
    
    // simulator
    if ([url.scheme isEqualToString:@"gonative.io"]) {
        return YES;
    }
    
    // local
    if ([url.host isEqualToString:@"offline"]) {
        return YES;
    }
    
    // gonative commands
    if ([url.scheme isEqualToString:@"gonative-bridge"]) {
        NSString *queryString = url.query;
        if (!queryString) return NO;
        
        NSArray *queryComponents = [queryString componentsSeparatedByString:@"&"];
        for (NSString *keyValue in queryComponents) {
            NSArray *pairComponents = [keyValue componentsSeparatedByString:@"="];
            NSString *key = [[pairComponents firstObject] stringByRemovingPercentEncoding];
            if ([key isEqualToString:@"json"] && [pairComponents count] == 2) {
                NSString *json = [[pairComponents lastObject] stringByRemovingPercentEncoding];
                
                NSArray *parsedJson = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                if (![parsedJson isKindOfClass:[NSArray class]]) return NO;
                
                for (NSDictionary *entry in parsedJson) {
                    if (![entry isKindOfClass:[NSDictionary class]]) continue;
                    
                    NSString *command = entry[@"command"];
                    if (![command isKindOfClass:[NSString class]]) continue;
                    
                    if ([command isEqualToString:@"pop"]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // it's safe to call popViewControllerAnimated even if we are only one on the stack
                            [self.navigationController popViewControllerAnimated:YES];
                        });
                    } else if ([command isEqualToString:@"clearPools"]) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerClearPools object:self];
                    }
                }
            }
        }
        
        return NO;
    }
    
    if ([@"gonative" isEqualToString:url.scheme]) {
        NSString *currentUrl;
        if (self.wkWebview) {
            currentUrl = self.wkWebview.URL.absoluteString;
        } else if (self.webview) {
            currentUrl = self.webview.request.mainDocumentURL.absoluteString;
        }
        if (![LEANUtilities checkNativeBridgeUrl:currentUrl]) {
            NSLog(@"URL not authorized for native bridge: %@", currentUrl);
            return NO;
        }
        
        // config preferences
        if ([@"config" isEqualToString:url.host]) {
            GNConfigPreferences *config = [GNConfigPreferences sharedPreferences];
            [config handleUrl:url];
            return NO;
        }
        
        // touchid authentication
        if ([@"auth" isEqualToString:url.host]) {
            GoNativeAuthUrl *authUrl = [[GoNativeAuthUrl alloc] init];
            authUrl.currentUrl = self.currentRequest.URL;
            [authUrl handleUrl:url callback:^(NSString * _Nullable postUrl, NSDictionary<NSString *,id> * _Nullable postData, NSString * _Nullable callbackFunction) {
                
                if (callbackFunction) {
                    NSString *jsCallback = [LEANUtilities createJsForCallback:callbackFunction data:postData];
                    if (jsCallback) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self runJavascript:jsCallback];
                        });
                    }
                }
                
                if (postUrl) {
                    NSString *jsPost = [LEANUtilities createJsForPostTo:postUrl data:postData];
                    if (jsPost) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self runJavascript:jsPost];
                        });
                    }
                    
                }
            }];
            
            return NO;
        }
        
        // registration info
        if ([@"registration" isEqualToString:url.host] && [@"/send" isEqualToString:url.path]) {
            NSDictionary *query = [LEANUtilities parseQueryParamsWithUrl:url];
            NSString *customDataString = query[@"customData"];
            if (customDataString) {
                NSDictionary *customData = [NSJSONSerialization JSONObjectWithData:[customDataString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                if ([customData isKindOfClass:[NSDictionary class]]) {
                    [[GNRegistrationManager sharedManager] setCustomData:customData];
                    [[GNRegistrationManager sharedManager] sendToAllEndpoints];
                } else {
                    NSLog(@"Gonative registration error: customData is not JSON object");
                }
            } else {
                [[GNRegistrationManager sharedManager] sendToAllEndpoints];
            }
            
            return NO;
        }
        
        // OneSignal registration
        if ([@"onesignal" isEqualToString:url.host]) {
            if (!appConfig.oneSignalEnabled) {
                return NO;
            }
            
            if ([@"/register" isEqualToString:url.path]) {
                [OneSignal promptForPushNotificationsWithUserResponse:nil];
                return NO;
            }
            
            if ([@"/userPrivacyConsent/grant" isEqualToString:url.path]) {
                [OneSignal consentGranted:YES];
                if (appConfig.oneSignalAutoRegister) {
                    [OneSignal promptForPushNotificationsWithUserResponse:nil];
                }
                return NO;
            }

            if ([@"/userPrivacyConsent/revoke" isEqualToString:url.path]) {
                [OneSignal consentGranted:NO];
                return NO;
            }

            if ([@"/tags/get" isEqualToString:url.path]) {
                NSDictionary *query = [LEANUtilities parseQueryParamsWithUrl:url];
                NSString *callback = query[@"callback"];
                if (!callback || callback.length == 0) {
                    return NO;
                }
                
                [OneSignal getTags:^(NSDictionary *result) {
                    NSDictionary *results = @{
                                              @"success": @YES,
                                              @"tags": result
                                              };
                    NSString *js = [LEANUtilities createJsForCallback:callback data:results];
                    [self runJavascript:js];
                } onFailure:^(NSError *error) {
                    NSDictionary *results = @{
                                              @"success": @NO,
                                              };
                    NSString *js = [LEANUtilities createJsForCallback:callback data:results];
                    [self runJavascript:js];
                }];
                return NO;
            }
            if ([@"/tags/set" isEqualToString:url.path]) {
                NSDictionary *query = [LEANUtilities parseQueryParamsWithUrl:url];
                NSString *callback = query[@"callback"];
                NSString *tagsString = query[@"tags"];
                NSDictionary *tags = [NSJSONSerialization JSONObjectWithData:[tagsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                if (![tags isKindOfClass:[NSDictionary class]]) {
                    return NO;
                }
                
                // verify all tags are strings
                for (id key in tags) {
                    if (![key isKindOfClass:[NSString class]] || ![tags[key] isKindOfClass:[NSString class]]) {
                        return NO;
                    }
                }
                
                // set the tags
                [OneSignal sendTags:tags onSuccess:^(NSDictionary *result) {
                    if (callback && callback.length > 0) {
                        NSString *js = [LEANUtilities createJsForCallback:callback data:@{
                              @"success": @YES
                                                                                          }];
                        [self runJavascript:js];
                    }
                } onFailure:^(NSError *error) {
                    if (callback && callback.length > 0) {
                        NSString *js = [LEANUtilities createJsForCallback:callback data:@{
                               @"success": @NO
                                                                                          }];
                        [self runJavascript:js];
                    }
                }];
                return NO;
            }
            
            if (([@"/promptLocation" isEqualToString:url.path])) {
                [OneSignal promptLocation];
                return NO;
            }

            if (([@"/showTagsUI" isEqualToString:url.path])) {
                UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Subscriptions" bundle:nil];
                UIViewController *vc = [storyboard instantiateInitialViewController];
                [self presentViewController:vc animated:YES completion:nil];

                return NO;
            }

            return NO;
        }
        
        // Sidebar
        if ([@"sidebar" isEqualToString:url.host]) {
            if ([@"/setItems" isEqualToString:url.path]) {
                NSDictionary *query = [LEANUtilities parseQueryParamsWithUrl:url];
                NSString *itemsString = query[@"items"];
                if (itemsString) {
                    id items = [NSJSONSerialization JSONObjectWithData:[itemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                    [appConfig setSidebarNavigation:items];
                }
            }
        }
        
        if ([@"window" isEqualToString:url.host]) {
            if ([@"/open" isEqualToString:url.path]) {
                NSDictionary *query = [LEANUtilities parseQueryParamsWithUrl:url];
                NSURL *urlToOpen = [NSURL URLWithString:query[@"url"]];
                if (urlToOpen) {
                    NSMutableURLRequest *requestToOpen = [NSMutableURLRequest requestWithURL:urlToOpen];
                    // need to set mainDocumentURL to properly handle external links in shouldLoadRequest:
                    requestToOpen.mainDocumentURL = urlToOpen;
                    if (requestToOpen) {
                        BOOL shouldLoad = [self shouldLoadRequest:requestToOpen isMainFrame:YES isUserAction:YES hideWebview:NO];
                        if (shouldLoad) {
                            LEANWebViewController *newvc = [self.storyboard instantiateViewControllerWithIdentifier:@"webviewController"];
                            newvc.initialUrl = urlToOpen;
                            NSMutableArray *controllers = [self.navigationController.viewControllers mutableCopy];
                            while (![[controllers lastObject] isKindOfClass:[LEANWebViewController class]]) {
                                [controllers removeLastObject];
                            }
                            [controllers addObject:newvc];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.navigationController setViewControllers:controllers animated:YES];
                            });
                        }
                    }
                }
            }
        }
        
        // Share page
        if ([@"share" isEqualToString:url.host] && [@"/sharePage" isEqualToString:url.path]) {
            NSDictionary *query = [LEANUtilities parseQueryParamsWithUrl:url];
            NSString *shareUrl = query[@"url"]; // can be nil
            [self sharePageWithUrl:shareUrl sender:nil];
        }
        
        // Geolocation shim
        if ([@"geolocationShim" isEqualToString:url.host]) {
            if ([@"/requestLocation" isEqualToString:url.path]) {
                [self requestLocation];
            } else if ([@"/startWatchingLocation" isEqualToString:url.path]) {
                [self startWatchingLocation];
            } else if ([@"/stopWatchingLocation" isEqualToString:url.path]) {
                [self stopWatchingLocation];
            }
            return NO;
        }
        
        // Tabs
        if ([@"tabs" isEqualToString:url.host]) {
            if ([url.path hasPrefix:@"/select/"]) {
                NSArray *components = url.pathComponents;
                if (components.count == 3 ) {
                    NSString *tabNumberString = components[2];
                    NSInteger tabNumber = [tabNumberString integerValue];
                    if (tabNumberString >= 0) {
                        [self.tabManager selectTabNumber:tabNumber];
                    }
                }
            } else if ([@"/deselect" isEqualToString:url.path]) {
                [self.tabManager deselectTabs];
            } else if ([@"/setTabs" isEqualToString:url.path]) {
                NSDictionary *query = [LEANUtilities parseQueryParamsWithUrl:url];
                NSString *tabsJson = query[@"tabs"];
                if (tabsJson && tabsJson.length) {
                    [self.tabManager setTabsWithJson:tabsJson];
                    self.javascriptTabs = YES;
                }
            }
        }
        
        // Status bar
        if ([@"statusbar" isEqualToString:url.host]) {
            if ([url.path isEqualToString:@"/set"]) {
                NSDictionary *query = [LEANUtilities parseQueryParamsWithUrl:url];
                
                NSString *style = query[@"style"];
                if (style) {
                    if ([style isEqualToString:@"light"]) {
                        // light icons and text
                        self.statusBarStyle = [NSNumber numberWithInteger:UIStatusBarStyleLightContent];
                        [self setNeedsStatusBarAppearanceUpdate];
                    }
                    else if ([style isEqualToString:@"dark"]) {
                        // dark icons and text
                        self.statusBarStyle = [NSNumber numberWithInteger:UIStatusBarStyleDefault];
                        [self setNeedsStatusBarAppearanceUpdate];
                    }
                }
                
                NSString *color = query[@"color"];
                if (color) {
                    UIColor *parsedColor = [LEANUtilities colorWithAlphaFromHexString:color];
                    if (parsedColor) {
                        UIView *background = [[UIView alloc] init];
                        background.backgroundColor = parsedColor;
                        [self.statusBarBackground removeFromSuperview];
                        self.statusBarBackground = background;
                        [self.view addSubview:self.statusBarBackground];
                    }
                }
                
                NSString *overlay = query[@"overlay"];
                if (overlay) {
                    if ([overlay isEqualToString:@"true"] || [overlay isEqualToString:@"1"]) {
                        self.statusBarOverlay = YES;
                    } else {
                        self.statusBarOverlay = NO;
                    }
                    [self applyStatusBarOverlay];
                }
            }
        }
        
        // connectivity
        if ([@"connectivity" isEqualToString:url.host]) {
            NSDictionary *query = [LEANUtilities parseQueryParamsWithUrl:url];
            NSString *callback = query[@"callback"];
            NSDictionary *status = [self getConnectivity];

            if ([@"/get" isEqualToString:url.path]) {
                if ([callback isKindOfClass:[NSString class]] && callback.length > 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *js = [LEANUtilities createJsForCallback:callback data:status];
                        [self runJavascript:js];
                    });
                }
            } else if ([@"/subscribe" isEqualToString:url.path]) {
                if ([callback isKindOfClass:[NSString class]] && callback.length > 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *js = [LEANUtilities createJsForCallback:callback data:status];
                        [self runJavascript:js];
                    });
                    self.connectivityCallback = callback;
                }
            } else if ([@"/unsubscribe" isEqualToString:url.path]) {
                self.connectivityCallback = nil;
            }
        }
        
        return NO;
    }
    
    // tel links
    if ([url.scheme isEqualToString:@"tel"]) {
        NSString *telNumber = url.resourceSpecifier;
        if ([telNumber length] > 0) {
            NSURL *telPromptUrl = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt:%@", telNumber]];
            if ([[UIApplication sharedApplication] canOpenURL:telPromptUrl]) {
                [[UIApplication sharedApplication] openURL:telPromptUrl];
            } else if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }
        return NO;
    }
    
    // mailto links
    if ([url.scheme isEqualToString:@"mailto"]) {
        if ([MFMailComposeViewController canSendMail]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // parse the mailto link
                NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];

                NSMutableArray *toRecipients = [NSMutableArray array];
                NSArray *recipients = [components.path componentsSeparatedByString:@","];
                for (NSString *recipient in recipients) {
                    if (recipient.length > 0) {
                        [toRecipients addObject:recipient];
                    }
                }
                
                MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
                mc.mailComposeDelegate = self;
                
                for (NSURLQueryItem *item in components.queryItems) {
                    if ([[item.name lowercaseString] isEqualToString: @"subject"]) {
                        [mc setSubject:item.value];
                    } else if ([[item.name lowercaseString]isEqualToString:@"body"]) {
                        [mc setMessageBody:item.value isHTML:NO];
                    } else if ([[item.name lowercaseString] isEqualToString:@"to"]) {
                        // append to array, do not replace
                        [toRecipients addObjectsFromArray:[item.value componentsSeparatedByString:@","]];
                    } else if ([[item.name lowercaseString] isEqualToString:@"cc"]) {
                        [mc setCcRecipients:[item.value componentsSeparatedByString:@","]];
                    } else if ([[item.name lowercaseString] isEqualToString:@"bcc"]) {
                        [mc setBccRecipients:[item.value componentsSeparatedByString:@","]];
                    }
                }
                [mc setToRecipients:toRecipients];
                [self presentViewController:mc animated:YES completion:nil];
            });
        } else {
            NSLog(@"MFMailComposeViewController cannot send mail. Opening mailto url in mail app");
            [[UIApplication sharedApplication] openURL:url];
        }
        return NO;
    }
    
    // sms links
    if ([url.scheme isEqualToString:@"sms"]) {
        [[UIApplication sharedApplication] openURL:url];
        return NO;
    }
    
    // always allow iframes to load
    if (![urlString isEqualToString:[[request mainDocumentURL] absoluteString]]) {
        return YES;
    }
    
    [[LEANUrlInspector sharedInspector] inspectUrl:url];
    
    // check redirects
    if (appConfig.redirects != nil) {
        NSString *to = [appConfig.redirects valueForKey:urlString];
        if (!to) to = [appConfig.redirects valueForKey:@"*"];
        if (to && ![to isEqualToString:urlString]) {
            url = [NSURL URLWithString:to];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self loadUrl:url];
            });
            return NO;
        }
    }
    
    // log out by clearing cookies
    if (urlString && [urlString caseInsensitiveCompare:@"file://gonative_logout"] == NSOrderedSame) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self logout];
        });
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[UIApplication sharedApplication] canOpenURL:url])
                [[UIApplication sharedApplication] openURL:url];
            else
                [[UIApplication sharedApplication] openURL:[request URL]];
        });
        
        return NO;
    }
    
    // external sites: don't launch if in iframe.
    if (isUserAction || (isMainFrame && ![[request URL] matchesPathOf:[self.currentRequest URL]])) {
        // first check regexInternalExternal
        bool matchedRegex = NO;
        for (NSUInteger i = 0; i < [appConfig.regexInternalEternal count]; i++) {
            NSPredicate *predicate = appConfig.regexInternalEternal[i];
            BOOL matches = NO;
            @try {
                matches = [predicate evaluateWithObject:urlString];
            }
            @catch (NSException* exception) {
                NSLog(@"Error in regex internal external: %@", exception);
            }
            if (matches) {
                matchedRegex = YES;
                if (![appConfig.regexIsInternal[i] boolValue]) {
                    // external
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[UIApplication sharedApplication] openURL:[request URL]];
                    });
                    return NO;
                }
                break;
            }
        }
        
        if (!matchedRegex) {
            if (![hostname isEqualToString:appConfig.initialHost] &&
                ![hostname hasSuffix:[@"." stringByAppendingString:appConfig.initialHost]]) {
                // open in external web browser
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] openURL:[request URL]];
                });
                return NO;
            }
        }
    }
    
    // Starting here, we are going to load the request, but possibly in a different webviewcontroller depending on the structured nav level
    NSInteger newLevel = [LEANWebViewController urlLevelForUrl:url];
    if (self.urlLevel >= 0 && newLevel >= 0) {
        if (newLevel > self.urlLevel) {
            // push a new controller
            LEANWebViewController *newvc = [self.storyboard instantiateViewControllerWithIdentifier:@"webviewController"];
            newvc.initialUrl = url;
            newvc.postLoadJavascript = self.postLoadJavascript;
            self.postLoadJavascript = nil;
            self.postLoadJavascriptForRefresh = nil;
            
            NSMutableArray *controllers = [self.navigationController.viewControllers mutableCopy];
            while (![[controllers lastObject] isKindOfClass:[LEANWebViewController class]]) {
                [controllers removeLastObject];
            }
            [controllers addObject:newvc];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController setViewControllers:controllers animated:YES];
            });
            
            return NO;
        }
        else if (newLevel < self.urlLevel) {
            // find controller on top of the first controller with a lower-numbered level
            NSArray *vcs = self.navigationController.viewControllers;
            LEANWebViewController *wvc = self;
            for (NSInteger i = vcs.count - 1; i >= 0; i--) {
                if ([vcs[i] isKindOfClass:[LEANWebViewController class]]) {
                    if (newLevel > ((LEANWebViewController*)vcs[i]).urlLevel) {
                        break;
                    }
                    
                    // save into as the 'previous to last' controller
                    wvc = vcs[i];
                }
            }
            
            if (wvc != self) {
                wvc.urlLevel = newLevel;
                if (self.postLoadJavascript) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [wvc loadRequest:request andJavascript:self.postLoadJavascript];
                    });
                    self.postLoadJavascript = nil;
                    self.postLoadJavascriptForRefresh = nil;
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [wvc loadRequest:request];
                    });
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.navigationController popToViewController:wvc animated:YES];
                });
                return NO;
            }
        }
    }
    
    
    // Starting here, the request will be loaded in this webviewcontroller
    // pop to the top webviewcontroller in the stack
    NSMutableArray *controllers = [self.navigationController.viewControllers mutableCopy];
    BOOL changedControllerStack = NO;
    while (![[controllers lastObject] isKindOfClass:[LEANWebViewController class]]) {
        [controllers removeLastObject];
        changedControllerStack = YES;
    }
    if (changedControllerStack) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController setViewControllers:controllers animated:YES];
        });
    }
    
    if (newLevel >= 0) {
        self.urlLevel = [LEANWebViewController urlLevelForUrl:url];
    }
    
    NSString *newTitle = [LEANWebViewController titleForUrl:url];
    if (newTitle) {
        self.navigationItem.title = newTitle;
    }
    
    
    // save request for various functions that require the current request
    NSURLRequest *previousRequest = self.currentRequest;
    self.currentRequest = request;
    // save for html interception
    [LEANWebviewInterceptTracker sharedTracker].currentRequest = request;
    
    // update title image, tabs, etc
    [self checkPreNavigationForUrl:request.URL];
    
    // check to see if the webview exists in pool. Swap it in if it's not the same url.
    UIView *poolWebview = nil;
    LEANWebViewPoolDisownPolicy poolDisownPolicy;
    poolWebview = [[LEANWebViewPool sharedPool] webviewForUrl:url policy:&poolDisownPolicy];
    
    if (poolWebview && poolDisownPolicy == LEANWebViewPoolDisownPolicyAlways) {
        self.isPoolWebview = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self switchToWebView:poolWebview showImmediately:YES];
            self.didLoadPage = YES;
            [self checkNavigationForUrl:url];
        });
        [[LEANWebViewPool sharedPool] disownWebview:poolWebview];
        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserFinishedLoading object:self];
        return NO;
    }
    
    if (poolWebview && poolDisownPolicy == LEANWebViewPoolDisownPolicyNever) {
        self.isPoolWebview = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self switchToWebView:poolWebview showImmediately:YES];
            self.didLoadPage = YES;
            [self checkNavigationForUrl:url];
        });
        return NO;
    }
    
    if (poolWebview && poolDisownPolicy == LEANWebViewPoolDisownPolicyReload &&
        ![[request URL] matchesPathOf:[previousRequest URL]]) {
        self.isPoolWebview = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self switchToWebView:poolWebview showImmediately:YES];
            self.didLoadPage = YES;
            [self checkNavigationForUrl:url];
        });
        return NO;
    }
    
    if (self.isPoolWebview) {
        // if we are here, either the policy is reload and we are reloading the page, or policy is never but we are going to a different page. So take ownership of the webview.
        [[LEANWebViewPool sharedPool] disownWebview:self.webview];
        [[LEANWebViewPool sharedPool] disownWebview:self.wkWebview];
        self.isPoolWebview = NO;
    }
    
    // Do not hide the webview if url.fragment exists and the url is the same.
    // here sometimes is an issue with single-page apps where shouldLoadRequest
    // is called for SPA page loads if there is a fragment. We will never get an sort of page finished callback, so the page
    // is always hidden.
    BOOL hide = hideWebview;
    if (hide && url.fragment) {
        NSURL *currentUrl = self.currentRequest.URL;
        if (currentUrl &&
            [url.host isEqualToString:currentUrl.host] &&
            [url.scheme isEqualToString:currentUrl.scheme] &&
            [url.path isEqualToString:currentUrl.path] &&
            [url.query isEqualToString:currentUrl.query]) {
            hide = NO;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (hide) [self hideWebview];
        [self setNavigationButtonStatus];
    });
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserStartedLoading object:self];
    
    return YES;
}

- (void)switchToWebView:(UIView*)newView showImmediately:(BOOL)showImmediately
{
    UIView *oldView;
    if (self.webview) {
        oldView = self.webview;
        ((UIWebView*)oldView).delegate = nil;
    }
    if (self.wkWebview) {
        oldView = self.wkWebview;
        
        // remove KVO
        @try {
            [oldView removeObserver:self forKeyPath:@"URL"];
            [oldView removeObserver:self forKeyPath:@"canGoBack"];
        }
        @catch (NSException * __unused exception) {
        }
    }
    
    [self hideWebview];
    
    [self removePullRefresh];
    
    UIScrollView *scrollView;
    if ([newView isKindOfClass:[UIWebView class]]) {
        self.webview = (UIWebView*)newView;
        self.wkWebview = nil;
        self.webview.delegate = self;
        scrollView = self.webview.scrollView;
    } else if ([newView isKindOfClass:[NSClassFromString(@"WKWebView") class]]) {
        self.wkWebview = (WKWebView*)newView;
        self.webview = nil;
        self.wkWebview.navigationDelegate = self;
        self.wkWebview.UIDelegate = self;
        scrollView = self.wkWebview.scrollView;
        
        // add KVO for single-page app url changes
        [newView addObserver:self forKeyPath:@"URL" options:0 context:nil];
        [newView addObserver:self forKeyPath:@"canGoBack" options:0 context:nil];
    } else {
        return;
    }
    
    // scroll before swapping to help reduce jank
    [scrollView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    
    if (oldView != newView) {
        newView.frame = oldView.frame;
        
        UIView *webviewContainer = [oldView superview];
        [webviewContainer insertSubview:newView aboveSubview:oldView];
        [oldView removeFromSuperview];
        
        // add layout constriants to constainer view
        [webviewContainer addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:webviewContainer attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
        [webviewContainer addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:webviewContainer attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
        [webviewContainer addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:webviewContainer attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
        [webviewContainer addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:webviewContainer attribute:NSLayoutAttributeRight multiplier:1 constant:0]];

    }
    [self adjustInsets];
    // re-scroll after adjusting insets
    [scrollView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    
    if (self.postLoadJavascript) {
        [self runJavascript:self.postLoadJavascript];
        self.postLoadJavascript = nil;
    }
    
    // fix for black boxes
    for (UIView *view in scrollView.subviews) {
        [view setNeedsDisplayInRect:newView.bounds];
    }
    
    if (showImmediately) {
        [self showWebview];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }
    
    if ([GoNativeAppConfig sharedAppConfig].pullToRefresh) {
        [self addPullToRefresh];
    }
}

// To detect single-page app navigation in WKWebView
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (object == self.wkWebview) {
        NSURL *url = self.wkWebview.URL;

        if ([keyPath isEqualToString:@"URL"]) {
            if (url) {
                [self checkPreNavigationForUrl:url];
                [self checkNavigationForUrl:url];
                [[GNRegistrationManager sharedManager] checkUrl:url];
            }
        }
        if ([keyPath isEqualToString:@"canGoBack"]) {
            // we need a separate observe canGoBack because it seems to update after URL
            [self.toolbarManager didLoadUrl:url];
        }
    }
}

- (void) webViewDidStartLoad:(UIWebView *)webView
{
    [self didStartLoad];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    [self didStartLoad];
}

- (void)didStartLoad
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![GoNativeAppConfig sharedAppConfig].pullToRefresh) {
            [self removePullRefresh];
        }
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        [self.customActionButton setEnabled:NO];
        
        [self.timer invalidate];
        self.timer = [NSTimer timerWithTimeInterval:0.05 target:self selector:@selector(checkReadyStatus) userInfo:nil repeats:YES];
        [self.timer setTolerance:0.02];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
        
        // remove share button
        if (self.shareButton) {
            self.shareButton = nil;
            [self showNavigationItemButtonsAnimated:YES];
        }
        
        // stop watching location
        [self.locationManager stopUpdatingLocation];
    });
}

- (void) webViewDidFinishLoad:(UIWebView *)webView
{
    [self didFinishLoad];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self didFinishLoad];
}

- (void)didFinishLoad
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showWebview];
        
        NSURL *url = nil;
        if (self.webview) {
            url = self.webview.request.URL;
        } else if (self.wkWebview) {
            url = self.wkWebview.URL;
        }
        
        // don't do any more processing or set didloadpage if we are showing an offline page
        if (!url || [url.host isEqualToString:@"offline"]) {
            [self addPullToRefresh];
            self.didLoadPage = NO;
            return;
        }
        
        self.didLoadPage = YES;
        
        [[LEANUrlInspector sharedInspector] inspectUrl:url];
                
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [self setNavigationButtonStatus];

        [LEANUtilities overrideGeolocation:self.webview];
        [LEANUtilities overrideGeolocation:self.wkWebview];
        
        // update navigation title
        if ([GoNativeAppConfig sharedAppConfig].useWebpageTitle) {
            if (self.webview) {
                NSString *theTitle=[self.webview stringByEvaluatingJavaScriptFromString:@"document.title"];
                self.nav.title = theTitle;
            }
            else if (self.wkWebview) {
                self.nav.title = self.wkWebview.title;
            }
        }
        
        // update menu
        if ([GoNativeAppConfig sharedAppConfig].loginDetectionURL && (!self.webview || !self.webview.isLoading)) {
            [[LEANLoginManager sharedManager] checkLogin];
            
            self.visitedLoginOrSignup = [url matchesPathOf:[GoNativeAppConfig sharedAppConfig].loginURL] ||
            [url matchesPathOf:[GoNativeAppConfig sharedAppConfig].signupURL];
        }
        
        // dynamic config updater
        if ([GoNativeAppConfig sharedAppConfig].updateConfigJS && (!self.webview || !self.webview.isLoading)) {
            if (self.webview) {
                NSString *result = [self.webview stringByEvaluatingJavaScriptFromString:[GoNativeAppConfig sharedAppConfig].updateConfigJS];
                [[GoNativeAppConfig sharedAppConfig] processDynamicUpdate:result];
            }
            if (self.wkWebview) {
                [self.wkWebview evaluateJavaScript:[GoNativeAppConfig sharedAppConfig].updateConfigJS completionHandler:^(id response, NSError *error) {
                    if ([response isKindOfClass:[NSString class]]) {
                        [[GoNativeAppConfig sharedAppConfig] processDynamicUpdate:response];
                    }
                }];
            }
        }
        
        // profile picker
        if (self.profilePickerJs) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.webview) {
                    NSString *json = [self.webview stringByEvaluatingJavaScriptFromString:self.profilePickerJs];
                    [(LEANMenuViewController*)self.frostedViewController.menuViewController parseProfilePickerJSON:json];
                }
                if (self.wkWebview) {
                    [self.wkWebview evaluateJavaScript:self.profilePickerJs completionHandler:^(id response, NSError *error) {
                        if ([response isKindOfClass:[NSString class]]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [(LEANMenuViewController*)self.frostedViewController.menuViewController parseProfilePickerJSON:response];
                            });
                        }
                    }];
                }
            });
        }
        
        // tabs
        [self checkNavigationForUrl: url];
        
        // actions
        [self checkActionsForUrl: url];
        
        // post-load js
        if (self.postLoadJavascript && (!self.webview || !self.webview.isLoading)) {
            NSString *js = self.postLoadJavascript;
            self.postLoadJavascript = nil;
            [self runJavascript:js];
        }
        
        // post notification
        if (!self.webview || !self.webview.isLoading) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserFinishedLoading object:self];
        }
        
        // document sharing
        if ([[LEANDocumentSharer sharedSharer] isSharableRequest:self.currentRequest]) {
            if (!self.shareButton) {
                self.shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(sharePressed:)];
            }
        } else {
            self.shareButton = nil;
        }
        
        [self showNavigationItemButtonsAnimated:YES];
                
        // registration service
        [[GNRegistrationManager sharedManager] checkUrl:url];
        
        BOOL doNativeBridge = YES;
        if (url) {
            doNativeBridge = [LEANUtilities checkNativeBridgeUrl:[url absoluteString]];
        }
        
        // send device info
        if (doNativeBridge) {
            NSDictionary *installation = [LEANInstallation info];
            LEANAppDelegate *appDelegate = (LEANAppDelegate*)[UIApplication sharedApplication].delegate;
            appDelegate.isFirstLaunch = NO;
            NSString *jsCallback = [LEANUtilities createJsForCallback:@"gonative_device_info" data:installation];
            if (jsCallback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self runJavascript:jsCallback];
                });
            }
        }
        
        // send OneSignal info
        if ([GoNativeAppConfig sharedAppConfig].oneSignalEnabled && doNativeBridge) {
            OSPermissionSubscriptionState *state = [OneSignal getPermissionSubscriptionState];

            NSMutableDictionary *toSend = [NSMutableDictionary dictionary];
            NSDictionary *installation = [LEANInstallation info];
            [toSend addEntriesFromDictionary:installation];
            if (state.subscriptionStatus) {
                if (state.subscriptionStatus.userId) {
                    toSend[@"oneSignalUserId"] = state.subscriptionStatus.userId;
                }
                if (state.subscriptionStatus.pushToken) {
                    toSend[@"oneSignalPushToken"] = state.subscriptionStatus.pushToken;
                }
                toSend[@"oneSignalSubscribed"] = [NSNumber numberWithBool:state.subscriptionStatus.subscribed];
                toSend[@"oneSignalRequiresUserPrivacyConsent"] = [NSNumber numberWithBool:[OneSignal requiresUserPrivacyConsent]];
            }
            
            NSString *jsCallback = [LEANUtilities createJsForCallback:@"gonative_onesignal_info" data:toSend];
            if (jsCallback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self runJavascript:jsCallback];
                });
            }
        }
        
        // save session cookies as persistent
        NSUInteger forceSessionCookieExpiry = [GoNativeAppConfig sharedAppConfig].forceSessionCookieExpiry;
        if (forceSessionCookieExpiry > 0) {
            NSHTTPCookieStorage *cookieStore = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            for (NSHTTPCookie *cookie in [cookieStore cookiesForURL:url]) {
                if (cookie.expiresDate == nil || cookie.sessionOnly) {
                    NSMutableDictionary *cookieProperties = [cookie.properties mutableCopy];
                    cookieProperties[NSHTTPCookieExpires] = [[NSDate date] dateByAddingTimeInterval:forceSessionCookieExpiry];
                    cookieProperties[NSHTTPCookieMaximumAge] = [NSString stringWithFormat:@"%lu", (unsigned long)forceSessionCookieExpiry];
                    [cookieProperties removeObjectForKey:@"Created"];
                    [cookieProperties removeObjectForKey:NSHTTPCookieDiscard];
                    NSHTTPCookie *newCookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
                    [cookieStore setCookie:newCookie];
                }
            }
        }
    });
}

- (WKWebView*)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    // createWebView is called before shouldLoadRequest is called. To avoid creating an extra
    // WebViewController for an external link, we check shouldLoadRequest here.
    if (navigationAction.request) {
        BOOL shouldLoad = [self shouldLoadRequest:navigationAction.request isMainFrame:YES isUserAction:YES hideWebview:NO];
        if (!shouldLoad) {
            return nil;
        }
    }
    
    if (![GoNativeAppConfig sharedAppConfig].enableWindowOpen) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadRequest:navigationAction.request];
        });
        return nil;
    }
    
    WKWebView *newWebview = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:self.webview.frame configuration:configuration];
    [LEANUtilities configureWebView:newWebview];
    
    LEANWebViewController *newvc = [self.storyboard instantiateViewControllerWithIdentifier:@"webviewController"];
    newvc.initialWebview = newWebview;
    
    NSMutableArray *controllers = [self.navigationController.viewControllers mutableCopy];
    while (![[controllers lastObject] isKindOfClass:[LEANWebViewController class]]) {
        [controllers removeLastObject];
    }
    [controllers addObject:newvc];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController setViewControllers:controllers animated:YES];
    });

    return newWebview;
}

-(void)webViewDidClose:(WKWebView *)webView
{
    if (webView != self.wkWebview) return;
    
    NSArray *vcs = self.navigationController.viewControllers;
    LEANWebViewController *popTo = nil;
    // find the top webviewcontroller that is not self
    for (NSInteger i = vcs.count - 1; i >= 0; i--) {
        if ([vcs[i] isKindOfClass:[LEANWebViewController class]] && vcs[i] != self) {
            popTo = vcs[i];
            break;
        }
    }
    
    if (popTo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController popToViewController:popTo animated:YES];
        });
    } else {
        NSString *initialUrlPref = [[GNConfigPreferences sharedPreferences] getInitialUrl];
        if (initialUrlPref) {
            [self loadUrl:[NSURL URLWithString:initialUrlPref]];
        } else {
            [self loadUrl:[GoNativeAppConfig sharedAppConfig].initialURL];
        }
    }
}

    - (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)message defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * __nullable result))completionHandler
    {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.text = defaultText;
        }];
        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *input = ((UITextField *)alertController.textFields.firstObject).text;
            completionHandler(input);
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            completionHandler(nil);
        }]];
        [[self getTopPresentedViewController] presentViewController:alertController animated:YES completion:^{}];
    }

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler();
    }];
    [alert addAction:okAction];
    
    // There is a chance that a view controller is already being presented, e.g. if a drop-down box
    // on iPad is open, and selecting an item triggers a javascript alert. That's why we don't just call
    // [self presentViewController:]
    [[self getTopPresentedViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }];
    [alert addAction:okAction];
    [alert addAction:cancelAction];
    
    [[self getTopPresentedViewController] presentViewController:alert animated:YES completion:nil];

}

-(UIViewController*)getTopPresentedViewController {
    UIViewController *vc = self;
    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    return vc;
}

- (void)checkReadyStatus
{
    // if interactiveDelay is specified, then look for readyState=interactive, and show webview
    // with a delay. If not specified, wait for readyState=complete.
    NSNumber *interactiveDelay = [GoNativeAppConfig sharedAppConfig].interactiveDelay;
    
    void (^readyStateBlock)(id, NSError*) = ^(id status, NSError *error) {
        // we keep track of startedLoading because loading is only really finished when we have gone to
        // "loading" or "interactive" before going to complete. When the web page first starts loading,
        // it will be in "complete", then "loading", "interactive", and finally "complete".
        
        if (![status isKindOfClass:[NSString class]]) {
            return;
        }
        
        if ([status isEqualToString:@"loading"] || (!interactiveDelay && [status isEqualToString:@"interactive"])){
            self.startedLoading = YES;
        }
        else if ((interactiveDelay && [status isEqualToString:@"interactive"])
                 || (self.startedLoading && [status isEqualToString:@"complete"])) {
            
            self.didLoadPage = YES;
            
            if ([status isEqualToString:@"interactive"]){
                // note: doubleValue will be 0 if interactiveDelay is null
                [self showWebviewWithDelay:[interactiveDelay doubleValue]];
            }
            else {
                [self showWebview];
            }
        }
    };
    
    if (self.webview) {
        NSString *readyState = [self.webview stringByEvaluatingJavaScriptFromString:@"document.readyState"];
        readyStateBlock(readyState, nil);
    } else if (self.wkWebview) {
        [self.wkWebview evaluateJavaScript:@"document.readyState" completionHandler:readyStateBlock];
    }
}

- (void)hideWebview
{
    if ([GoNativeAppConfig sharedAppConfig].disableAnimations) return;
    
    self.webview.alpha = self.hideWebviewAlpha;
    self.webview.userInteractionEnabled = NO;
    
    self.wkWebview.alpha = self.hideWebviewAlpha;
    self.wkWebview.userInteractionEnabled = NO;
    
    self.activityIndicator.alpha = 1.0;
    [self.activityIndicator startAnimating];
    
    // Show webview after 10 seconds just in case we never get a page finished callback
    // Otherwise, users may be stuck forever on the loading animation
    [self showWebviewWithDelay:10.0];
}

- (void)showWebview
{
    // cancel any other pending calls to showWebView
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showWebview) object:nil];
    
    self.startedLoading = NO;
    [self.timer invalidate];
    self.timer = nil;
    self.webview.userInteractionEnabled = YES;
    self.wkWebview.userInteractionEnabled = YES;
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^(void){
        self.webview.alpha = 1.0;
        self.wkWebview.alpha = 1.0;
        self.activityIndicator.alpha = 0.0;
    } completion:^(BOOL finished){
        [self.activityIndicator stopAnimating];
    }];
}

- (void)showWebviewWithDelay:(NSTimeInterval)delay
{
    [self performSelector:@selector(showWebview) withObject:nil afterDelay:delay];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self didFailLoadWithError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self didFailLoadWithError:error];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self didFailLoadWithError:error];
}

- (void)didFailLoadWithError:(NSError*)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    // show webview unless navigation was canceled, which is most likely due to a different page being requested
    if (![error.domain isEqualToString:NSURLErrorDomain] || error.code != NSURLErrorCancelled) {
        [self showWebview];
    }
    
    if ([[error domain] isEqualToString:NSURLErrorDomain] && [error code] == NSURLErrorNotConnectedToInternet) {
        NSURL *offlineFile = [[NSBundle mainBundle] URLForResource:@"offline" withExtension:@"html"];
        NSString *html = [NSString stringWithContentsOfURL:offlineFile encoding:NSUTF8StringEncoding error:nil];
        [self.wkWebview loadHTMLString:html baseURL:[NSURL URLWithString:@"http://offline/"]];
        [self.webview loadHTMLString:html baseURL:[NSURL URLWithString:@"http://offline/"]];
    }
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

- (NSDictionary*)getConnectivity
{
    LEANAppDelegate *appDelegate = (LEANAppDelegate*)[UIApplication sharedApplication].delegate;
    Reachability *reachability = appDelegate.internetReachability;
    NetworkStatus status = [reachability currentReachabilityStatus];
    NSString *statusString;
    NSNumber *connected;

    switch (status) {
        case NotReachable:
            statusString = @"DISCONNECTED";
            connected = [NSNumber numberWithBool:NO];
            break;
        case ReachableViaWiFi:
            statusString = @"WIFI";
            connected = [NSNumber numberWithBool:YES];
            break;
        case ReachableViaWWAN:
            statusString = @"MOBILE";
            connected = [NSNumber numberWithBool:YES];
            break;
            
        default:
            statusString = @"UNKNOWN";
            break;
    }
    
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:2];
    [result setObject:statusString forKey:@"type"];
    if (connected) {
        [result setObject:connected forKey:@"connected"];
    }
    
    return result;
}

#pragma mark - MFMailComposeViewControllerDelegate
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Location

-(void)checkLocationPermissionWithBlock:(void (^)(void))block
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        NSError *error = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil];
        [self locationManager:self.locationManager didFailWithError:error];
    } else if (status == kCLAuthorizationStatusNotDetermined) {
        self.locationPermissionBlock = block;
        [self.locationManager requestWhenInUseAuthorization];
    } else {
        block();
    }
}

-(void)requestLocation
{
    [self checkLocationPermissionWithBlock:^{
        [self.locationManager requestLocation];
        if (self.locationManager.location) {
            [self receivedLocation:self.locationManager.location];
        }
    }];
}

-(void)startWatchingLocation
{
    [self checkLocationPermissionWithBlock:^{
        [self.locationManager startUpdatingLocation];
    }];
}

-(void)stopWatchingLocation
{
    [self.locationManager stopUpdatingLocation];
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status != kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestLocation];
    }
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSMutableDictionary *jsError = [NSMutableDictionary dictionaryWithObjectsAndKeys:@1, @"PERMISSION_DENIED", @2, @"POSITION_UNAVAILABLE", @3, @"TIMEOUT", nil];
    
    if (error.code == kCLErrorDenied) {
        jsError[@"code"] = @1;
        jsError[@"message"] = @"User denied Geolocation";
    } else if (error.code == kCLErrorLocationUnknown) {
        jsError[@"code"] = @2;
        jsError[@"message"] = @"Position unavailable";
    }
    
    NSString *js = [LEANUtilities createJsForCallback:@"gonative_geolocation_failed" data:jsError];
    [self runJavascript:js];
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *location = [locations lastObject];
    [self receivedLocation:location];
}

-(void)receivedLocation:(CLLocation*)location {
    NSMutableDictionary *coords = [NSMutableDictionary dictionary];
    coords[@"latitude"] = [NSNumber numberWithDouble:location.coordinate.latitude];
    coords[@"longitude"] = [NSNumber numberWithDouble:location.coordinate.longitude];
    coords[@"accuracy"] = [NSNumber numberWithDouble:location.horizontalAccuracy];
    if (location.verticalAccuracy > 0) {
        coords[@"altitude"] = [NSNumber numberWithDouble:location.altitude];
        coords[@"altitudeAccuracy"] = [NSNumber numberWithDouble:location.verticalAccuracy];
    } else {
        coords[@"altitude"] = [NSNull null];
        coords[@"altitudeAccuracy"] = [NSNull null];
    }
    coords[@"heading"] = location.course < 0 ? [NSNull null] : [NSNumber numberWithDouble:location.course];
    coords[@"speed"] = location.speed < 0 ? [NSNull null] : [NSNumber numberWithDouble:location.speed];
    
    double ts = trunc([[NSDate date] timeIntervalSince1970] * 1000);
    NSNumber *timestamp = [NSNumber numberWithDouble:ts];
    
    NSDictionary *data = @{
                           @"timestamp": timestamp,
                           @"coords": coords
                           };
    
    NSString *js = [LEANUtilities createJsForCallback:@"gonative_geolocation_received" data:data];
    [self runJavascript:js];
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

- (BOOL)prefersStatusBarHidden
{
    return self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (self.statusBarStyle) {
        return [self.statusBarStyle integerValue];
    }
    
    if ([[GoNativeAppConfig sharedAppConfig].iosTheme isEqualToString:@"dark"]) {
        return UIStatusBarStyleLightContent;
    } else {
        return UIStatusBarStyleDefault;
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    [self adjustInsets];
    [self applyStatusBarOverlay];
}

- (void)viewWillLayoutSubviews
{
    if (self.statusBarBackground) {
        // fix sizing (usually because of rotation) when navigation bar is hidden
        CGSize statusSize = [UIApplication sharedApplication].statusBarFrame.size;
        CGFloat height = MIN(statusSize.height, statusSize.width);
        // fix for double height status bar on non-iPhoneX
        if (height == 40) {
            height = 20;
        }
        CGFloat width = MAX(statusSize.height, statusSize.width);
        self.statusBarBackground.frame = CGRectMake(0, 0, width, height);
    }
    [self adjustInsets];
    
    // bar thickness changes when rotating, so resize internal contents
    [self.tabBar invalidateIntrinsicContentSize];
    [self.toolbar invalidateIntrinsicContentSize];
}

-(void)orientationChanged
{
    // fixes status bar weirdness when rotating video to landscape
    [self setNeedsStatusBarAppearanceUpdate];
}

-(void)viewDidLayoutSubviews
{
    // Heights of tab and tool bars will change after rotation, as bars are thinner on landscape.
    // If the bar is hidden, then the bottom constraint is based on the thickness of the bar.
    // The constraint will need to be updated to keep everything in the right place.
    if (self.tabBar.hidden) {
        [self hideBottomBar:self.tabBar constraint:self.tabBarBottomConstraint animated:NO];
    }
    if (self.toolbar.hidden) {
        [self hideBottomBar:self.toolbar constraint:self.toolbarBottomConstraint animated:NO];
    }
}

@end
