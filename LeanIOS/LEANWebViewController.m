//
//  LEANWebViewController.m
//  LeanIOS
//
//  Created by Weiyin He on 2/10/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <MessageUI/MessageUI.h>

#import "LEANWebViewController.h"
#import "LEANAppDelegate.h"
#import "LEANUtilities.h"
#import "GoNativeAppConfig.h"
#import "LEANMenuViewController.h"
#import "LEANNavigationController.h"
#import "LEANRootViewController.h"
#import "LEANWebFormController.h"
#import "NSURL+LEANUtilities.h"
#import "LEANCustomAction.h"
#import "LEANUrlInspector.h"
#import "LEANProfilePicker.h"
#import "LEANInstallation.h"
#import "LEANTabManager.h"
#import "LEANToolbarManager.h"
#import "LEANWebViewPool.h"
#import "LEANDocumentSharer.h"
#import "Reachability.h"
#import "LEANActionManager.h"
#import "LEANIdentityService.h"
#import "GNRegistrationManager.h"
#import "GonativeIO-swift.h"

@interface LEANWebViewController () <UISearchBarDelegate, UIActionSheetDelegate, UIScrollViewDelegate, UITabBarDelegate, WKNavigationDelegate, WKUIDelegate, MFMailComposeViewControllerDelegate>

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

@property BOOL willBeLandscape;
@property BOOL keyboardVisible;
@property CGRect keyboardRect; // in window coordinates

@property NSURLRequest *currentRequest;
@property NSInteger urlLevel; // -1 for unknown
@property NSString *profilePickerJs;
@property NSString *analyticsJs;
@property NSTimer *timer;
@property BOOL startedLoading; // for transitions, keeps track of whether document.readystate has switched to "loading"
@property BOOL didLoadPage; // keep track of whether any page has loaded. If network reconnects, then will attempt reload if there is no page loaded
@property BOOL isPoolWebview;
@property UIView *defaultTitleView;
@property UIView *navigationTitleImageView;
@property CGFloat hideWebviewAlpha;

@property NSString *postLoadJavascript;
@property NSString *postLoadJavascriptForRefresh;

@property BOOL visitedLoginOrSignup;

@property LEANActionManager *actionManager;
@property LEANToolbarManager *toolbarManager;

@end

@implementation LEANWebViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.checkLoginSignup = YES;
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    
    self.hideWebviewAlpha = [appConfig.hideWebviewAlpha floatValue];
    
    // push login controller if it should be the first thing shown
    if (appConfig.loginIsFirstPage && [self isRootWebView]) {
        LEANWebFormController *wfc = [[LEANWebFormController alloc] initWithDictionary:appConfig.loginConfig title:appConfig.appName isLogin:YES];
        wfc.originatingViewController = self;
        [self.navigationController pushViewController:wfc animated:NO];
    }
    
    // hide toolbar and tab bar on initial launch
    [self hideTabBarAnimated:NO];
    [self hideToolbarAnimated:NO];
    
    self.tabManager = [[LEANTabManager alloc] initWithTabBar:self.tabBar webviewController:self];
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
        // hack to space it a bit closer to the left edge
        UIBarButtonItem *negativeSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        [negativeSpacer setWidth:-10];
        
        self.navigationItem.leftBarButtonItems = @[negativeSpacer, self.navButton];
    }
    self.defaultLeftNavBarItems = self.navigationItem.leftBarButtonItems;
    
    // profile picker
    if (appConfig.profilePickerJS && [appConfig.profilePickerJS length] > 0) {
        self.profilePickerJs = appConfig.profilePickerJS;
    }
    
    if (appConfig.analytics) {
        NSString *distribution = [LEANInstallation info][@"distribution"];
        NSInteger idsite;
        if ([distribution isEqualToString:@"appstore"]) idsite = appConfig.idsite_prod;
        else idsite = appConfig.idsite_test;
        
        
        NSString *template = @"var _paq = _paq || []; "
        "_paq.push(['trackPageView']); "
        "_paq.push(['enableLinkTracking']); "
        "(function() { "
        "    var u = 'https://analytics.gonative.io/'; "
        "    _paq.push(['setTrackerUrl', u+'piwik.php']); "
        "    _paq.push(['setSiteId', %d]); "
        "    var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0]; g.type='text/javascript'; "
        "    g.defer=true; g.async=true; g.src=u+'piwik.js'; s.parentNode.insertBefore(g,s); "
        "})(); ";
        self.analyticsJs = [NSString stringWithFormat:template, idsite];
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
            self.initialUrl = appConfig.initialURL;
        }
        [self loadUrl:self.initialUrl];
        
        // nav title image
        [self checkNavigationTitleImageForUrl:self.initialUrl];

    }
    
    // hidden nav bar
    if (!appConfig.showNavigationBar && [self isRootWebView]) {
        UINavigationBar *bar = [[UINavigationBar alloc] init];
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
    if (![GoNativeAppConfig sharedAppConfig].pullToRefresh) return;
    
    if (!self.pullRefreshControl) {
        self.pullRefreshControl = [[UIRefreshControl alloc] init];
        [self.pullRefreshControl addTarget:self action:@selector(pullToRefresh:) forControlEvents:UIControlEventValueChanged];
        self.pullRefreshControl.tintColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
    }
    
    [self.wkWebview.scrollView addSubview:self.pullRefreshControl];
    [self.webview.scrollView addSubview:self.pullRefreshControl];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self addPullToRefresh];
    
    if ([self isRootWebView]) {
        [self.navigationController setNavigationBarHidden:![GoNativeAppConfig sharedAppConfig].showNavigationBar animated:YES];
    } else if ([GoNativeAppConfig sharedAppConfig].showNavigationBarWithNavigationLevels) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    
    [self adjustInsets];
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
        [self.tabManager autoSelectTabForUrl:url];
        
        GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
        [self setSidebarEnabled:[appConfig shouldShowSidebarForUrl:[url absoluteString]]];
    });
}

- (void)checkNavigationForUrl:(NSURL*) url;
{
    if (![GoNativeAppConfig sharedAppConfig].tabMenus) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideTabBarAnimated:YES];
        });
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tabManager didLoadUrl:url];
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
    if (bar.hidden) return;
    
    [self.view layoutIfNeeded];
    CGFloat barHeight = MIN(bar.bounds.size.width, bar.bounds.size.height);
    constraint.constant = -barHeight;
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
            [self sharePage:sender];
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
    
    // right: chromecast button
    LEANAppDelegate *appDelegate = (LEANAppDelegate*)[[UIApplication sharedApplication] delegate];
    if (appDelegate.castController.castButton && !appDelegate.castController.castButton.customView.hidden) {
        [buttons addObject:appDelegate.castController.castButton];
    }
    
    // right: document share button
    if (self.shareButton) {
        [buttons addObject:self.shareButton];
    }
    
    
    [self.navigationItem setRightBarButtonItems:buttons animated:animated];
}

- (void) sharePage:(id)sender
{
    UIActivityViewController * avc = [[UIActivityViewController alloc]
                                      initWithActivityItems:@[[self.currentRequest URL]] applicationActivities:nil];
    // The activity view inherits tint color, but always has a light background, making the buttons
    // impossible to read if we have light tint color. Force the tint to be the ios default.
    [avc.view setTintColor:[UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0]];
    
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
    [self loadRequest:self.currentRequest andJavascript:self.postLoadJavascriptForRefresh];
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
            if ([predicate evaluateWithObject:urlString]) {
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
    // the default url character does not escape '/', so use this function. NSString is toll-free bridged with CFStringRef
    NSString *searchText = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)searchBar.text,NULL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",kCFStringEncodingUTF8 ));
    // the search template can have any allowable url character, but we need to escape unicode characters like '✓' so that the NSURL creation doesn't die.
    NSString *searchTemplate = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)[GoNativeAppConfig sharedAppConfig].searchTemplateURL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",NULL,kCFStringEncodingUTF8 ));
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
    return [self shouldLoadRequest:request isMainFrame:isMainFrame isUserAction:isUserAction];
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
    BOOL shouldLoad = [self shouldLoadRequest:navigationAction.request isMainFrame:navigationAction.targetFrame.isMainFrame isUserAction:isUserAction];
    if (shouldLoad) decisionHandler(WKNavigationActionPolicyAllow);
    else decisionHandler(WKNavigationActionPolicyCancel);
}

- (BOOL)shouldLoadRequest:(NSURLRequest*)request isMainFrame:(BOOL)isMainFrame isUserAction:(BOOL)isUserAction
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
    
    // touchid authentication
    if ([@"gonative" isEqualToString:url.scheme] && [@"auth" isEqualToString:url.host]) {
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
    if ([@"gonative" isEqualToString:url.scheme] && [@"registration" isEqualToString:url.host]
        && [@"/send" isEqualToString:url.path]) {
        
        NSDictionary *query = [LEANUtilities parseQuaryParamsWithUrl:url];
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
                NSArray *rawURLparts = [url.resourceSpecifier componentsSeparatedByString:@"?"];
                if (rawURLparts.count > 2) {
                    NSLog(@"error parsing mailto %@", url);
                    return;
                }
                
                NSMutableArray *toRecipients = [NSMutableArray array];
                NSArray *recipients = [rawURLparts[0] componentsSeparatedByString:@","];
                for (NSString *recipient in recipients) {
                    if (recipient.length > 0) {
                        [toRecipients addObject:recipient];
                    }
                }
                
                MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
                mc.mailComposeDelegate = self;
                
                if (rawURLparts.count == 2) {
                    NSString *queryString = rawURLparts[1];
                    NSArray *queryParams = [queryString componentsSeparatedByString:@"&"];
                    for (NSString *param in queryParams) {
                        NSArray *keyValue = [param componentsSeparatedByString:@"="];
                        if (keyValue.count != 2) {
                            continue;
                        }
                        
                        NSString *key = [keyValue[0] lowercaseString];
                        NSString *value = [keyValue[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                        
                        if ([key isEqualToString:@"subject"]) {
                            [mc setSubject:value];
                        } else if ([key isEqualToString:@"body"]) {
                            [mc setMessageBody:value isHTML:NO];
                        } else if ([key isEqualToString:@"to"]) {
                            [toRecipients addObjectsFromArray:[value componentsSeparatedByString:@","]];
                        } else if ([key isEqualToString:@"cc"]) {
                            [mc setCcRecipients:[value componentsSeparatedByString:@","]];
                        } else if ([key isEqualToString:@"bcc"]) {
                            [mc setBccRecipients:[value componentsSeparatedByString:@","]];
                        }
                    }
                }
                
                [mc setToRecipients:toRecipients];
                [self presentViewController:mc animated:YES completion:nil];
            });
        } else {
            NSLog(@"MFMailComposeViewController cannot send mail. Ignoring mailto link");
        }
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
    
    // checkLoginSignup might be NO when returning from login screen with loginIsFirstPage
    BOOL checkLoginSignup = self.checkLoginSignup;
    self.checkLoginSignup = YES;
    
    // log in
    if (checkLoginSignup && appConfig.loginConfig &&
        [url matchesPathOf:appConfig.loginURL]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showWebview];
        });
        
        if (appConfig.loginIsFirstPage) {
            if (self.currentRequest) {
                // this is not the first page loaded, so was probably called via Logout.
                
                // recheck status as it has probably changed
                [[LEANLoginManager sharedManager] checkLogin];
                
                LEANWebFormController *wfc = [[LEANWebFormController alloc] initWithDictionary:appConfig.loginConfig title:appConfig.appName isLogin:YES];
                
                wfc.originatingViewController = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.navigationController pushViewController:wfc animated:YES];
                });
            } else {
                // this is the first page loaded, which means that the form controller has already been pushed in viewDidLoad. Do nothing.
            }
            
            return NO;
        }
        
        LEANWebFormController *wfc = [[LEANWebFormController alloc] initWithDictionary:appConfig.loginConfig title:@"Log In" isLogin:YES];
        wfc.originatingViewController = self;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UINavigationController *formSheet = [[UINavigationController alloc] initWithRootViewController:wfc];
            formSheet.modalPresentationStyle = UIModalPresentationFormSheet;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:formSheet animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:wfc animated:YES];
            });
        }
        return NO;
    }
    
    // sign up
    if (checkLoginSignup && appConfig.signupURL &&
        [url matchesPathOf:appConfig.signupURL]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showWebview];
        });
        
        LEANWebFormController *wfc = [[LEANWebFormController alloc] initWithDictionary:appConfig.signupConfig title:@"Sign Up" isLogin:NO];
        wfc.originatingViewController = self;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UINavigationController *formSheet = [[UINavigationController alloc] initWithRootViewController:wfc];
            formSheet.modalPresentationStyle = UIModalPresentationFormSheet;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:formSheet animated:YES completion:nil];
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:wfc animated:YES];
            });
        }
        return NO;
    }
    
    // other forms
    if (appConfig.interceptForms) {
        for (id form in appConfig.interceptForms) {
            if ([url matchesPathOf:[NSURL URLWithString:form[@"interceptUrl"]]]) {
                [self showWebview];
                
                LEANWebFormController *wfc = [[LEANWebFormController alloc] initWithJsonObject:form];
                wfc.originatingViewController = self;
                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                    UINavigationController *formSheet = [[UINavigationController alloc] initWithRootViewController:wfc];
                    formSheet.modalPresentationStyle = UIModalPresentationFormSheet;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self presentViewController:formSheet animated:YES completion:nil];
                        
                    });
                }
                else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.navigationController pushViewController:wfc animated:YES];
                    });
                }
                
                return NO;
            }
        }
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
            if ([predicate evaluateWithObject:urlString]) {
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
    ((LEANAppDelegate*)[[UIApplication sharedApplication] delegate]).currentRequest = request;
    
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
    
    // Do not hide the webview if url.fragment exists. There sometimes is an issue with single-page apps where shouldLoadRequest
    // is called for SPA page loads if there is a fragment. We will never get an sort of page finished callback, so the page
    // is always hidden.
    BOOL hideWebView = !url.fragment;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (hideWebView) [self hideWebview];
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
    
    // remove pull to refresh
    [self.pullRefreshControl removeFromSuperview];
    
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
        [self.view insertSubview:newView aboveSubview:oldView];
        [oldView removeFromSuperview];
    }
    [self adjustInsets];
    // re-scroll after adjusting insets
    [scrollView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    
    // Add layout constraints
    // The top, left, and right are straightforward.
    // For the bottom, by default we align to the bottom layout guide. However, if a toolbar and/or
    // tab bar are shown, we want the bottom to be pushed up by them. So make the bottom layout guide
    // have a lower priority, then add constraints to the tab bar and toolbar with "great than or equal"
    // relationships.
    // top layout guide
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.topLayoutGuide attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    // left (leading)
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    // right (trailing)
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    // bottom layout guide (750 priority)
    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.bottomLayoutGuide attribute:NSLayoutAttributeTop multiplier:1 constant:0];
    constraint.priority = UILayoutPriorityDefaultHigh;
    [self.view addConstraint:constraint];
    // tab bar <=
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tabBar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationLessThanOrEqual toItem:newView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    // toolbar <=
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.toolbar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationLessThanOrEqual toItem:newView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    
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
    
    [self addPullToRefresh];
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
        if (!url || [url.host isEqualToString:@"offline"]) return;
        
        self.didLoadPage = YES;
        
        [[LEANUrlInspector sharedInspector] inspectUrl:url];
        
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [self setNavigationButtonStatus];
        
        [LEANUtilities addJqueryToWebView:self.webview];
        [LEANUtilities addJqueryToWebView:self.wkWebview];
        
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
        
        // analytics
        if (self.analyticsJs && (!self.webview || !self.webview.isLoading)) {
            [self runJavascript:self.analyticsJs];
        }
        
        if ([GoNativeAppConfig sharedAppConfig].enableChromecast) {
            [self detectVideo];
            // [self performSelector:@selector(detectVideo) withObject:nil afterDelay:1];
        }
        
        [self updateCustomActions];
        
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
        
        // identity service
        [[LEANIdentityService sharedService] checkUrl:url];
        
        // registration service
        [[GNRegistrationManager sharedManager] checkUrl:url];
        
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
        [self loadUrl:[GoNativeAppConfig sharedAppConfig].initialURL];
    }
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:frame.request.URL.host message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler();
    }];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:frame.request.URL.host message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }];
    [alert addAction:okAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
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

- (void)detectVideo
{
    NSString *dataUrlJs = @"jwplayer().config.fallbackDiv.getAttribute('data-url_alt');";
    NSString *titleJs = @"jwplayer().config.fallbackDiv.getAttribute('data-title');";
    
    LEANAppDelegate *appDelegate = (LEANAppDelegate*)[[UIApplication sharedApplication] delegate];
    LEANCastController *castController = appDelegate.castController;
    
    if (self.webview) {
        NSURL *url = nil;
        NSString *title = nil;
        NSString *dataurl = [self.webview stringByEvaluatingJavaScriptFromString:dataUrlJs];
        
        if (dataurl && [dataurl length] > 0) {
            url = [NSURL URLWithString:dataurl relativeToURL:self.currentRequest.URL];
            title = [self.webview stringByEvaluatingJavaScriptFromString:titleJs];
        }
        
        castController.urlToPlay = url;
        castController.titleToPlay = title;

    }
    else if (self.wkWebview) {
        [self.wkWebview evaluateJavaScript:dataUrlJs completionHandler:^(id result, NSError *error) {
            if ([result isKindOfClass:[NSString class]] && [result length] > 0) {
                NSURL *url = [NSURL URLWithString:result relativeToURL:self.currentRequest.URL];
                
                [self.wkWebview evaluateJavaScript:titleJs completionHandler:^(id result2, NSError *error2) {
                    castController.urlToPlay = url;
                    castController.titleToPlay = result2;
                }];
                
            } else {
                castController.urlToPlay = nil;
                castController.titleToPlay = nil;
            }
        }];
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

#pragma mark - MFMailComposeViewControllerDelegate
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
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
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        return NO;
    } else {
        return self.willBeLandscape;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if ([[GoNativeAppConfig sharedAppConfig].iosTheme isEqualToString:@"dark"]) {
        return UIStatusBarStyleLightContent;
    } else {
        return UIStatusBarStyleDefault;
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    [self adjustInsets];
}

- (void)viewWillLayoutSubviews
{
    if (self.statusBarBackground) {
        // fix sizing (usually because of rotation) when navigation bar is hidden
        CGSize statusSize = [UIApplication sharedApplication].statusBarFrame.size;
        CGFloat height = 20;
        CGFloat width = MAX(statusSize.height, statusSize.width);
        self.statusBarBackground.frame = CGRectMake(0, 0, width, height);
    }
    [self adjustInsets];
}


@end
