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
#import "LEANInstallation.h"
#import "LEANTabManager.h"
#import "LEANWebViewPool.h"
#import "LEANDocumentSharer.h"

@interface LEANWebViewController () <UISearchBarDelegate, UIActionSheetDelegate, UIScrollViewDelegate, UITabBarDelegate>

@property IBOutlet UIBarButtonItem* backButton;
@property IBOutlet UIBarButtonItem* forwardButton;
@property IBOutlet UINavigationItem* nav;
@property IBOutlet UIBarButtonItem* navButton;
@property IBOutlet UIActivityIndicatorView *activityIndicator;
@property NSArray *defaultLeftNavBarItems;
@property NSArray *defaultToolbarItems;
@property UIBarButtonItem *customActionButton;
@property NSArray *customActions;
@property UIBarButtonItem *searchButton;
@property UISearchBar *searchBar;
@property UIView *statusBarBackground;
@property UITabBar *tabBar;
@property UIBarButtonItem *shareButton;

@property BOOL willBeLandscape;

@property NSURLRequest *currentRequest;
@property NSInteger urlLevel; // -1 for unknown
@property NSString *profilePickerJs;
@property NSString *analyticsJs;
@property NSTimer *timer;
@property BOOL startedLoading; // for transitions
@property LEANTabManager *tabManager;
@property BOOL isPoolWebview;
@property UIView *defaultTitleView;

@property NSString *postLoadJavascript;

@property BOOL visitedLoginOrSignup;

@end

@implementation LEANWebViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.checkLoginSignup = YES;
    
    LEANAppConfig *appConfig = [LEANAppConfig sharedAppConfig];
    
    // push login controller if it should be the first thing shown
    if (appConfig.loginIsFirstPage && [self isRootWebView]) {
        LEANWebFormController *wfc = [[LEANWebFormController alloc] initWithDictionary:appConfig.loginConfig title:appConfig.appName isLogin:YES];
        wfc.originatingViewController = self;
        [self.navigationController pushViewController:wfc animated:NO];
    }
    
    // set title to application title
    if ([appConfig.navTitles count] == 0) {
        self.navigationItem.title = appConfig.appName;
    }
    
    // show logo in navigation bar
    if (appConfig.navigationTitleImage) {
        UIImage *im = nil;
        if (appConfig.navigationTitleIcon) {
            im = appConfig.navigationTitleIcon;
        } else {
            im = [UIImage imageNamed:@"navbar_logo"];
        }
        if (im) {
            CGRect bounds = CGRectMake(0, 0, 30 * im.size.width / im.size.height, 30);
            UIView *backView = [[UIView alloc] initWithFrame:bounds];
            UIImageView *iv = [[UIImageView alloc] initWithImage:im];
            iv.bounds = bounds;
            [backView addSubview:iv];
            iv.center = backView.center;
            self.defaultTitleView = backView;
            self.navigationItem.titleView = backView;
        }
    }
    
    // dark theme
    if ([appConfig.iosTheme isEqualToString:@"dark"]) {
        self.view.backgroundColor = [UIColor blackColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }
    
    // configure zoomability
    self.webview.scalesPageToFit = appConfig.allowZoom;
    
    // hide button if no native nav
    if (!appConfig.showNavigationMenu) {
        self.navButton.customView = [[UIView alloc] init];
    }
    
    // add nav button
    if (appConfig.showNavigationMenu &&  [self isRootWebView]) {
        self.navButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"navImage"] style:UIBarButtonItemStyleBordered target:self action:@selector(showMenu)];
        // hack to space it a bit closer to the left edge
        UIBarButtonItem *negativeSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        [negativeSpacer setWidth:-10];
        
        self.navigationItem.leftBarButtonItems = @[negativeSpacer, self.navButton];
    }
    self.defaultLeftNavBarItems = self.navigationItem.leftBarButtonItems;
    
    // profile picker
    if (appConfig.profilePickerJS && [appConfig.profilePickerJS length] > 0) {
        self.profilePickerJs = appConfig.profilePickerJS;
        self.profilePicker = [[LEANProfilePicker alloc] init];
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
    
	// set self as webview delegate to handle start/end load events
    self.webview.delegate = self;
    
    // load initial url
    self.urlLevel = -1;
    if (!self.initialUrl) {
        self.initialUrl = appConfig.initialURL;
    }
    [self loadUrl:self.initialUrl];
    
    
    self.webview.scrollView.bounces = NO;
    
    // hidden nav bar
    if (!appConfig.showNavigationBar && [self isRootWebView]) {
        self.statusBarBackground = [[UINavigationBar alloc] init];
        [self.view addSubview:self.statusBarBackground];
    }
    
    if (appConfig.searchTemplateURL) {
        self.searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchPressed:)];
        self.searchBar = [[UISearchBar alloc] init];
        self.searchBar.showsCancelButton = NO;
        self.searchBar.delegate = self;
    }
    
    [self showNavigationItemButtonsAnimated:NO];
    [self buildDefaultToobar];
    [self adjustInsets];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNotification:) name:kLEANAppConfigNotificationProcessedTabNavigation object:nil];
}

- (void)didReceiveNotification:(NSNotification*)notification
{
    if ([[notification name] isEqualToString:kLEANAppConfigNotificationProcessedTabNavigation]) {
        [self checkTabsForUrl:[self.webview.request URL]];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self isRootWebView]) {
        [self.navigationController setNavigationBarHidden:![LEANAppConfig sharedAppConfig].showNavigationBar animated:YES];
    } else {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    
    [self adjustInsets];
}

- (void)viewWillDisappear:(BOOL)animated
{
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

- (void)checkTabsForUrl:(NSURL*) url;
{
    if (![LEANAppConfig sharedAppConfig].tabMenus) {
        [self hideTabBar];
        return;
    }
    
    if (!self.tabBar) {
        self.tabBar = [[UITabBar alloc] init];
        
        if ([[LEANAppConfig sharedAppConfig].iosTheme isEqualToString:@"dark"]) {
            self.tabBar.barStyle = UIBarStyleBlack;
        } else {
            self.tabBar.barStyle = UIBarStyleDefault;
        }
        
        self.tabBar.delegate = self;
        self.tabBar.hidden = YES;
        self.tabBar.alpha = 0.0;
    }
    
    if (![self.tabBar isDescendantOfView:self.view]) {
        [self.view addSubview:self.tabBar];

    }
    
    if (!self.tabManager) {
        self.tabManager = [[LEANTabManager alloc] initWithTabBar:self.tabBar webviewController:self];
    }
    
    [self.tabManager didLoadUrl:url];
}

- (void)hideTabBar
{
    if (!self.tabBar) {
        return;
    }
    
    if (!self.tabBar.hidden) {
        [UIView animateWithDuration:0.3 animations:^(void){
            self.tabBar.alpha = 0.0;
        }completion:^(BOOL finished){
            self.tabBar.hidden = YES;
            self.tabBar.frame = CGRectZero;
            [self adjustInsets];
        }];
    }
}

- (void)showTabBar
{
    [self.navigationController setToolbarHidden:YES animated:NO];
    
    if (self.tabBar.hidden) {
        self.tabBar.alpha = 0;
        self.tabBar.hidden = NO;
        self.tabBar.frame = CGRectMake(0, self.view.bounds.size.height - 49, self.view.bounds.size.width, 49);
        [UIView animateWithDuration:0.3 animations:^(void){
            self.tabBar.alpha = 1.0;
        } completion:^(BOOL finished){
            [self adjustInsets];
        }];
    }
}

- (void)adjustInsets
{
    CGFloat top = 0;
    if (!self.navigationController.navigationBarHidden && self.navigationController.navigationBar) {
        top = MIN(self.navigationController.navigationBar.bounds.size.height,
                  self.navigationController.navigationBar.bounds.size.width);
    }
    top += MIN([UIApplication sharedApplication].statusBarFrame.size.height,
               [UIApplication sharedApplication].statusBarFrame.size.width);
    
    CGFloat bottom = 0;
    if (self.tabBar && !self.tabBar.hidden) {
        bottom = MIN(self.tabBar.bounds.size.height, self.tabBar.bounds.size.width);
    }
    
    // the following line should not be necessary, but adding it helps prevent a black bar from flashing at the bottom of the screen for a fraction of a second.
    self.webview.scrollView.contentInset = UIEdgeInsetsMake(top, 0, -top + bottom, 0);
    self.webview.scrollView.contentInset = UIEdgeInsetsMake(top, 0, bottom, 0);
    self.webview.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(top, 0, bottom, 0);
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
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(searchCanceled)];
    
    [self.navigationItem setLeftBarButtonItems:nil animated:YES];
    [self.navigationItem setRightBarButtonItems:@[cancelButton] animated:YES];
    [self.searchBar becomeFirstResponder];
}

- (void) sharePressed:(UIBarButtonItem*)sender
{
    [[LEANDocumentSharer sharedSharer] shareRequest:self.webview.request fromButton:sender];
}

- (void) showNavigationItemButtonsAnimated:(BOOL)animated
{
    //left
    [self.navigationItem setLeftBarButtonItems:self.defaultLeftNavBarItems animated:animated];
    
    NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:3];
    
    // right: search button
    if (self.searchButton) {
        [buttons addObject:self.searchButton];
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
    
    // load initial page in bottom webview
    [self.navigationController popToRootViewControllerAnimated:NO];
    [self.navigationController.viewControllers[0] loadUrl:[LEANAppConfig sharedAppConfig].initialURL];
    
    [(LEANMenuViewController*)self.frostedViewController.menuViewController updateMenuWithStatus:@"default"];
}

- (IBAction) showMenu
{
    [self.frostedViewController presentMenuViewController];
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
    [self.webview loadRequest:[NSURLRequest requestWithURL:url]];
}


- (void) loadRequest:(NSURLRequest*) request
{
    [self.webview loadRequest:request];
}

- (void) loadUrl:(NSURL *)url andJavascript:(NSString *)js
{
    if ([[[self.webview.request URL] absoluteString] isEqualToString:[url absoluteString]]) {
        [self hideWebview];
        [self.webview stringByEvaluatingJavaScriptFromString:js];
        [self showWebview];
    } else {
        self.postLoadJavascript = js;
        [self loadUrl:url];
    }
}

- (void) loadRequest:(NSURLRequest *)request andJavascript:(NSString*)js
{
    self.postLoadJavascript = js;
    [self.webview loadRequest:request];
}

- (void) runJavascript:(NSString *) script
{
    [self.webview stringByEvaluatingJavaScriptFromString:script];
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
    NSArray *entries = [LEANAppConfig sharedAppConfig].navStructureLevels;
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
    NSArray *entries = [LEANAppConfig sharedAppConfig].navTitles;
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
    NSString *searchTemplate = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)[LEANAppConfig sharedAppConfig].searchTemplateURL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",NULL,kCFStringEncodingUTF8 ));
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
    LEANAppConfig *appConfig = [LEANAppConfig sharedAppConfig];
    NSURL *url = [request URL];
    NSString *urlString = [url absoluteString];
    NSString* hostname = [url host];
    
//    NSLog(@"should start load %d %@", navigationType, url);
    
    // simulator
    if ([url.scheme isEqualToString:@"gonative.io"]) {
        return YES;
    }
    
    // always allow iframes to load
    if (![urlString isEqualToString:[[request mainDocumentURL] absoluteString]]) {
        return YES;
    }
    
    [[LEANUrlInspector sharedInspector] inspectUrl:url];
    
    // check redirects
    if (appConfig.redirects != nil) {
        NSString *to = [appConfig.redirects valueForKey:urlString];
        if (to) {
            url = [NSURL URLWithString:to];
            
//            [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:to]]];
//            return false;
        }
    }
    
    // log out by clearing cookies
    if (urlString && [urlString caseInsensitiveCompare:@"file://gonative_logout"] == NSOrderedSame) {
        [self logout];
        return NO;
    }
    
    // checkLoginSignup might be NO when returning from login screen with loginIsFirstPage
    BOOL checkLoginSignup = self.checkLoginSignup;
    self.checkLoginSignup = YES;
    
    // log in
    if (checkLoginSignup && appConfig.loginConfig &&
        [url matchesPathOf:appConfig.loginURL]) {
        [self showWebview];
        
        if (appConfig.loginIsFirstPage) {
            if (self.webview.request) {
                // this is not the first page loaded, so was probably called via Logout.
                
                // recheck status as it has probably changed
                [[LEANLoginManager sharedManager] checkLogin];
                
                LEANWebFormController *wfc = [[LEANWebFormController alloc] initWithDictionary:appConfig.loginConfig title:appConfig.appName isLogin:YES];

                wfc.originatingViewController = self;
                [self.navigationController pushViewController:wfc animated:YES];
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
            [self presentViewController:formSheet animated:YES completion:nil];
        } else {
            [self.navigationController pushViewController:wfc animated:YES];
        }
        return NO;
    }
    
    // sign up
    if (checkLoginSignup && appConfig.signupURL &&
        [url matchesPathOf:appConfig.signupURL]) {
        [self showWebview];

        LEANWebFormController *wfc = [[LEANWebFormController alloc] initWithDictionary:appConfig.signupConfig title:@"Sign Up" isLogin:NO];
        wfc.originatingViewController = self;
        
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
                    [self presentViewController:formSheet animated:YES completion:nil];
                }
                else {
                    [self.navigationController pushViewController:wfc animated:YES];
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
        
        if ([[UIApplication sharedApplication] canOpenURL:url])
            [[UIApplication sharedApplication] openURL:url];
        else
            [[UIApplication sharedApplication] openURL:[request URL]];
        
        
        return NO;
    }
    
    // external sites: don't launch if in iframe.
    if ([[[request URL] absoluteString] isEqualToString:[[request mainDocumentURL] absoluteString]]
        && ![[request URL] matchesPathOf:[[webView request] URL]]) {
        // first check regexInternalExternal
        bool matchedRegex = NO;
        for (NSUInteger i = 0; i < [appConfig.regexInternalEternal count]; i++) {
            NSPredicate *predicate = appConfig.regexInternalEternal[i];
            if ([predicate evaluateWithObject:urlString]) {
                matchedRegex = YES;
                if (![appConfig.regexIsInternal[i] boolValue]) {
                    // external
                    [[UIApplication sharedApplication] openURL:[request URL]];
                    return NO;
                }
                break;
            }
        }
        
        if (!matchedRegex) {
            if (![hostname isEqualToString:appConfig.initialHost] &&
                ![hostname hasSuffix:[@"." stringByAppendingString:appConfig.initialHost]]) {
                // open in external web browser
                [[UIApplication sharedApplication] openURL:[request URL]];
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
            
            NSMutableArray *controllers = [self.navigationController.viewControllers mutableCopy];
            while (![[controllers lastObject] isKindOfClass:[LEANWebViewController class]]) {
                [controllers removeLastObject];
            }
            [controllers addObject:newvc];
            [self.navigationController setViewControllers:controllers animated:YES];
            
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
                    [wvc loadRequest:request andJavascript:self.postLoadJavascript];
                    self.postLoadJavascript = nil;
                } else {
                    [wvc loadRequest:request];
                }
                [self.navigationController popToViewController:wvc animated:YES];
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
        [self.navigationController setViewControllers:controllers animated:YES];
    }
    
    if (newLevel >= 0) {
        self.urlLevel = [LEANWebViewController urlLevelForUrl:url];
    }
    
    NSString *newTitle = [LEANWebViewController titleForUrl:url];
    if (newTitle) {
        self.navigationItem.title = newTitle;
    }
    
    // save for reload
    self.currentRequest = request;
    // save for html interception
    ((LEANAppDelegate*)[[UIApplication sharedApplication] delegate]).currentRequest = request;
    
    
    // check to see if the webview exists in pool. Swap it in if it's not the same url.
    UIWebView *poolWebview = nil;
    LEANWebViewPoolDisownPolicy poolDisownPolicy;
    poolWebview = [[LEANWebViewPool sharedPool] webviewForUrl:url policy:&poolDisownPolicy];
    
    if (poolWebview && poolDisownPolicy == LEANWebViewPoolDisownPolicyAlways) {
        self.isPoolWebview = NO;
        [self switchToWebView:poolWebview];
        [self checkTabsForUrl:url];
        [[LEANWebViewPool sharedPool] disownWebview:poolWebview];
        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserFinishedLoading object:self];
        return NO;
    }
    
    if (poolWebview && poolDisownPolicy == LEANWebViewPoolDisownPolicyNever) {
        self.isPoolWebview = YES;
        [self switchToWebView:poolWebview];
        [self checkTabsForUrl:url];
        return NO;
    }
    
    if (poolWebview && poolDisownPolicy == LEANWebViewPoolDisownPolicyReload &&
        ![[request URL] matchesPathOf:[[webView request] URL]]) {
        self.isPoolWebview = YES;
        [self switchToWebView:poolWebview];
        [self checkTabsForUrl:url];
        return NO;
    }
    
    if (self.isPoolWebview) {
        // if we are here, either the policy is reload and we are reloading the page, or policy is never but we are going to a different page. So take ownership of the webview.
        [[LEANWebViewPool sharedPool] disownWebview:self.webview];
        self.isPoolWebview = NO;
    }
    
    [self hideWebview];
    
    [self setNavigationButtonStatus];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserStartedLoading object:self];
    
    return YES;
}

- (void)switchToWebView:(UIWebView*)newView
{
    UIWebView *oldView = self.webview;
    self.webview = newView;

    oldView.delegate = nil;
    newView.delegate = self;
    [newView.scrollView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    
    [self hideWebview];
    if (oldView != newView) {
        [self.view insertSubview:newView aboveSubview:oldView];
        [oldView removeFromSuperview];
    }
    [self adjustInsets];
   
    // add layout constraints
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webview attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webview attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webview attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webview attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    if (self.postLoadJavascript) {
        [self.webview stringByEvaluatingJavaScriptFromString:self.postLoadJavascript];
        self.postLoadJavascript = nil;
    }
    
    // fix for black boxes
    for (UIView *view in newView.scrollView.subviews) {
        [view setNeedsDisplayInRect:newView.bounds];
    }
    
    [self showWebview];
}

- (void) webViewDidStartLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self.customActionButton setEnabled:NO];
    
    [self.timer invalidate];
    self.timer = [NSTimer timerWithTimeInterval:0.05 target:self selector:@selector(checkReadyStatus) userInfo:nil repeats:YES];
    [self.timer setTolerance:0.02];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
    
    // remove share button
    if (self.shareButton) {
        self.shareButton = nil;
        [self showNavigationItemButtonsAnimated:YES];
    }
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
    if ([LEANAppConfig sharedAppConfig].useWebpageTitle) {
        NSString *theTitle=[self.webview stringByEvaluatingJavaScriptFromString:@"document.title"];
        self.nav.title = theTitle;
    }
    
    // update menu
    if ([LEANAppConfig sharedAppConfig].loginDetectionURL && !webView.isLoading) {
        [[LEANLoginManager sharedManager] checkLogin];
        
        self.visitedLoginOrSignup = [url matchesPathOf:[LEANAppConfig sharedAppConfig].loginURL] ||
        [url matchesPathOf:[LEANAppConfig sharedAppConfig].signupURL];
    }
    
    // dynamic config updater
    if ([LEANAppConfig sharedAppConfig].updateConfigJS && !webView.isLoading) {
        NSString *result = [webView stringByEvaluatingJavaScriptFromString:[LEANAppConfig sharedAppConfig].updateConfigJS];
        [[LEANAppConfig sharedAppConfig] processDynamicUpdate:result];
    }
    
    // profile picker
    if (self.profilePickerJs) {
        NSString *json = [webView stringByEvaluatingJavaScriptFromString:self.profilePickerJs];
        [self.profilePicker parseJson:json];
        [(LEANMenuViewController*)self.frostedViewController.menuViewController showSettings:[self.profilePicker hasProfiles]];
    }
    
    // analytics
    if (self.analyticsJs && !webView.isLoading) {
        [webView stringByEvaluatingJavaScriptFromString:self.analyticsJs];
    }
    
    if ([LEANAppConfig sharedAppConfig].enableChromecast) {
        [self detectVideo];
        // [self performSelector:@selector(detectVideo) withObject:nil afterDelay:1];
    }
    
    [self updateCustomActions];
    
    // tabs
    [self checkTabsForUrl: url];
    
    // post-load js
    if (self.postLoadJavascript && !webView.isLoading) {
        NSString *js = self.postLoadJavascript;
        self.postLoadJavascript = nil;
        [self runJavascript:js];
    }
    
    // post notification
    if (!webView.isLoading) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANWebViewControllerUserFinishedLoading object:self];
    }
    
    // document sharing
    if (!webView.isLoading) {
        if ([[LEANDocumentSharer sharedSharer] isSharableRequest:webView.request]) {
            if (!self.shareButton) {
                self.shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(sharePressed:)];
                [self showNavigationItemButtonsAnimated:YES];
            }
        }
    }
}


- (void)checkReadyStatus
{
    // if interactiveDelay is specified, then look for readyState=interactive, and show webview
    // with a delay. If not specified, wait for readyState=complete.
    NSNumber *interactiveDelay = [LEANAppConfig sharedAppConfig].interactiveDelay;
    
    NSString *status = [self.webview stringByEvaluatingJavaScriptFromString:@"document.readyState"];
    // we keep track of startedLoading because loading is only really finished when we have gone to
    // "loading" or "interactive" before going to complete. When the web page first starts loading,
    // it will be in "complete", then "loading", "interactive", and finally "complete".
    if ([status isEqualToString:@"loading"] || (!interactiveDelay && [status isEqualToString:@"interactive"])){
        self.startedLoading = YES;
    }
    else if ((interactiveDelay && [status isEqualToString:@"interactive"])
             || (self.startedLoading && [status isEqualToString:@"complete"])) {
        
        if ([status isEqualToString:@"interactive"]){
            // note: doubleValue will be 0 if interactiveDelay is null
            [self showWebviewWithDelay:[interactiveDelay doubleValue]];
        }
        else {
            [self showWebview];
        }
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

- (void)showWebviewWithDelay:(NSTimeInterval)delay
{
    [self performSelector:@selector(showWebview) withObject:nil afterDelay:delay];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

    [self showWebview];
    
    if ([[error domain] isEqualToString:NSURLErrorDomain] && [error code] == NSURLErrorNotConnectedToInternet) {
        [[[UIAlertView alloc] initWithTitle:@"No connection" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
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
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        return NO;
    } else {
        return self.willBeLandscape;
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
        CGFloat height = MIN(statusSize.height, statusSize.width);
        CGFloat width = MAX(statusSize.height, statusSize.width);
        self.statusBarBackground.frame = CGRectMake(0, 0, width, height);
    }
}


@end
