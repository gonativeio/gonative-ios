//
//  GNRegistrationService.m
//  GoNativeIOS
//
//  Created by Weiyin He on 10/3/15.
//  Copyright © 2015 GoNative.io LLC. All rights reserved.
//

#import "GNRegistrationManager.h"
#import "LEANUtilities.h"
#import "LEANInstallation.h"

#pragma mark Registration Data

@interface GNRegistrationInfo : NSObject
@property NSString *oneSignalUserId;
@property NSString *oneSignalPushToken;
@property BOOL oneSignalSubscribed;
@property BOOL oneSignalRequiresPrivacyConsent;
@property NSDictionary *customData;
@end
@implementation GNRegistrationInfo
@end

#pragma mark Registration endpoint (individual)

@interface GNRegistrationEndpoint : NSObject
@property NSURL *postUrl;
@property NSString *postUrlString;
@property NSArray *urlRegexes;
// WKWebView cookies are not shared with native url request functions, so if we are using
// WK, use a hidden webview to do POSTs.
@property WKWebView *wkWebView;
@end

@implementation GNRegistrationEndpoint
-(instancetype)initWithUrl:(NSURL*)postUrl urlRegexes:(NSArray*)urlRegexes
{
    self = [super init];
    if (self) {
        self.postUrl = postUrl;
        self.postUrlString = [self.postUrl absoluteString];
        self.urlRegexes = urlRegexes;
        
        if ([GoNativeAppConfig sharedAppConfig].useWKWebView) {
            WKWebViewConfiguration *config = [[NSClassFromString(@"WKWebViewConfiguration") alloc] init];
            config.processPool = [LEANUtilities wkProcessPool];
            self.wkWebView = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:CGRectZero configuration:config];
            
            // load url to get around same-origin policy
            [self.wkWebView loadHTMLString:@"" baseURL:self.postUrl];
        }
    }
    return self;
}

-(void)sendRegistrationInfo:(GNRegistrationInfo*)info {
    // [LEANInstallation info] requires main thread
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendRegistrationInfo:info];
        });
        return;
    }

    NSMutableDictionary *toSend = [NSMutableDictionary dictionary];
    
    [toSend addEntriesFromDictionary:[LEANInstallation info]];
    
    if (info.oneSignalUserId) {
        toSend[@"oneSignalUserId"] = info.oneSignalUserId;
        if (info.oneSignalPushToken) {
            toSend[@"oneSignalPushToken"] = info.oneSignalPushToken;
        }
        toSend[@"oneSignalSubscribed"] = [NSNumber numberWithBool:info.oneSignalSubscribed];
        toSend[@"oneSignalRequiresUserPrivacyConsent"] = [NSNumber numberWithBool:info.oneSignalRequiresPrivacyConsent];
    }
    
    if (info.customData) {
        for (NSString *key in info.customData) {
            toSend[[NSString stringWithFormat:@"customData_%@", key]] = info.customData[key];
        }
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:toSend options:0 error:nil];
//    NSLog(@"sending registration json: %@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.postUrl];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    // if using WkWebView, send POST via WkWebView.
    if (self.wkWebView) {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSString *js = [NSString stringWithFormat:@"var xhr = new XMLHttpRequest(); xhr.open('POST', %@, true); xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8'); xhr.send(%@);",
                        [LEANUtilities jsWrapString:self.postUrlString],
                        [LEANUtilities jsWrapString:jsonString]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.wkWebView evaluateJavaScript:js completionHandler:nil];
        });
        
        return;
    }
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"Error posting to %@", self.postUrl);
            return;
        }
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = ((NSHTTPURLResponse*)response).statusCode;
            if (statusCode < 200 || statusCode > 299) {
                NSLog(@"Received status code %ld when posting registration data to %@", (long)statusCode, self.postUrl);
            }
        }
    }];
    
    [task resume];
}
@end

#pragma mark Registration Manager Singleton

@interface GNRegistrationManager()
@property NSMutableArray<GNRegistrationEndpoint*> *registrationEndpoints;

@property GNRegistrationInfo *registrationInfo;
@property NSURL *lastUrl;
@end

@implementation GNRegistrationManager

+ (instancetype)sharedManager
{
    static GNRegistrationManager *sharedManager;
    
    @synchronized(self)
    {
        if (!sharedManager){
            sharedManager = [[GNRegistrationManager alloc] init];
        }
        return sharedManager;
    }
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        self.registrationEndpoints = [NSMutableArray array];
        self.registrationInfo = [[GNRegistrationInfo alloc] init];
    }
    return self;
}


-(void)processConfig:(NSArray*)endpoints
{
    [self.registrationEndpoints removeAllObjects];
    
    for (NSDictionary *endpoint in endpoints) {
        if (![endpoint isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        NSString *urlString = endpoint[@"url"];
        NSURL *url = [LEANUtilities urlWithString:urlString];
        if (!url) {
            NSLog(@"Invalid registration endpoint url %@", url);
            continue;
        }
        
        NSArray *urlRegexes = [LEANUtilities createRegexArrayFromStrings:endpoint[@"urlRegex"]];
        
        GNRegistrationEndpoint *registrationEndpoint = [[GNRegistrationEndpoint alloc] initWithUrl:url urlRegexes:urlRegexes];
        [self.registrationEndpoints addObject:registrationEndpoint];
    }
}

-(void)registrationDataChanged
{
    
    for (GNRegistrationEndpoint *endpoint in self.registrationEndpoints) {
        if (self.lastUrl && [LEANUtilities string:[self.lastUrl absoluteString] matchesAnyRegex:endpoint.urlRegexes]) {
            [endpoint sendRegistrationInfo:self.registrationInfo];
        }
    }
}

-(void)sendToAllEndpoints
{
    for (GNRegistrationEndpoint *endpoint in self.registrationEndpoints) {
        [endpoint sendRegistrationInfo:self.registrationInfo];
    }
}

-(void)setOneSignalUserId:(NSString *)userId pushToken:(NSString*)pushToken subscribed:(BOOL)subscribed
{
    self.registrationInfo.oneSignalUserId = userId;
    self.registrationInfo.oneSignalPushToken = pushToken;
    self.registrationInfo.oneSignalSubscribed = YES;
    [self registrationDataChanged];
}

-(void)setCustomData:(NSDictionary *)data
{
    self.registrationInfo.customData = data;
    [self registrationDataChanged];
}

-(void)checkUrl:(NSURL *)url
{
    self.lastUrl = url;
    for (GNRegistrationEndpoint *endpoint in self.registrationEndpoints) {
        if ([LEANUtilities string:[url absoluteString] matchesAnyRegex:endpoint.urlRegexes]) {
            // send after delay. Cookies may not have synced if we send immediately.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [endpoint sendRegistrationInfo:self.registrationInfo];
            });
        }
    }
}

-(void)setOneSignalRequiresPrivacyConsent:(BOOL)requiresPrivacyConsent {
    self.registrationInfo.oneSignalRequiresPrivacyConsent = requiresPrivacyConsent;
}

- (void)handleUrl:(NSURL *)url query:(NSDictionary *)query {
    if ([@"/send" isEqualToString:url.path]) {
        id customData = query[@"customData"];
        
        if (!customData) {
            [self sendToAllEndpoints];
            return;
        }
        
        if ([customData isKindOfClass:[NSString class]]) {
            NSData *jsonData = [customData dataUsingEncoding:NSUTF8StringEncoding];
            customData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        }
        
        if ([customData isKindOfClass:[NSDictionary class]]) {
            [self setCustomData:customData];
            [self sendToAllEndpoints];
        }
    }
}

@end
