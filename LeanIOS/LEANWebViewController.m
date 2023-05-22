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
#import <AVFoundation/AVFoundation.h>

#import "LEANWebViewController.h"
#import "LEANAppDelegate.h"
#import "LEANUtilities.h"
#import "GNCustomHeaders.h"
#import "LEANMenuViewController.h"
#import "LEANNavigationController.h"
#import "LEANRootViewController.h"
#import "LEANJsCustomCodeExecutor.h"
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
#import "LEANRegexRulesManager.h"
#import "LEANWebViewIntercept.h"
#import "GNFileWriterSharer.h"
#import "GNConfigPreferences.h"
#import "GNBackgroundAudio.h"
#import "GonativeIO-Swift.h"
#import <AppTrackingTransparency/ATTrackingManager.h>
#import "GNJSBridgeInterface.h"
#import "GNLogManager.h"
@import GoNativeCore;

#define OFFLINE_URL @"http://offline/"
#define LOCAL_FILE_URL @"http://localFile/"

@interface LEANWebViewController () <UISearchBarDelegate, UIActionSheetDelegate, UIScrollViewDelegate, UITabBarDelegate, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, MFMailComposeViewControllerDelegate, CLLocationManagerDelegate, GNJavascriptRunner>

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
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *pluginViewTopWebviewBottomConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *toolbarTopWebviewBottomConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *tabbarTopWebviewBottomConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *webviewLeftSafeAreaLeft;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *webviewRightSafeAreaRight;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *toolbarLeftSafeAreaLeft;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *toolbarRightSafeAreaRight;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *tabbarLeftSafeAreaLeft;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *tabbarRightSafeAreaRight;
@property IBOutlet UIView *webviewContainer;
@property NSArray *defaultToolbarItems;
@property UIBarButtonItem *customActionButton;
@property NSArray *customActions;

@property UIView *statusBarBackground;
@property UIVisualEffectView *blurEffectView;
@property UIBarButtonItem *shareButton;
@property UIRefreshControl *pullRefreshControl;

@property BOOL keyboardVisible;
@property CGRect keyboardRect; // in window coordinates

@property NSURLRequest *currentRequest;
@property NSInteger urlLevel; // -1 for unknown
@property BOOL isWindowOpen;
@property NSString *profilePickerJs;
@property NSTimer *timer;
@property BOOL startedLoading; // for transitions, keeps track of whether document.readystate has switched to "loading"
@property BOOL didLoadPage; // keep track of whether any page has loaded. If network reconnects, then will attempt reload if there is no page loaded
@property BOOL isPoolWebview;
@property UIView *defaultTitleView;
@property UIView *navigationTitleImageView;
@property CGFloat hideWebviewAlpha;
@property BOOL statusBarOverlay;
@property CGFloat savedScreenBrightness;
@property BOOL restoreBrightnessOnNavigation;
@property BOOL sidebarItemsEnabled;

@property NSString *postLoadJavascript;
@property NSString *postLoadJavascriptForRefresh;

@property (nonatomic, copy) void (^locationPermissionBlock)(void);

@property BOOL visitedLoginOrSignup;

@property LEANActionManager *actionManager;
@property LEANToolbarManager *toolbarManager;
@property LEANRegexRulesManager *regexRulesManager;
@property CLLocationManager *locationManager;
@property GNFileWriterSharer *fileWriterSharer;
@property NSString *connectivityCallback;
@property GNBackgroundAudio *backgroundAudio;
@property GNConfigPreferences *configPreferences;
@property LEANDocumentSharer *documentSharer;
@property GNRegistrationManager *registrationManager;
@property GNLogManager *logManager;
@property GNCustomHeaders *customHeadersManager;

@property NSNumber* statusBarStyle; // set via native bridge, only works if no navigation bar
@property IBOutlet NSLayoutConstraint *topGuideConstraint; // modify constant to place content under status bar

@property IBOutlet UIView *pluginView;
@property GNJSBridgeInterface *JSBridgeInterface;
@property NSString *JSBridgeScript;

@property NSUInteger prevBackHistoryCount;

@end

@implementation LEANWebViewController

static CGRect sharePopOverRect; // last touch coordinates in CGRect
static NSInteger _currentWindows = 0;

+ (NSInteger)currentWindows {
  return _currentWindows;
}

+ (void)setCurrentWindows:(NSInteger) currentWindows {
    _currentWindows = currentWindows;
    [WindowsController windowCountChanged];
}

- (void)updateWindowsController {
    [WindowsController windowCountChanged];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self becomeFirstResponder];
    LEANWebViewController.currentWindows += 1;
    self.checkLoginSignup = YES;
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    
    // enable touch listener only for iPads
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        UITapGestureRecognizer *coordinateListener =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:nil];
        coordinateListener.delegate = (id)self;
        // Set required taps and number of touches
        [coordinateListener setNumberOfTapsRequired:1];
        [coordinateListener setNumberOfTouchesRequired:1];
        [[self view] addGestureRecognizer:coordinateListener];
    }
    
    self.hideWebviewAlpha = [appConfig.hideWebviewAlpha floatValue];
    self.statusBarOverlay = NO;
    self.savedScreenBrightness = -1;
    self.restoreBrightnessOnNavigation = NO;
    self.sidebarItemsEnabled = YES;
    
    self.tabManager = [[LEANTabManager alloc] initWithTabBar:self.tabBar webviewController:self];
    self.toolbarManager = [[LEANToolbarManager alloc] initWithToolbar:self.toolbar webviewController:self];
    self.JSBridgeInterface = [[GNJSBridgeInterface alloc] init];
    
    self.customHeadersManager = [[GNCustomHeaders alloc] init];
    
    // set title to application title
    if ([appConfig.navTitles count] == 0) {
        self.navigationItem.title = appConfig.appName;
    }
    
    // add nav button
    if (appConfig.showNavigationMenu &&  [self isRootWebView]) {
        [self showSidebarNavButton];
    }
    
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
        if (appConfig.userAgentReady) {
            [self initializeWebview];
        } else {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kGoNativeAppConfigNotificationUserAgentReady object:nil];
        }
    }
    
    // hide ad banner view initially
    self.pluginViewTopWebviewBottomConstraint.active = NO;
    
    // hidden nav bar
    if (!appConfig.showNavigationBar && [self isRootWebView]) {
        UIToolbar *bar = [[UIToolbar alloc] init];
        if ([appConfig.iosTheme isEqualToString:@"dark"]) {
            bar.barStyle = UIBarStyleBlack;
        }
        self.statusBarBackground = bar;
        [self.view addSubview:self.statusBarBackground];
    }
    
    [self updateStatusBarBackgroundColor:[UIColor colorNamed:@"statusBarBackgroundColor"] enableBlurEffect:appConfig.iosEnableBlurInStatusBar];
    
    self.sidebarItemsEnabled = appConfig.showNavigationMenu && [self isRootWebView];
    [self showNavigationItemButtonsAnimated:NO];
    [self buildDefaultToobar];
    self.keyboardVisible = NO;
    self.keyboardRect = CGRectZero;
    [self adjustInsets];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedTabNavigation object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedNavigationTitles object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedNavigationLevels object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kReachabilityChangedNotification object:nil];
    
    // keyboard change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardHidden:) name:UIKeyboardWillHideNotification object:nil];
    
    // to help fix status bar issues when rotating in full-screen video
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    self.actionManager = [[LEANActionManager alloc] initWithWebviewController:self];
    
    self.regexRulesManager = [[LEANRegexRulesManager alloc] init];
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    self.fileWriterSharer = [[GNFileWriterSharer alloc] init];
    self.fileWriterSharer.wvc = self;
    
    self.backgroundAudio = [[GNBackgroundAudio alloc] init];
    self.configPreferences = [GNConfigPreferences sharedPreferences];
    self.documentSharer = [LEANDocumentSharer sharedSharer];
    self.registrationManager = [GNRegistrationManager sharedManager];
    
    // we will always be loading a page at launch, hide webview here to fix a white flash for dark themed apps
    [self hideWebview];
    
    // enable full screen webview i.e turn off safe area constraints
    if(appConfig.iosFullScreenWebview){
        // webview
        [self.webviewLeftSafeAreaLeft setActive:NO];
        [self.webviewRightSafeAreaRight setActive:NO];
        // tab Bar
        [self.tabbarLeftSafeAreaLeft setActive:NO];
        [self.tabbarRightSafeAreaRight setActive:NO];
        // toolbar
        [self.toolbarLeftSafeAreaLeft setActive:NO];
        [self.toolbarRightSafeAreaRight setActive:NO];
    }
    
    // set initial native theme
    NSString *mode = [[NSUserDefaults standardUserDefaults] objectForKey:@"darkMode"];
    [self setNativeTheme:mode ?: appConfig.iosDarkMode];
    [self updateStatusBarStyle:appConfig.iosStatusBarStyle];
    
    [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge runnerDidLoad:self];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

// called when screen touched
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    CGPoint point = [touch locationInView:touch.view];
    CGPoint pointOnScreen = [touch.view convertPoint:point toView:nil];
    sharePopOverRect = CGRectMake(pointOnScreen.x, pointOnScreen.y, 0, 0);
    return NO;
}

// set share dialog popover location in CGRect
- (void)setSharePopOverRect:(CGRect)rect
{
    sharePopOverRect = rect;
}

-(void)initializeWebview
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    WKWebViewConfiguration *config = [[NSClassFromString(@"WKWebViewConfiguration") alloc] init];
    config.processPool = [LEANUtilities wkProcessPool];
    config.allowsInlineMediaPlayback = YES;
    
    WKWebView *wv = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:self.wkWebview.frame configuration:config];
    [LEANUtilities configureWebView:wv];
    [self switchToWebView:wv showImmediately:NO];
    
    // load initial url
    self.urlLevel = -1;
    if (!self.initialUrl) {
        NSString *initialUrlPref = [self.configPreferences getInitialUrl];
        if (initialUrlPref && initialUrlPref.length > 0) {
            self.initialUrl = [NSURL URLWithString:initialUrlPref];
            [self.configPreferences setInitialUrl:initialUrlPref];
        }
    }
    if (!self.initialUrl && appConfig.initialURL) {
        NSURLComponents *components = [[NSURLComponents alloc] initWithURL:appConfig.initialURL resolvingAgainstBaseURL:NO];
        NSMutableArray *newQueryItems = [NSMutableArray array];
        if (components.queryItems) {
            [newQueryItems addObjectsFromArray:components.queryItems];
        }
        
        NSArray *addedQueryItems = [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge getInitialUrlQueryItems];
        [newQueryItems addObjectsFromArray:addedQueryItems];
        
        components.queryItems = newQueryItems;
        if (newQueryItems.count > 0) {
            self.initialUrl = [components URL];
        } else {
            self.initialUrl = appConfig.initialURL;
        }
    }
    [self loadUrl:self.initialUrl];
    
    // nav title image
    [self checkNavigationTitleImageForUrl:self.initialUrl];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.wkWebview) {
        @try {
            [self.wkWebview removeObserver:self forKeyPath:@"URL"];
            [self.wkWebview removeObserver:self forKeyPath:@"canGoBack"];
            [self.wkWebview removeObserver:self forKeyPath:@"canGoForward"];
        }
        @catch (NSException * __unused exception) {
        }
    }
    LEANWebViewController.currentWindows -= 1;
}

- (void)didReceiveNotification:(NSNotification*)notification
{
    NSString *name = [notification name];
    if ([name isEqualToString:kGoNativeAppConfigNotificationUserAgentReady]) {
        [self initializeWebview];
    }
    else if ([name isEqualToString:kLEANAppConfigNotificationProcessedTabNavigation]) {
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
        if (self.wkWebview) url = self.wkWebview.URL;
        
        if (url) {
            NSString *newTitle = [LEANWebViewController titleForUrl:url];
            if (newTitle) {
                self.navigationItem.title = newTitle;
            } else {
                self.navigationItem.title = [GoNativeAppConfig sharedAppConfig].appName;
            }
        }
    }
    else if ([name isEqualToString:kLEANAppConfigNotificationProcessedNavigationLevels]) {
        NSURL *url = nil;
        if (self.wkWebview) url = self.wkWebview.URL;
        
        if (url) {
            self.urlLevel = [LEANWebViewController urlLevelForUrl:url];
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
    
    // work around a bug starting in iOS 12 where the scroll doesn't readjust when the keyboard is hidden
    [self.wkWebview.scrollView setContentInset:UIEdgeInsetsMake(0.0001, 0, 0, 0)];
    [self.wkWebview.scrollView setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
}

- (void)retryFailedPage
{
    // return if we are not the top view controller
    if (![self isViewLoaded] || !self.view.window) return;
    
    // if there is a page loaded, user can just retry navigation
    if (self.didLoadPage) return;
    
    // return if currently loading a page
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
    
    self.wkWebview.scrollView.bounces = YES;
}

- (void)removePullRefresh
{
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
    } else if (self.isWindowOpen && [GoNativeAppConfig sharedAppConfig].windowOpenHideNavbar){
            [self.navigationController setNavigationBarHidden:YES animated:YES];
    } else if ([GoNativeAppConfig sharedAppConfig].showNavigationBarWithNavigationLevels) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    
    [self adjustInsets];
    
    NSURL *url = self.wkWebview.URL;
    if (url) {
        [self checkNavigationForUrl:url];
    }
    
    [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge runnerWillAppear:self];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.pullRefreshControl removeFromSuperview];
    
    if (self.isMovingFromParentViewController) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserFinishedLoading object:self];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }
    [super viewWillDisappear:animated];
    
    [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge runnerWillDisappear:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [self.tabManager traitCollectionDidChange:previousTraitCollection];
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
        [self showSidebarNavButton];
    } else {
        self.navButton = nil;
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
    if (!self.tabManager.javascriptTabs) {
        if (![GoNativeAppConfig sharedAppConfig].tabMenus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideTabBarAnimated:YES];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tabManager didLoadUrl:url];
                // toolbar may need to adjust its background to fill in behind home indicator
                [self.toolbar layoutSubviews];
            });
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.toolbarManager didLoadUrl:url];
        // toolbar may need to adjust its background to fill in behind home indicator
        [self.toolbar layoutSubviews];
    });
}

- (void)checkNavigationTitleImageForUrl:(NSURL*)url
{
    // check if navbar titles has regex match
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    BOOL showImageView = [appConfig shouldShowNavigationTitleImageForUrl:[url absoluteString]];
    NSArray *entries = appConfig.navTitles;
    
    if (!showImageView && entries) {
        NSString *urlString = [url absoluteString];
        for (NSDictionary *entry in entries) {
            NSPredicate *predicate = entry[@"predicate"];
            if ([predicate evaluateWithObject:urlString]) {
                showImageView = [entry[@"showImage"] boolValue];
                break;
            }
        }
    }
    
    // show logo in navigation bar
    if (showImageView) {
        // create the view if necesary
        if (!self.navigationTitleImageView) {
            UIImage *im = [GoNativeAppConfig sharedAppConfig].navigationTitleIcon;
            if (!im) im = [UIImage imageNamed:@"NavBarImage"];
            
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
    self.tabbarTopWebviewBottomConstraint.active = NO;
    [self hideBottomBar:self.tabBar constraint:self.tabBarBottomConstraint animated:animated];
}

- (void)hideToolbarAnimated:(BOOL)animated
{
    self.toolbarTopWebviewBottomConstraint.active = NO;
    [self hideBottomBar:self.toolbar constraint:self.toolbarBottomConstraint animated:animated];
}

- (void)showTabBarAnimated:(BOOL)animated
{
    self.tabbarTopWebviewBottomConstraint.active = YES;
    [self showBottomBar:self.tabBar constraint:self.tabBarBottomConstraint animated:animated];
}

- (void)showToolbarAnimated:(BOOL)animated
{
    self.toolbarTopWebviewBottomConstraint.active = YES;
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
        // use the gap between safeArea and statusbar as constraint if top nav bar is hidden
        float gap = self.view.safeAreaInsets.top - [UIApplication sharedApplication].statusBarFrame.size.height;
        self.topGuideConstraint.constant = gap < 20.0 ? -gap : 0;
    }
}

- (IBAction) buttonPressed:(id)sender
{
    switch ((long)[((UIBarButtonItem*) sender) tag]) {
        case 1:
            // back
            if (self.wkWebview.canGoBack)
                [self.wkWebview goBack];
            break;
            
        case 2:
            // forward
            if (self.wkWebview.canGoForward)
                [self.wkWebview goForward];
            break;
            
        case 3:
            //action
            [self sharePageWithUrl:nil text:nil sender:sender];
            break;
            
        case 4:
            //search
            NSLog(@"search");
            break;
            
        case 5:
            //refresh
            if (self.wkWebview.URL && ![[self.wkWebview.URL absoluteString] isEqualToString:@""]) {
                [self.wkWebview reload];
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
    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.showsCancelButton = NO;
    searchBar.delegate = self;
    
    self.navigationItem.titleView = searchBar;
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"button-cancel", @"Button: Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(searchCanceled)];
    
    [self.navigationItem setHidesBackButton:YES animated:YES];
    [self.navigationItem setLeftBarButtonItems:nil animated:YES];
    [self.navigationItem setRightBarButtonItems:@[cancelButton] animated:YES];
    [searchBar becomeFirstResponder];
}

- (void) sharePressed:(UIBarButtonItem*)sender
{
    [self.documentSharer shareRequest:self.currentRequest fromButton:sender];
}

- (void) showNavigationItemButtonsAnimated:(BOOL)animated
{
    NSMutableArray *buttons = [NSMutableArray array];
    NSMutableArray *leftButtons = [NSMutableArray array];
    NSMutableArray *rightButtons = [NSMutableArray array];
    
    BOOL backButtonShown = self.urlLevel > 1 || self.isWindowOpen;
    
    if (self.actionManager.items)
        [buttons addObjectsFromArray:self.actionManager.items];
    
    if (self.sidebarItemsEnabled && self.navButton)
        [buttons addObject:self.navButton];
    
    // put sidebar button to the left
    if (buttons.count == 1 && self.sidebarItemsEnabled && self.navButton) {
        [leftButtons addObject:self.navButton];
    }
    else if (buttons.count <= 3 && backButtonShown) {
        [rightButtons addObjectsFromArray:buttons];
    }
    // split buttons between the left and right navigation items
    else {
        float halfIndex = (float)[buttons count] / 2;
        for (NSInteger i = 0; i < [buttons count]; i++) {
            if (i < halfIndex) {
                [rightButtons addObject:buttons[i]];
            } else {
                [leftButtons insertObject:buttons[i] atIndex:0];
            }
        }
    }
    
    // do not override the back button
    if (!backButtonShown) {
        [self.navigationItem setLeftBarButtonItems:leftButtons animated:animated];
    }
    
    [self.navigationItem setRightBarButtonItems:rightButtons animated:animated];
    [self.navigationItem setHidesBackButton:NO animated:animated];
}

- (void) sharePage:(id)sender
{
    [self sharePageWithUrl:nil text:nil sender:sender];
}

- (void) sharePageWithUrl:(NSString*)url text:(NSString*)text sender:(id)sender;
{
    NSMutableArray *shareData = [NSMutableArray array];
    
    if (url) {
        [shareData addObject:[NSURL URLWithString:url relativeToURL:self.currentRequest.URL]];
    } else {
        [shareData addObject:self.currentRequest.URL];
    }
    
    if (text) {
        [shareData addObject:text];
    }

    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:shareData applicationActivities:nil];
    
    // For iPads starting in iOS 8, we need to specify where the pop over should occur from.
    if ( [avc respondsToSelector:@selector(popoverPresentationController)] ) {
        if ([sender isKindOfClass:[UIBarButtonItem class]]) {
            avc.popoverPresentationController.barButtonItem = sender;
        } else if ([sender isKindOfClass:[UIView class]]) {
            avc.popoverPresentationController.sourceView = sender;
        } else {
            if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
                avc.popoverPresentationController.sourceRect = sharePopOverRect;
            }
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
    NSString *currentUrl = self.wkWebview.URL.absoluteString;
    if ([currentUrl isEqualToString:OFFLINE_URL]) {
        if ([self.wkWebview canGoBack]) {
            [self.wkWebview goBack];
        } else {
            [self loadUrl:self.initialUrl];
        }
    } else {
        [self.wkWebview reload];
    }
}

- (void) logout
{
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
    if (self.wkWebview) {
        return [self.wkWebview canGoBack];
    } else {
        return NO;
    }
}

- (void)goBack
{
    if (self.wkWebview && [self.wkWebview canGoBack]) {
        [self.wkWebview goBack];
    }
}

- (BOOL)canGoForward
{
    if (self.wkWebview) {
        return [self.wkWebview canGoForward];
    } else {
        return NO;
    }
}

- (void)goForward
{
    if (self.wkWebview && [self.wkWebview canGoForward]) {
        [self.wkWebview goForward];
    }
}

- (void)refresh
{
    if (self.wkWebview) {
        [self.wkWebview reload];
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
        [self loadUrlAfterFilter:[NSURL URLWithString:url]];
    }
}

- (void) loadUrlAfterFilter:(NSURL *)url
{
    if([url.scheme isEqualToString:@"gonative"]){
        [self handleJSBridgeFunctions:url];
    } else {
        [self loadUrl:url];
    }
    
}

- (void) loadUrl:(NSURL *)url
{
    // in case this is called before the user agent stuff has finished
    if (![GoNativeAppConfig sharedAppConfig].userAgentReady) {
        self.initialUrl = url;
        return;
    }
    
    // local file url
    if ([url.scheme isEqualToString:@"file"]) {
        NSArray *components = [url.path componentsSeparatedByString:@"."];
        NSString *filePath;
        if (components.count == 2 && [components[components.count - 1] isEqualToString:@"html"]) {
            filePath = components[0];
        }
        NSURL *localUrl = [[NSBundle mainBundle] URLForResource:filePath withExtension:@"html"];
        if (localUrl) {
            NSString *html = [NSString stringWithContentsOfURL:localUrl encoding:NSUTF8StringEncoding error:nil];
            [self.wkWebview loadHTMLString:html baseURL:[NSURL URLWithString:LOCAL_FILE_URL]];
        } else {
            [self showOfflinePage];
        }
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSNumber *timeout = [GoNativeAppConfig sharedAppConfig].iosConnectionOfflineTime;
    if (timeout) {
        request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:[timeout doubleValue]];
    }
    [self loadRequest:request];
}


- (void) loadRequest:(NSURLRequest*) request
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserStartedLoading object:self];
    [self.wkWebview loadRequest:request];
    self.postLoadJavascript = nil;
    self.postLoadJavascriptForRefresh = nil;
}

- (void) loadUrl:(NSURL *)url andJavascript:(NSString *)js
{
    NSURL *currentUrl = nil;
    if (self.wkWebview) {
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
        [self.wkWebview loadRequest:request];
    }
}

- (void) loadRequest:(NSURLRequest *)request andJavascript:(NSString*)js
{
    self.postLoadJavascript = js;
    self.postLoadJavascriptForRefresh = js;
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserStartedLoading object:self];
    [self.wkWebview loadRequest:request];
}

- (void) runJavascript:(NSString *) script
{
    if (!script || script.length == 0) return;
    
    if ([NSThread isMainThread]) {
        [self.wkWebview evaluateJavaScript:script completionHandler:nil];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.wkWebview evaluateJavaScript:script completionHandler:nil];
        });
    }
}

- (void)runJavascriptWithCallback:(NSString *)callback data:(NSDictionary*)data {
    if (callback) {
        NSString *js = [LEANUtilities createJsForCallback:callback data:data];
        [self runJavascript:js];
    }
}

- (void)runCustomCode:(NSDictionary *)query {
    // execute code defined by the CustomCodeHandler
    // call LEANJsCustomCodeExecutor#setHandler to override this default handler
    NSDictionary *data = [LEANJsCustomCodeExecutor execute:query];

    NSString *callback = query[@"callback"];
    if (callback && callback.length > 0) {
        NSString *js = [LEANUtilities createJsForCallback:callback data:data];
        [self runJavascript:js];
    }
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
    if (!entries) return nil;
    
    NSString *urlString = [url absoluteString];
    for (NSDictionary *entry in entries) {
        NSPredicate *predicate = entry[@"predicate"];
        if ([predicate evaluateWithObject:urlString]) {
            return entry[@"title"];
        }
    }
    
    return nil;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if(event.subtype == UIEventSubtypeMotionShake){
        [[NSNotificationCenter defaultCenter] postNotificationName:kGoNativeCoreDeviceDidShake object:nil];
    }
}

#pragma mark - Search Bar Delegate
- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSString *searchText = [searchBar.text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *searchTemplate = self.actionManager.currentSearchTemplateUrl;
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


#pragma mark - WebView Delegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction preferences:(nonnull WKWebpagePreferences *)preferences decisionHandler:(nonnull void (^)(WKNavigationActionPolicy, WKWebpagePreferences * _Nonnull))decisionHandler  API_AVAILABLE(ios(13.0)) {
    BOOL shouldModifyRequest = [self.customHeadersManager shouldModifyRequest:navigationAction.request webview:webView];
    
    // is target="_blank" and we are allowing window open? Always accept, skipping logic. This makes
    // target="_blank" behave like window.open
    if (navigationAction.targetFrame == nil && [GoNativeAppConfig sharedAppConfig].enableWindowOpen) {
        decisionHandler(WKNavigationActionPolicyAllow, preferences);
        return;
    }
    
    BOOL isUserAction = navigationAction.navigationType == WKNavigationTypeLinkActivated || navigationAction.navigationType == WKNavigationTypeFormSubmitted;
    BOOL shouldLoad = [self shouldLoadRequest:navigationAction.request isMainFrame:navigationAction.targetFrame.isMainFrame isUserAction:isUserAction hideWebview:YES sender:nil];
    if (!shouldLoad) {
        decisionHandler(WKNavigationActionPolicyCancel, preferences);
        return;
    }
    
    [self.documentSharer receivedRequest:navigationAction.request];
    
    if (shouldModifyRequest &&
        navigationAction.targetFrame.isMainFrame &&
        ![OFFLINE_URL isEqualToString:navigationAction.request.URL.absoluteString]) {
        NSURLRequest *modifiedRequest = [self.customHeadersManager modifyRequest:navigationAction.request];
        decisionHandler(WKNavigationActionPolicyCancel, preferences);
        [self.wkWebview loadRequest:modifiedRequest];
        return;
    }
    
    if (@available(iOS 15.0, *)) {
        if (navigationAction.shouldPerformDownload) {
            decisionHandler(WKNavigationActionPolicyCancel, preferences);
            [self.documentSharer shareUrl:navigationAction.request.URL fromView:self.wkWebview];
            [self showWebviewWithDelay:0.5];
            return;
        }
    }
    
    decisionHandler(WKNavigationActionPolicyAllow, preferences);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    [self.documentSharer receivedWebviewResponse:navigationResponse.response];
    [self.toolbarManager setUrlMimeType:navigationResponse.response.MIMEType];
    
    if (navigationResponse.canShowMIMEType) {
        decisionHandler(WKNavigationResponsePolicyAllow);
        return;
    }
    
    [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge webView:webView handleURL:navigationResponse.response.URL];
    
    if ([@"application/vnd.apple.pkpass" isEqualToString:navigationResponse.response.MIMEType]) {
        decisionHandler(WKNavigationResponsePolicyCancel);
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
//                            PKPass *pass = [[PKPass alloc] initWithData:data error:&passError];
                            if (passError) {
                                NSLog(@"Error parsing pass from %@: %@", url, passError);
                            } else {
                                dispatch_async(dispatch_get_main_queue(), ^{
//                                    PKAddPassesViewController *apvc = [[PKAddPassesViewController alloc] initWithPass:pass];
//                                    [[self getTopPresentedViewController] presentViewController:apvc animated:YES completion:nil];
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
        return;
    }
    
    if (@available(iOS 15.0, *)) {
        decisionHandler(WKNavigationResponsePolicyDownload);
        return;
    }
    
    decisionHandler(WKNavigationResponsePolicyCancel);
}

- (void)webView:(WKWebView *)webView navigationAction:(WKNavigationAction *)navigationAction didBecomeDownload:(WKDownload *)download  API_AVAILABLE(ios(15.0)) {
    download.delegate = self;
}

- (void)webView:(WKWebView *)webView navigationResponse:(WKNavigationResponse *)navigationResponse didBecomeDownload:(WKDownload *)download  API_AVAILABLE(ios(15.0)) {
    download.delegate = self;
}

- (void)download:(nonnull WKDownload *)download decideDestinationUsingResponse:(nonnull NSURLResponse *)response suggestedFilename:(nonnull NSString *)suggestedFilename completionHandler:(nonnull void (^)(NSURL * _Nullable))completionHandler  API_AVAILABLE(ios(15.0)) {
    NSURL *url = [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:suggestedFilename isDirectory:YES];
    completionHandler(url);
}

-(void)webView:(WKWebView *)webView requestMediaCapturePermissionForOrigin:(WKSecurityOrigin *)origin initiatedByFrame:(WKFrameInfo *)frame type:(WKMediaCaptureType)type decisionHandler:(void (^)(WKPermissionDecision))decisionHandler  API_AVAILABLE(ios(15.0)){
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        decisionHandler(granted ? WKPermissionDecisionGrant : WKPermissionDecisionDeny);
    }];
}

-(void)initializeJSInterfaceInWebView:(WKWebView*) wkWebview
{
    [wkWebview.configuration.userContentController removeScriptMessageHandlerForName:GNJSBridgeName];
    [wkWebview.configuration.userContentController addScriptMessageHandler:self.JSBridgeInterface name:GNJSBridgeName];
}

- (void)openWindowWithUrl:(NSString *)urlString {
    NSURL *urlToOpen = [NSURL URLWithString:urlString];
    if (!urlToOpen) {
        return;
    }
    NSMutableURLRequest *requestToOpen = [NSMutableURLRequest requestWithURL:urlToOpen];
    // need to set mainDocumentURL to properly handle external links in shouldLoadRequest:
    requestToOpen.mainDocumentURL = urlToOpen;
    if (!requestToOpen) {
        return;
    }
    BOOL shouldLoad = [self shouldLoadRequest:requestToOpen isMainFrame:YES isUserAction:YES hideWebview:NO sender:nil];
    if (!shouldLoad) {
        return;
    }
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

- (void) handleJSBridgeFunctions:(id)data{
    NSString *currentUrl;
    if (self.wkWebview) {
        currentUrl = self.wkWebview.URL.absoluteString;
    }
    if (![LEANUtilities checkNativeBridgeUrl:currentUrl]) {
        NSLog(@"URL not authorized for native bridge: %@", currentUrl);
        return;
    }
    
    NSURL *url;
    NSDictionary *query;
    if([data isKindOfClass:[NSURL class]]){
        url = data;
        query = [LEANUtilities parseQueryParamsWithUrl:url];
    } else if([data isKindOfClass:[NSDictionary class]]) {
        url = [NSURL URLWithString:data[@"gonativeCommand"]];
        if(!url) return;
        if([data[@"data"] isKindOfClass:[NSDictionary class]]) query = data[@"data"];
    } else return;
    
    if (![((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge runner:self shouldLoadRequestWithURL:url withData:query]) {
        return;
    }
    
    [[GNJSBridgeHandler shared] handleUrl:url query:query wvc:(id)self];
}

// currently, sender is used to receive a selected UIBarButtonItem from the action bar
- (BOOL)shouldLoadRequest:(NSURLRequest*)request isMainFrame:(BOOL)isMainFrame isUserAction:(BOOL)isUserAction hideWebview:(BOOL)hideWebview sender:(id)sender
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
    
    // blob download
    if (urlString.length == 0) {
        // for some reason we will get an empty url before the actual blob url on iOS 11
        return NO;
    }
    // Only start blob downloads on the main frame
    if ([url.scheme isEqualToString:@"blob"] && isMainFrame) {
        [self.fileWriterSharer downloadBlobUrl:urlString];
        return NO;
    }
    
    // inject GoNative JS Bridge Library if regex matches
    if([LEANUtilities checkNativeBridgeUrl:urlString]){
        if(!self.JSBridgeScript){
            NSURL *GNJSBridgeFile = [[NSBundle mainBundle] URLForResource:@"GoNativeJSBridgeLibrary" withExtension:@"js"];
            if(GNJSBridgeFile)
                self.JSBridgeScript = [NSString stringWithContentsOfURL:GNJSBridgeFile encoding:NSUTF8StringEncoding error:nil];
        }
        if(self.JSBridgeScript){
            WKUserScript *GNJSBridgeLibrary = [[NSClassFromString(@"WKUserScript") alloc] initWithSource:self.JSBridgeScript injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
            [self.wkWebview.configuration.userContentController addUserScript:GNJSBridgeLibrary];
            
            // load plugins' js script
            [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge loadUserScriptsForContentController:self.wkWebview.configuration.userContentController];
        }
    } else {
        NSString *emptyJSBridgeScript = @"gonative = null";
        WKUserScript *GNJSBridgeLibrary = [[NSClassFromString(@"WKUserScript") alloc] initWithSource:emptyJSBridgeScript injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
        [self.wkWebview.configuration.userContentController addUserScript:GNJSBridgeLibrary];
    }
    
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
    }
    
    // JS Bridge Commands
    if ([@"gonative" isEqualToString:url.scheme]) {
        [self handleJSBridgeFunctions:url];
        return NO;
    }
    
    // tel links
    if ([url.scheme isEqualToString:@"tel"]) {
        NSString *telNumber = url.resourceSpecifier;
        if ([telNumber length] > 0) {
            NSURL *telPromptUrl = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt:%@", telNumber]];
            if ([[UIApplication sharedApplication] canOpenURL:telPromptUrl]) {
                [[UIApplication sharedApplication] openURL:telPromptUrl options:@{} completionHandler:nil];
            } else if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
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
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
        return NO;
    }
    
    // sms links
    if ([url.scheme isEqualToString:@"sms"]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        return NO;
    }
    
    // always allow iframes to load
    if (!isMainFrame && ![urlString isEqualToString:[[request mainDocumentURL] absoluteString]]) {
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
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            } else {
                [[UIApplication sharedApplication] openURL:request.URL options:@{} completionHandler:nil];
            }
        });
        
        return NO;
    }
    
    // external sites: don't launch if in iframe.
    if (isUserAction || (isMainFrame && ![[request URL] matchesPathOf:[self.currentRequest URL]])) {
        // first check regexInternalExternal
        NSDictionary *matchResult = [self.regexRulesManager matchesWithUrlString:urlString];
        BOOL matchedRegex = [matchResult[@"matches"] boolValue];
        if (matchedRegex) {
            BOOL isInternal = [matchResult[@"isInternal"] boolValue];
            if (!isInternal) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] openURL:request.URL options:@{} completionHandler:nil];
                });
                return NO;
            }
        }
        
        if (!matchedRegex) {
            if (![hostname isEqualToString:appConfig.initialHost] &&
                ![hostname hasSuffix:[@"." stringByAppendingString:appConfig.initialHost]]) {
                // open in external web browser
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] openURL:request.URL options:@{} completionHandler:nil];
                });
                return NO;
            }
        }
    }
    
    // Starting here, we are going to load the request, but possibly in a different webviewcontroller depending on the structured nav level
    if (self.restoreBrightnessOnNavigation) {
        if (self.savedScreenBrightness >= 0) {
            [UIScreen mainScreen].brightness = self.savedScreenBrightness;
        }
        self.restoreBrightnessOnNavigation = NO;
    }
    
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
    while (controllers && controllers.count > 0 &&
           ![[controllers lastObject] isKindOfClass:[LEANWebViewController class]]) {
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
        [[LEANWebViewPool sharedPool] disownWebview:self.wkWebview];
        self.isPoolWebview = NO;
    }
    
    // Do not hide the webview if url.fragment exists and the url is the same.
    // here sometimes is an issue with single-page apps where shouldLoadRequest
    // is called for SPA page loads if there is a fragment (anchor). We will never get an sort of page finished callback, so the page
    // is always hidden.
    BOOL hide = hideWebview;
    if (hide && url.fragment) {
        NSURL *currentUrl = self.currentRequest.URL;
        if (currentUrl && [currentUrl matchesIgnoreAnchor:url]) {
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
    if (self.wkWebview) {
        oldView = self.wkWebview;
        [self.wkWebview.configuration.userContentController removeScriptMessageHandlerForName:GNFileWriterSharerName];
        [self.wkWebview.configuration.userContentController removeScriptMessageHandlerForName:GNJSBridgeName];
        
        // remove KVO
        @try {
            [oldView removeObserver:self forKeyPath:@"URL"];
            [oldView removeObserver:self forKeyPath:@"canGoBack"];
            [oldView removeObserver:self forKeyPath:@"canGoForward"];
        }
        @catch (NSException * __unused exception) {
        }
    }
    
    [self hideWebview];
    
    [self removePullRefresh];
    
    UIScrollView *scrollView;
    if ([newView isKindOfClass:[NSClassFromString(@"WKWebView") class]]) {
        self.wkWebview = (WKWebView*)newView;
        self.wkWebview.navigationDelegate = self;
        self.wkWebview.UIDelegate = self;
        scrollView = self.wkWebview.scrollView;
        
        // add KVO for single-page app url changes
        [newView addObserver:self forKeyPath:@"URL" options:0 context:nil];
        [newView addObserver:self forKeyPath:@"canGoBack" options:0 context:nil];
        [newView addObserver:self forKeyPath:@"canGoForward" options:0 context:nil];
        
        self.wkWebview.allowsBackForwardNavigationGestures = [GoNativeAppConfig sharedAppConfig].swipeGestures;
        [self.wkWebview.configuration.userContentController removeScriptMessageHandlerForName:GNFileWriterSharerName];
        [self.wkWebview.configuration.userContentController addScriptMessageHandler:self.fileWriterSharer name:GNFileWriterSharerName];
        self.fileWriterSharer.webView = newView;
        [self initializeJSInterfaceInWebView:self.wkWebview]; // initialize JS Interface
    } else {
        return;
    }
    
    // scroll before swapping to help reduce jank
    [scrollView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    
    if (oldView != newView) {
        if (oldView) {
            newView.frame = oldView.frame;
            [self.webviewContainer insertSubview:newView aboveSubview:oldView];
            [oldView removeFromSuperview];
        } else {
            newView.frame = self.webviewContainer.frame;
            [self.webviewContainer insertSubview:newView atIndex:0];
        }
        
        // add layout constriants to constainer view
        [self.webviewContainer addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.webviewContainer attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
        [self.webviewContainer addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.webviewContainer attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
        [self.webviewContainer addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.webviewContainer attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
        [self.webviewContainer addConstraint:[NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.webviewContainer attribute:NSLayoutAttributeRight multiplier:1 constant:0]];

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
    
    [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge switchToWebView:newView withRunner:self];
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
                [self.registrationManager checkUrl:url];
            }
        }
        if ([keyPath isEqualToString:@"canGoBack"]) {
            // we need a separate observe canGoBack because it seems to update after URL
            [self.toolbarManager didLoadUrl:url];
        }
        if ([keyPath isEqualToString:@"canGoForward"]) {
            // we need a separate observe canGoForward because it seems to update after URL
            [self.toolbarManager didLoadUrl:url];
        }
    }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    [self didStartLoad];
}

- (void)didStartLoad
{
    self.startedLoading = YES;
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

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self didFinishLoad];
    
    [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge webView:webView didFinishNavigation:navigation withRunner:self];
}

- (void)didFinishLoad
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showWebview];
        
        GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
        
        NSURL *url = nil;
        if (self.wkWebview) {
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

        [LEANUtilities overrideGeolocation:self.wkWebview];
        self.logManager = [[GNLogManager alloc] initWithWebview:self.wkWebview enabled:appConfig.enableWebConsoleLogs];
        
        // update navigation title
        if (appConfig.useWebpageTitle) {
            if (self.wkWebview) {
                self.nav.title = self.wkWebview.title;
            }
        }
        
        // update menu
        if (appConfig.loginDetectionURL) {
            [[LEANLoginManager sharedManager] checkLogin];
            
            self.visitedLoginOrSignup = [url matchesPathOf:appConfig.loginURL] ||
            [url matchesPathOf:[GoNativeAppConfig sharedAppConfig].signupURL];
        }
        
        // post-load javascript
        if (appConfig.postLoadJavascript) {
            [self runJavascript:appConfig.postLoadJavascript];
        }
        
        // profile picker
        if (self.profilePickerJs) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
        [self.actionManager didLoadUrl:url];
        
        // post-load js
        if (self.postLoadJavascript) {
            NSString *js = self.postLoadJavascript;
            self.postLoadJavascript = nil;
            [self runJavascript:js];
        }
        
        // post notification
        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserFinishedLoading object:self];
        
        // document sharing
        if (!appConfig.disableDocumentOpenWith &&
            [self.documentSharer isSharableRequest:self.currentRequest]) {
            if (!self.shareButton) {
                self.shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(sharePressed:)];
            }
        } else {
            self.shareButton = nil;
        }
        
        [self showNavigationItemButtonsAnimated:YES];
                
        // registration service
        [self.registrationManager checkUrl:url];
        
        BOOL doNativeBridge = YES;
        if (url) {
            doNativeBridge = [LEANUtilities checkNativeBridgeUrl:[url absoluteString]];
        }
        
        // send device info
        if (doNativeBridge) {
            [self runGonativeDeviceInfoWithCallback:@"gonative_device_info"];
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
            
            // do same for wkwebview
            WKHTTPCookieStore *wkCookieStore = self.wkWebview.configuration.websiteDataStore.httpCookieStore;
            [wkCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull arrCookies) {
                for (NSHTTPCookie *cookie in arrCookies) {
                    if(cookie.expiresDate == nil || cookie.sessionOnly){
                        NSMutableDictionary *cookieProperties = [cookie.properties mutableCopy];
                        cookieProperties[NSHTTPCookieExpires] = [[NSDate date] dateByAddingTimeInterval:forceSessionCookieExpiry];
                        cookieProperties[NSHTTPCookieMaximumAge] = [NSString stringWithFormat:@"%lu", (unsigned long)forceSessionCookieExpiry];
                        [cookieProperties removeObjectForKey:@"Created"];
                        [cookieProperties removeObjectForKey:NSHTTPCookieDiscard];
                        NSHTTPCookie *newCookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
                        [wkCookieStore setCookie:newCookie completionHandler:nil];
                    }
                }
            }];
        }
        
        // persist previous status of statusbar and body bg color matching
        BOOL enableMatching = [[NSUserDefaults standardUserDefaults] boolForKey:@"matchStatusBarToBodyBgColor"];
        if (enableMatching) {
            [LEANUtilities matchStatusBarToBodyBackgroundColor:self.wkWebview enabled:enableMatching];
        }
        
        // set initial css theme
        NSString *mode = [[NSUserDefaults standardUserDefaults] objectForKey:@"darkMode"];
        [self setCssTheme:mode andPersistData:NO];
        
        [self runJavascript:[LEANUtilities createJsForCallback:@"gonative_library_ready" data:nil]];
    });
}

-(void)runGonativeDeviceInfoWithCallback:(NSString*)callback {
    if(!callback) callback = @"gonative_device_info";
    
    LEANAppDelegate *appDelegate = (LEANAppDelegate*)[UIApplication sharedApplication].delegate;
    appDelegate.isFirstLaunch = NO;
    
    NSMutableDictionary *additionalData = [NSMutableDictionary dictionary];
    if(appDelegate.apnsToken)
        additionalData[@"apnsToken"] = appDelegate.apnsToken;
    
    [self runGonativeInfoWithCallback:callback additionalData:additionalData];
}

-(void)runGonativeInfoWithCallback:(NSString*)callback additionalData:(NSDictionary *)additionalData {
    NSMutableDictionary *toSend = [NSMutableDictionary dictionary];
    NSDictionary *installation = [LEANInstallation info];
    [toSend addEntriesFromDictionary:installation];
    if (additionalData)
        [toSend addEntriesFromDictionary:additionalData];
    
    NSString *jsCallback = [LEANUtilities createJsForCallback:callback data:toSend];
    if (jsCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self runJavascript:jsCallback];
        });
    }
}

- (WKWebView*)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    // createWebView is called before shouldLoadRequest is called. To avoid creating an extra
    // WebViewController for an external link, we check shouldLoadRequest here.
    if (navigationAction.request) {
        BOOL shouldLoad = [self shouldLoadRequest:navigationAction.request isMainFrame:YES isUserAction:YES hideWebview:NO sender:nil];
        if (!shouldLoad) {
            return nil;
        }
    }
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    
    if (!appConfig.enableWindowOpen) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadRequest:navigationAction.request];
        });
        return nil;
    }
    
    if (appConfig.maxWindowsAutoClose && _currentWindows == appConfig.maxWindows && [appConfig.initialURL matchesIgnoreAnchor:navigationAction.request.URL]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LEANWebViewController *vc = self.navigationController.viewControllers.firstObject;
            [self loadRequest:navigationAction.request];
            [vc switchToWebView:self.wkWebview showImmediately:YES];
            [self.navigationController popToRootViewControllerAnimated:NO];
            
        });
        return nil;
    }
    
    WKWebView *newWebview = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:self.wkWebview.frame configuration:configuration];
    [LEANUtilities configureWebView:newWebview];
    
    LEANWebViewController *newvc = [self.storyboard instantiateViewControllerWithIdentifier:@"webviewController"];
    newvc.initialWebview = newWebview;
    newvc.isWindowOpen = YES;
    
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
        NSString *initialUrlPref = [self.configPreferences getInitialUrl];
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
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"button-ok", @"Button: OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *input = ((UITextField *)alertController.textFields.firstObject).text;
            completionHandler(input);
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"button-cancel", @"Button: Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            completionHandler(nil);
        }]];
        [[self getTopPresentedViewController] presentViewController:alertController animated:YES completion:^{}];
    }

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"button-ok", @"Button: OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"button-ok", @"Button: OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"button-cancel", @"Button: Cancel") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
    
    if (self.wkWebview) {
        [self.wkWebview evaluateJavaScript:@"document.readyState" completionHandler:readyStateBlock];
    }
}

- (void)hideWebview
{
    [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge hideWebViewWithRunner:self];
    
    if ([GoNativeAppConfig sharedAppConfig].disableAnimations) return;
    
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
    self.wkWebview.userInteractionEnabled = YES;
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^(void){
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

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self didFailLoadWithError:error isProvisional:NO];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self didFailLoadWithError:error isProvisional:YES];
}

- (void)didFailLoadWithError:(NSError*)error isProvisional:(BOOL)isProvisional
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    // show webview unless navigation was canceled, which is most likely due to a different page being requested
    if (![error.domain isEqualToString:NSURLErrorDomain] || error.code != NSURLErrorCancelled) {
        [self showWebview];
    }
    
    if ([[error domain] isEqualToString:NSURLErrorDomain]) {
        if (![GoNativeAppConfig sharedAppConfig].iosShowOfflinePage)
            return;
        
        if ([error code] == NSURLErrorCannotFindHost || [error code] == NSURLErrorNotConnectedToInternet ||
            (isProvisional && [error code] == NSURLErrorTimedOut)) {
            [self showOfflinePage];
        }
    }
}

- (void) showOfflinePage
{
    NSURL *offlineFile = [[NSBundle mainBundle] URLForResource:@"offline" withExtension:@"html"];
    NSString *html = [NSString stringWithContentsOfURL:offlineFile encoding:NSUTF8StringEncoding error:nil];
    [self.wkWebview loadHTMLString:html baseURL:[NSURL URLWithString:OFFLINE_URL]];
}

- (void) showSidebarNavButton {
    UIButton *favButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [favButton setImage:[UIImage imageNamed:@"navImage"] forState:UIControlStateNormal];
    [favButton addTarget:self action:@selector(showMenu)
        forControlEvents:UIControlEventTouchUpInside];
    [favButton setFrame:CGRectMake(0, 0, 36, 30)];
    self.navButton = [[UIBarButtonItem alloc] initWithCustomView:favButton];
    self.navButton.accessibilityLabel = NSLocalizedString(@"button-menu", @"Button: Menu");
}

- (void) setNavigationButtonStatus
{
    self.backButton.enabled = self.wkWebview.canGoBack;
    self.forwardButton.enabled = self.wkWebview.canGoForward;
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

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    // usually called because of rotation
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [self adjustInsets];
    [self applyStatusBarOverlay];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // bar thickness changes when rotating, so resize internal contents
        [self.tabBar invalidateIntrinsicContentSize];
        [self.toolbar invalidateIntrinsicContentSize];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
    }];
    
    [((LEANAppDelegate *)[UIApplication sharedApplication].delegate).bridge runner:self willTransitionToSize:size withTransitionCoordinator:coordinator];
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
        
        if (self.blurEffectView) {
            self.blurEffectView.frame = CGRectMake(0, 0, width, height);
        }
    }
    [self adjustInsets];
}

-(void)orientationChanged
{
    // fixes status bar weirdness when rotating video to landscape
    [self setNeedsStatusBarAppearanceUpdate];
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // Heights of tab and tool bars will change after rotation, as bars are thinner on landscape.
    // If the bar is hidden, then the bottom constraint is based on the thickness of the bar.
    // The constraint will need to be updated to keep everything in the right place.
    if (self.tabBar.hidden) {
        [self hideBottomBar:self.tabBar constraint:self.tabBarBottomConstraint animated:NO];
    }
    if (self.toolbar.hidden) {
        [self hideBottomBar:self.toolbar constraint:self.toolbarBottomConstraint animated:NO];
    }
    
    // fixes issue on iPhone XS Max and iPhone XR where instrinsic content height = 49
    [self.tabBar invalidateIntrinsicContentSize];
    [self.toolbar invalidateIntrinsicContentSize];
    
    
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    
    // theme and colors
    if ([appConfig.iosTheme isEqualToString:@"dark"]) {
        self.view.backgroundColor = [UIColor blackColor];
        self.webviewContainer.backgroundColor = [UIColor blackColor];
        self.tabBar.barStyle = UIBarStyleBlack;
        self.toolbar.barStyle = UIBarStyleBlack;
    } else {
        self.tabBar.barStyle = UIBarStyleDefault;
        self.toolbar.barStyle = UIBarStyleDefault;
        
        if (@available(iOS 12.0, *)) {
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                self.view.backgroundColor = [UIColor blackColor];
                self.webviewContainer.backgroundColor = [UIColor blackColor];
            } else {
                self.view.backgroundColor = [UIColor whiteColor];
                self.webviewContainer.backgroundColor = [UIColor whiteColor];
            }
        } else {
            self.view.backgroundColor = [UIColor whiteColor];
            self.webviewContainer.backgroundColor = [UIColor whiteColor];
        }
    }
    
    [self applyStatusBarOverlay];
    if (appConfig.iosEnableOverlayInStatusBar) {
        [self updateStatusBarOverlay:appConfig.iosEnableOverlayInStatusBar];
    }
    
    self.tabBar.barTintColor = [UIColor colorNamed:@"tabBarTintColor"];
}

# pragma theme
-(void)setNativeTheme:(NSString *)mode {
    if (@available(iOS 13.0, *)) {
        if (mode == nil) {
            return;
        }
        
        if ([[GoNativeAppConfig sharedAppConfig].iosTheme isEqualToString:@"dark"]) {
            mode = @"dark";
        }
        
        if ([mode isEqualToString:@"dark"]) {
            [UIApplication sharedApplication].delegate.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            self.statusBarStyle = [NSNumber numberWithInteger:UIStatusBarStyleDarkContent];
        }
        else if ([mode isEqualToString:@"light"]) {
            [UIApplication sharedApplication].delegate.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
            self.statusBarStyle = [NSNumber numberWithInteger:UIStatusBarStyleLightContent];
        } else {
            [UIApplication sharedApplication].delegate.window.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
            self.statusBarStyle = [NSNumber numberWithInteger:UIStatusBarStyleDefault];
        }
        
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

-(void)setCssTheme:(NSString *)mode andPersistData:(BOOL)persist {
    if (mode == nil) {
        return;
    }
    
    if ([[GoNativeAppConfig sharedAppConfig].iosTheme isEqualToString:@"dark"]) {
        mode = @"dark";
    }

    [self setCssThemeAttribute:@"data-mode" withValue:mode];
    [self setCssThemeAttribute:@"data-theme" withValue:mode];
    
    if (persist) {
        [[NSUserDefaults standardUserDefaults] setValue:mode forKey:@"darkMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

-(void)setCssThemeAttribute:(NSString *)attr withValue:(NSString *)value {
    NSString *js = [NSString stringWithFormat:@"document.documentElement.setAttribute(\"%@\", \"%@\");", attr, value];
    [self.wkWebview evaluateJavaScript:js completionHandler:nil];
}

- (void)updateStatusBarBackgroundColor:(UIColor *)backgroundColor enableBlurEffect:(BOOL)isBlurEnabled{
    if (!backgroundColor) return;

    UIView *background = [[UIView alloc] init];
    background.backgroundColor = backgroundColor;
    [self.statusBarBackground removeFromSuperview];
    self.statusBarBackground = background;
    [self.view addSubview:self.statusBarBackground];
    
    if (isBlurEnabled) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        [self.blurEffectView removeFromSuperview];
        self.blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        [self.view addSubview:self.blurEffectView];
    }
}

- (void)updateStatusBarOverlay:(BOOL)isOverlayEnabled{
    self.statusBarOverlay = isOverlayEnabled;
    [self applyStatusBarOverlay];
}

- (void)updateStatusBarStyle:(NSString *)statusBarStyle{
    if ([statusBarStyle isEqualToString:@"dark"]) {
        // dark icons and text
        if (@available(iOS 13.0, *)) {
            self.statusBarStyle = [NSNumber numberWithInteger:UIStatusBarStyleDarkContent];
        } else {
            self.statusBarStyle = [NSNumber numberWithInteger:UIStatusBarStyleDefault];
        }
    } else if ([statusBarStyle isEqualToString:@"light"]) {
        // light icons and text
        self.statusBarStyle = [NSNumber numberWithInteger:UIStatusBarStyleLightContent];
    } else {
        self.statusBarStyle = [NSNumber numberWithInteger:UIStatusBarStyleDefault];
    }
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)themeManagerHandleUrl:(NSURL *)url query:(NSDictionary *)query {
    if ([url.path isEqualToString:@"/set"]) {
        NSString *style = query[@"style"];
        if (style) {
            [self updateStatusBarStyle:style];
        }
        
        NSString *color = query[@"color"];
        BOOL isBlurEnabled = [query[@"blur"] boolValue];
        if (color) {
            [self updateStatusBarBackgroundColor:[LEANUtilities colorWithAlphaFromHexString:color] enableBlurEffect:isBlurEnabled];
        }
        
        BOOL overlay = [query[@"overlay"] boolValue];
        [self updateStatusBarOverlay:overlay];
    }
    else if ([url.path isEqualToString:@"/matchBodyBackgroundColor"]) {
        BOOL enableMatching = [[query objectForKey:@"active"] boolValue];
        [LEANUtilities matchStatusBarToBodyBackgroundColor:self.wkWebview enabled:enableMatching];
        
        // persist statusbar and body bg color matching status
        [[NSUserDefaults standardUserDefaults] setBool:enableMatching forKey:@"matchStatusBarToBodyBgColor"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end
