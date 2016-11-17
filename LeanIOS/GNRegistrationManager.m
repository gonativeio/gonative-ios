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
#import "GoNativeAppConfig.h"

#pragma mark Registration Data

typedef NS_OPTIONS(NSUInteger, RegistrationData) {
    RegistrationDataInstallation = 1 << 0,
    RegistrationDataPush = 1 << 1,
    RegistrationDataParse = 1 << 2,
    RegistrationDataOneSignal = 1 << 3,
    RegistrationDataCustom = 1 << 4
};

@interface GNRegistrationInfo : NSObject
@property NSData *pushRegistrationToken;
@property NSString *parseInstallationId;
@property NSString *oneSignalUserId;
@property NSDictionary *customData;
@end
@implementation GNRegistrationInfo
@end

#pragma mark Registration endpoint (individual)

@interface GNRegistrationEndpoint : NSObject
@property NSURL *postUrl;
@property NSString *postUrlString;
@property NSArray *urlRegexes;
@property RegistrationData dataTypes;
// WKWebView cookies are not shared with native url request functions, so if we are using
// WK, use a hidden webview to do POSTs.
@property WKWebView *wkWebView;
@end

@implementation GNRegistrationEndpoint
-(instancetype)initWithUrl:(NSURL*)postUrl urlRegexes:(NSArray*)urlRegexes dataTypes:(RegistrationData)dataTypes
{
    self = [super init];
    if (self) {
        self.postUrl = postUrl;
        self.postUrlString = [self.postUrl absoluteString];
        self.urlRegexes = urlRegexes;
        self.dataTypes = dataTypes;
        
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
    NSMutableDictionary *toSend = [NSMutableDictionary dictionary];
    
    if (self.dataTypes & RegistrationDataInstallation) {
        [toSend addEntriesFromDictionary:[LEANInstallation info]];
    }
    
    if (self.dataTypes & RegistrationDataPush && info.pushRegistrationToken) {
        toSend[@"deviceToken"] = [info.pushRegistrationToken base64EncodedStringWithOptions:0];
    }
    
    if (self.dataTypes & RegistrationDataParse && info.parseInstallationId) {
        toSend[@"parseInstallationId"] = info.parseInstallationId;
    }
    
    if (self.dataTypes & RegistrationDataOneSignal && info.oneSignalUserId) {
        toSend[@"oneSignalUserId"] = info.oneSignalUserId;
    }
    
    if (self.dataTypes & RegistrationDataCustom && info.customData) {
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
        [self.wkWebView evaluateJavaScript:js completionHandler:nil];
        
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
@property RegistrationData allDataTypes;

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

-(RegistrationData)registrationDataTypeFromString:(NSString*)string
{
    if ([string caseInsensitiveCompare:@"installation"] == NSOrderedSame) {
        return RegistrationDataInstallation | RegistrationDataCustom;
    }
    else if ([string caseInsensitiveCompare:@"push"] == NSOrderedSame) {
        return RegistrationDataPush | RegistrationDataInstallation | RegistrationDataCustom;
    }
    else if ([string caseInsensitiveCompare:@"parse"] == NSOrderedSame) {
        return RegistrationDataParse | RegistrationDataInstallation | RegistrationDataCustom;
    }
    else if ([string caseInsensitiveCompare:@"onesignal"] == NSOrderedSame) {
        return RegistrationDataOneSignal | RegistrationDataInstallation | RegistrationDataCustom;
    }
    
    return 0;
}

-(void)processConfig:(NSArray*)endpoints
{
    [self.registrationEndpoints removeAllObjects];
    self.allDataTypes = 0;
    
    for (NSDictionary *endpoint in endpoints) {
        if (![endpoint isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        NSString *urlString = endpoint[@"url"];
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            NSLog(@"Invalid registration endpoint url %@", url);
            continue;
        }
        
        RegistrationData dataTypes = 0;
        if ([endpoint[@"dataType"] isKindOfClass:[NSString class]]) {
            dataTypes = [self registrationDataTypeFromString:endpoint[@"dataType"]];
        } else if ([endpoint[@"dataType"] isKindOfClass:[NSArray class]]) {
            NSArray *dataTypesArray = endpoint[@"dataType"];
            for (NSString *entry in dataTypesArray) {
                if (![entry isKindOfClass:[NSString class]]) continue;
                dataTypes |= [self registrationDataTypeFromString:entry];
            }
        }
        
        if (!dataTypes) {
            NSLog(@"No data types specified for registration endpoint %@", urlString);
            continue;
        }
        
        NSArray *urlRegexes = [LEANUtilities createRegexArrayFromStrings:endpoint[@"urlRegex"]];
        
        GNRegistrationEndpoint *registrationEndpoint = [[GNRegistrationEndpoint alloc] initWithUrl:url urlRegexes:urlRegexes dataTypes:dataTypes];
        [self.registrationEndpoints addObject:registrationEndpoint];
        self.allDataTypes |= dataTypes;
    }
}

-(void)registrationDataChanged:(RegistrationData)type
{
    if (!self.allDataTypes & type) return;
    
    for (GNRegistrationEndpoint *endpoint in self.registrationEndpoints) {
        if (!(endpoint.dataTypes & type)) continue;
        
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

-(void)setPushRegistrationToken:(NSData*)token
{
    self.registrationInfo.pushRegistrationToken = token;
    [self registrationDataChanged:RegistrationDataPush];
}

-(void)setParseInstallationId:(NSString*)installationId
{
    self.registrationInfo.parseInstallationId = installationId;
    [self registrationDataChanged:RegistrationDataParse];
}

-(void)setOneSignalUserId:(NSString *)userId
{
    self.registrationInfo.oneSignalUserId = userId;
    [self registrationDataChanged:RegistrationDataOneSignal];
}

-(void)setCustomData:(NSDictionary *)data
{
    self.registrationInfo.customData = data;
    [self registrationDataChanged:RegistrationDataCustom];
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

-(BOOL)pushEnabled
{
    return self.allDataTypes & RegistrationDataPush;
}

@end
