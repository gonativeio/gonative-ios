//
//  LEANDocumentSharer.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/26/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANDocumentSharer.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface LEANDocumentSharer ()
@property UIDocumentInteractionController *interactionController;
@property NSArray *allowableMimeTypes;
@property NSString *imageMimePrefix;
@property NSURLRequest *lastRequest;
@property NSURLResponse *lastResponse;
@property NSURL *dataFile;
@property NSFileHandle *dataFileHandle;
@property NSMutableArray *sharableRequests; // array of nsurlrequests
@property BOOL isFinished;
@property BOOL isSharableFile;
@end

@implementation LEANDocumentSharer
+ (LEANDocumentSharer *)sharedSharer
{
    static LEANDocumentSharer *sharedSharer;
    
    @synchronized(self)
    {
        if (!sharedSharer){
            sharedSharer = [[LEANDocumentSharer alloc] init];
        }
        return sharedSharer;
    }
}

- (instancetype) init
{
    self = [super init];
    if (self) {
        NSURL *cacheDir = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]];
        self.dataFile = [cacheDir URLByAppendingPathComponent:@"io.gonative.documentsharer.cachedfile"];
        self.allowableMimeTypes = @[@"application/pdf", // pdf
                                    
                                    @"application/octet-stream",
                                    
                                    // word
                                    @"application/msword",
                                    @"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                                    @"application/vnd.ms-word.document.macroEnabled.12",
                                    @"application/vnd.ms-excel",
                                    
                                    // excel
                                    @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                                    @"application/vnd.ms-excel.sheet.macroEnabled.12",
                                    @"application/vnd.ms-excel.sheet.binary.macroEnabled.12",
                                    @"application/vnd.ms-powerpoint",
                                    
                                    // powerpoint
                                    @"application/vnd.openxmlformats-officedocument.presentationml.presentation",
                                    @"application/vnd.openxmlformats-officedocument.presentationml.slideshow",
                                    @"application/vnd.ms-powerpoint.presentation.macroEnabled.12",
                                    @"application/vnd.ms-powerpoint.slideshow.macroEnabled.12",
                                    
                                    @"application/zip"]; // many MS office documents may be auto-detect as zip files
        self.imageMimePrefix = @"image/";
        self.sharableRequests = [NSMutableArray array];
    }
    return self;
}


- (void)receivedRequest:(NSURLRequest*)request
{
    self.lastRequest = request;
    self.isSharableFile = NO;
    self.isFinished = NO;
}


- (void)receivedResponse:(NSURLResponse*)response
{
    self.lastResponse = response;
    self.isFinished = NO;
    
    // check mime types
    if ([self.allowableMimeTypes containsObject:response.MIMEType] || [response.MIMEType hasPrefix:self.imageMimePrefix]) {
        self.isSharableFile = YES;
        [self.sharableRequests addObject:self.lastRequest];
    }
}


- (void)receivedData:(NSData *)data
{
    self.isFinished = NO;
    
    if (!self.isSharableFile) {
        return;
    }
    
    if (!self.dataFileHandle) {
        [[NSFileManager defaultManager] createFileAtPath:[self.dataFile path] contents:nil attributes:nil];
        NSError *error;
        self.dataFileHandle = [NSFileHandle fileHandleForWritingToURL:self.dataFile error:&error];
        if (error) {
            NSLog(@"Error creating file for document sharer: %@", error);
            self.dataFileHandle = nil;
            return;
        }
    }
    
    [self.dataFileHandle writeData:data];
}

- (void)cancel
{
    [self.dataFileHandle closeFile];
    self.dataFileHandle = nil;
    [[NSFileManager defaultManager] removeItemAtURL:self.dataFile error:nil];
    self.isFinished = NO;
}

- (void)finish
{
    [self.dataFileHandle closeFile];
    self.dataFileHandle = nil;
    self.isFinished = YES;
}

- (BOOL)isSharableRequest:(NSURLRequest *)req
{
    if (self.lastRequest && self.lastResponse && self.isFinished
        && [LEANDocumentSharer request:self.lastRequest matchesRequest:req]){
        return self.isSharableFile;
    } else {
        for (NSURLRequest *savedRequest in self.sharableRequests) {
            if ([LEANDocumentSharer request:req matchesRequest:savedRequest]) {
                return YES;
            }
        }
    }
    
    return NO;
}

+ (BOOL)request:(NSURLRequest*)req1 matchesRequest:(NSURLRequest*)req2
{
    return [req1.URL.absoluteString isEqualToString:req2.URL.absoluteString]
    && [req1.HTTPMethod isEqualToString:req1.HTTPMethod]
    && req1.HTTPBody == req2.HTTPBody
    && req1.HTTPBodyStream == req2.HTTPBodyStream;
}

- (void)shareRequest:(NSURLRequest *)req fromButton:(UIBarButtonItem*) button;
{
    if (![self isSharableRequest:req]) {
        return;
    }
    
    
    // is the last reqwuest we intercepted
    if ([LEANDocumentSharer request:req matchesRequest:self.lastRequest]) {
        // copy to documents folder with a good suggested file name
        NSURL *documentsDir = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]];
        NSURL *sharedFile = [documentsDir URLByAppendingPathComponent:[self.lastResponse suggestedFilename]];
        [[NSFileManager defaultManager] removeItemAtURL:sharedFile error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:self.dataFile toURL:sharedFile error:nil];
        
        // launch the interaction controller
        self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:sharedFile];
        [self.interactionController presentOpenInMenuFromBarButtonItem:button animated:YES];
    } else {
        // download the file
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithRequest:req completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if (error || httpResponse.statusCode != 200 || !location) {
                button.enabled = YES;
                return;
            }
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            
            NSURL *documentsDirectoryPath = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]];
            NSURL *destination = [documentsDirectoryPath URLByAppendingPathComponent:[response suggestedFilename]];
            [fileManager removeItemAtURL:destination error:nil];
            [fileManager moveItemAtURL:location toURL:destination error:nil];
            
            self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:destination];
            [self.interactionController presentOpenInMenuFromBarButtonItem:button animated:YES];
            
            button.enabled = YES;
        }];
        
        [downloadTask resume];
    }
}

@end
