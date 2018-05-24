//
//  LEANUrlCache.m
//  GoNativeIOS
//
//  Created by Weiyin He on 6/4/14.
//  Copyright (c) 2014 The Lean App. All rights reserved.
//

#import "LEANUrlCache.h"
#import <zipzap.h>

@interface LEANUrlCache ()
@property ZZArchive *cacheFile;
@property id manifest;
@property NSMutableDictionary *urlsToManifest;
@property NSMutableDictionary *filesToEntries;
@end

@implementation LEANUrlCache

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.urlsToManifest = [[NSMutableDictionary alloc] init];
        
        NSURL *path = [[NSBundle mainBundle] URLForResource:@"localCache" withExtension:@"zip"];
        self.cacheFile = [ZZArchive archiveWithURL:path error:nil];
        self.filesToEntries = [[NSMutableDictionary alloc] init];
        
        for (ZZArchiveEntry *entry in self.cacheFile.entries) {
            [self.filesToEntries setObject:entry forKey:entry.fileName];
            
            if ([entry.fileName isEqualToString:@"manifest.json"]) {
                NSInputStream *inputStream = [entry newStreamWithError:nil];
                [inputStream open];
                self.manifest = [NSJSONSerialization JSONObjectWithStream:inputStream options:0 error:nil];
                [inputStream close];
            }
        }
        
        // process
        if (self.manifest) {
            for (id file in self.manifest[@"files"]) {
                NSString *temp = [LEANUrlCache urlWithoutProtocol:file[@"url"]];
                [self.urlsToManifest setObject:file forKey:temp];
            }
        }
    }
    
    return self;
}

- (BOOL)hasCacheForRequest:(NSURLRequest*)request
{
    if (!self.urlsToManifest) return NO;
    
    NSString *urlString = [LEANUrlCache urlWithoutProtocol:[[request URL] absoluteString]];
    id cached = self.urlsToManifest[urlString];
    if (cached) {
        return YES;
    } else {
        return NO;
    }
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    if (!self.urlsToManifest) return nil;
    
    NSString *urlString = [LEANUrlCache urlWithoutProtocol:[[request URL] absoluteString]];
    id cached = self.urlsToManifest[urlString];
    if (cached) {
        NSString *internalPath = cached[@"path"];
        ZZArchiveEntry *entry = self.filesToEntries[internalPath];
        if (entry) {
            NSError *zipError;
            NSData *data = [entry newDataWithError:&zipError];
            
            if (!zipError) {
                NSString *mimeType = cached[@"mimetype"];
                NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[request URL] MIMEType:mimeType expectedContentLength:entry.uncompressedSize textEncodingName:nil];
                NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];

                return cachedResponse;
            }
        }

    }
    
    return nil;
}

+ (NSString*)urlWithoutProtocol:(NSString*)url
{
    NSRange loc = [url rangeOfString:@":"];
    if (loc.location == NSNotFound) {
        return url;
    } else {
        return [url substringFromIndex:loc.location+1];
    }
    
}

@end
