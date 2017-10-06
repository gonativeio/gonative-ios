//
//  LEANWebViewIntercept.m
//  GoNativeIOS
//
//  Created by Weiyin He on 4/12/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANWebViewIntercept.h"
#import "LEANAppDelegate.h"
#import "GoNativeAppConfig.h"
#import "GTMNSString+HTML.h"
#import "LEANWebViewPool.h"
#import "LEANDocumentSharer.h"
#import "LEANUrlCache.h"
#import "GNCustomHeaders.h"

static NSPredicate* schemeHttpTest;
static NSOperationQueue* queue;

static NSString * kOurRequestProperty = @"io.gonative.ios.LEANWebViewIntercept";
static NSString * kRequestPropertyRemoveXframe = @"io.gonative.ios.LEANWebViewIntercept.removeXFrameOptions";
static LEANUrlCache *urlCache;

@interface LEANWebViewIntercept () <NSURLSessionDataDelegate>
@property NSMutableURLRequest *modifiedRequest;
@property NSURLSession *session;
@property NSURLSessionTask *task;
@property BOOL isHtml;
@property NSStringEncoding htmlEncoding;
@property NSMutableData *htmlBuffer;
@property NSCachedURLResponse *localCachedResponse;
@end

@implementation LEANWebViewIntercept

+(void)initialize
{
    [self register];
}

+(void)register
{
    // run only once
    static BOOL isRegistered = NO;
    if (isRegistered) return;
    isRegistered = YES;
    
    schemeHttpTest = [NSPredicate predicateWithFormat:@"scheme in {'http', 'https'}"];
    queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    
    [NSURLProtocol registerClass:[LEANWebViewIntercept class]];
    
    urlCache = [[LEANUrlCache alloc] init];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString* userAgent = [request valueForHTTPHeaderField:@"User-Agent"];
    if (userAgent && ![userAgent isEqualToString:[GoNativeAppConfig sharedAppConfig].userAgent]) return NO;
    if (![schemeHttpTest evaluateWithObject:request.URL]) return NO;
    if ([self propertyForKey:kOurRequestProperty inRequest:request]) return NO;
    
    // yes if it is in localCache.zip
    if ([urlCache hasCacheForRequest:request]) {
        return YES;
    }
    
    // if is equal to current url being loaded, then intercept
    NSURLRequest *currentRequest = [LEANWebviewInterceptTracker sharedTracker].currentRequest;
    NSURLRequest *poolRequest = [LEANWebViewPool sharedPool].currentLoadingRequest;
    
    if (([[request URL] isEqual:[currentRequest URL]] || [[request URL] isEqual:[poolRequest URL]]) &&
        [[request HTTPMethod] isEqualToString:[currentRequest HTTPMethod]] &&
        [request HTTPBody] == [currentRequest HTTPBody] &&
        [request HTTPBodyStream] == [currentRequest HTTPBodyStream]) {
        return YES;
    }
    
    // if has removeXFrameOptions=true, then intercept
    NSURLComponents *components = [NSURLComponents componentsWithURL:request.URL.absoluteURL resolvingAgainstBaseURL:NO];
    if (components) {
        for (NSURLQueryItem *item in components.queryItems) {
            if ([@"removeXFrameOptions" isEqualToString:item.name] &&
                ([@"true" isEqualToString:item.value] || [@"1" isEqualToString:item.value])) {
                return YES;
            }
        }
    }
    // may have gotten redirected from a page with removeXFrameOptions=true
    if ([self propertyForKey:kRequestPropertyRemoveXframe inRequest:request]) return YES;
    
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client {
    
    if (self = [super initWithRequest:request cachedResponse:cachedResponse client:client]) {
        self.modifiedRequest = request.mutableCopy;
        
        // custom user agent
        NSString *customUserAgent = [[GoNativeAppConfig sharedAppConfig] userAgentForUrl:request.URL];
        if (customUserAgent) {
            [self.modifiedRequest setValue:customUserAgent forHTTPHeaderField:@"User-Agent"];
        }
        
        // custom headers
        NSDictionary *customHeaders = [GNCustomHeaders getCustomHeaders];
        if (customHeaders) {
            for (NSString *key in customHeaders) {
                [self.modifiedRequest setValue:customHeaders[key] forHTTPHeaderField:key];
            }
        }
        
        // if url contains removeXFrameOptions, remove it from modified request
        NSURLComponents *components = [NSURLComponents componentsWithURL:request.URL.absoluteURL resolvingAgainstBaseURL:NO];
        NSMutableArray *removeQueries = [NSMutableArray array];
        if (components) {
            for (NSURLQueryItem *item in components.queryItems) {
                if ([@"removeXFrameOptions" isEqualToString:item.name]) {
                    [removeQueries addObject:item];
                }
            }
        }
        if ([removeQueries count] > 0) {
            NSMutableArray<NSURLQueryItem*> *modifiedQueryItems = [components.queryItems mutableCopy];
            [modifiedQueryItems removeObjectsInArray:removeQueries];
            components.queryItems = modifiedQueryItems;
            self.modifiedRequest.URL = [components URL];
            // also set this so that we still do interception even if there is a redirect.
            [[self class] setProperty:[NSNumber numberWithBool:YES] forKey:kRequestPropertyRemoveXframe inRequest:self.modifiedRequest];
        }
        
        // this prevents us from re-intercepting the subsequent request. kOurRequestProperty is checked for in canInitWithRequest
        [[self class] setProperty:[NSNumber numberWithBool:YES] forKey:kOurRequestProperty inRequest:self.modifiedRequest];
        
        // try to get from localCache.zip
        self.localCachedResponse = [urlCache cachedResponseForRequest:request];
    }
    self.isHtml = NO;
    [[LEANDocumentSharer sharedSharer] receivedRequest:request];
    return self;
}

- (void)startLoading {
    if (self.localCachedResponse) {
        [self.client URLProtocol:self didReceiveResponse:self.localCachedResponse.response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:self.localCachedResponse.data];
        [self.client URLProtocolDidFinishLoading:self];
    }
    else {
        NSLog(@"start loading %@", self.modifiedRequest.URL);
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        self.task = [self.session dataTaskWithRequest:self.modifiedRequest];
        [self.task resume];
    }
}

- (void)stopLoading {
    [self.session invalidateAndCancel];
    self.session = nil;
    self.modifiedRequest = nil;
}

- (NSData *)modifyHtml:(NSData *)htmlBuffer
{
    NSString *htmlString = [[NSString alloc] initWithData:htmlBuffer encoding:self.htmlEncoding];
    // if decoding fails, try other encodings
    if ([htmlBuffer length] > 0 && [htmlString length] == 0) {
        htmlString = [[NSString alloc] initWithData:htmlBuffer encoding:NSWindowsCP1252StringEncoding];
    }
    if ([htmlBuffer length] > 0 && [htmlString length] == 0) {
        htmlString = [[NSString alloc] initWithData:htmlBuffer encoding:NSISOLatin1StringEncoding];
    }
    if ([htmlBuffer length] > 0 && [htmlString length] == 0) {
        htmlString = [[NSString alloc] initWithData:htmlBuffer encoding:NSASCIIStringEncoding];
    }
    
    // bail out if we still cannot decode the string
    if ([htmlString length] == 0) {
        return htmlBuffer;
    }
    
    // string replacements
    for (NSDictionary *entry in [GoNativeAppConfig sharedAppConfig].replaceStrings) {
        if ([entry isKindOfClass:[NSDictionary class]]) {
            NSString *old = entry[@"old"];
            NSString *new = entry[@"new"];
            if ([old isKindOfClass:[NSString class]] && [new isKindOfClass:[NSString class]]) {
                htmlString = [htmlString stringByReplacingOccurrencesOfString:old withString:new];
            }
        }
    }
    
    // find closing </head> tag
    NSRange insertPoint = [htmlString rangeOfString:@"</head>" options:NSCaseInsensitiveSearch];
    if (insertPoint.location != NSNotFound) {
        NSString *customCss = [GoNativeAppConfig sharedAppConfig].customCss;
        NSString *stringViewport = [GoNativeAppConfig sharedAppConfig].stringViewport;
        NSNumber *viewportWidth = [GoNativeAppConfig sharedAppConfig].forceViewportWidth;
        
        NSMutableString *newString = [[htmlString substringToIndex:insertPoint.location] mutableCopy];
        if (customCss) {
            [newString appendString:@"<style>"];
            [newString appendString:customCss];
            [newString appendString:@"</style>"];
        }
        
        
        if (stringViewport) {
            [newString appendString:@"<meta name=\"viewport\" content=\""];
            [newString appendString:[stringViewport gtm_stringByEscapingForHTML]];
            [newString appendString:@"\">"];
        }
        if (viewportWidth) {
            [newString appendFormat:@"<meta name=\"viewport\" content=\"width=%@,user-scalable=no\"/>", viewportWidth];
        }
        
        if (!stringViewport && !viewportWidth) {
            // find original viewport
            NSString *origViewport = [LEANWebViewIntercept extractViewport:htmlString];
            
            if ([origViewport length] > 0) {
                [newString appendFormat:@"<meta name=\"viewport\" content=\"%@,user-scalable=no\"/>", origViewport];
            }
            else {
                [newString appendFormat:@"<meta name=\"viewport\" content=\"user-scalable=no\"/>"];
            }
        }
        
        [newString appendString:[htmlString substringFromIndex:insertPoint.location]];
        return [newString dataUsingEncoding:self.htmlEncoding];
    } else {
        return [htmlString dataUsingEncoding:self.htmlEncoding];
    }

}

+(NSString *)extractViewport:(NSString*)html
{
    if (!html) return nil;
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<meta\\s+name=[\"']viewport[\"']\\s+content=[\"']([-;,=\\.\\w\\s]+)[\"']\\s*/?>" options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray *results = [regex matchesInString:html options:0 range:NSMakeRange(0, [html length])];
    if ([results count] > 0) {
        NSTextCheckingResult *result = results[0];
        return [html substringWithRange:[result rangeAtIndex:1]];
    }
    
    regex = [NSRegularExpression regularExpressionWithPattern:@"<meta\\s+content=[\"']([-;,=\\.\\w\\s]+)[\"']\\s+name=[\"']viewport[\"']\\s*/?>" options:NSRegularExpressionCaseInsensitive error:nil];
    results = [regex matchesInString:html options:0 range:NSMakeRange(0, [html length])];
    if ([results count] > 0) {
        NSTextCheckingResult *result = results[0];
        return [html substringWithRange:[result rangeAtIndex:1]];
    }
    
    return nil;
}

#pragma mark - URL Session Delegate
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        // remove X-Frame-Options from all responses
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        NSDictionary *headers = [httpResponse allHeaderFields];
        if (headers[@"x-frame-options"]) {
            NSMutableDictionary *modifiedHeaders = [headers mutableCopy];
            [modifiedHeaders removeObjectForKey:@"x-frame-options"];
            response = [[NSHTTPURLResponse alloc] initWithURL:httpResponse.URL statusCode:httpResponse.statusCode HTTPVersion:nil headerFields:modifiedHeaders];
        }
    }
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    
    [[LEANDocumentSharer sharedSharer] receivedResponse:response];
    
    if ([[response MIMEType] hasPrefix:@"text/html"]) {
        self.isHtml = YES;
        self.htmlBuffer = [[NSMutableData alloc] init];
        NSString *encoding = [response textEncodingName];
        if (encoding == nil) {
            self.htmlEncoding = NSUTF8StringEncoding;
        } else {
            CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)encoding);
            if (cfEncoding == kCFStringEncodingInvalidId)
                self.htmlEncoding = NSUTF8StringEncoding;
            else
                self.htmlEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
        }
    } else {
        self.isHtml = NO;
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    if (self.isHtml)
        [self.htmlBuffer appendData:data];
    else
        [self.client URLProtocol:self didLoadData:data];
    
    [[LEANDocumentSharer sharedSharer] receivedData:data];
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self.session invalidateAndCancel];
    
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
        [[LEANDocumentSharer sharedSharer] cancel];
        return;
    }
    
    if (self.isHtml) {
        [self.client URLProtocol:self didLoadData:[self modifyHtml:self.htmlBuffer]];
    } else {
        [self.client URLProtocol:self didLoadData:self.htmlBuffer];
    }
    
    [self.client URLProtocolDidFinishLoading:self];
    [[LEANDocumentSharer sharedSharer] finish];
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
    if (request != nil) {
        NSMutableURLRequest *newReq = [request mutableCopy];
        [[self class] removePropertyForKey:kOurRequestProperty inRequest:newReq];
        [self.client URLProtocol:self wasRedirectedToRequest:newReq redirectResponse:response];
        
        // client will resend request, so cancel this one.
        // See Apple's CustomHTTPProtocol example.
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
    }
    completionHandler(nil);
}

@end

@implementation LEANWebviewInterceptTracker
+ (LEANWebviewInterceptTracker *)sharedTracker
{
    static LEANWebviewInterceptTracker *sharedTracker;
    
    @synchronized(self)
    {
        if (!sharedTracker) {
            sharedTracker = [[LEANWebviewInterceptTracker alloc] init];
        }
        return sharedTracker;
    }
}
@end

