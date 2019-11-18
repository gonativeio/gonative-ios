//
//  GNFileWriterSharer.m
//  GonativeIO
//
//  Created by Weiyin He on 11/16/19.
//  Copyright © 2019 GoNative.io LLC. All rights reserved.
//

#import "GNFileWriterSharer.h"
#import "LEANUtilities.h"

@interface GNFileWriterSharerFileInfo : NSObject
@property NSString *identifier;
@property NSString *fileName;
@property NSUInteger size;
@property NSString *type;

@property NSURL *containerDir;
@property NSURL *savedFileUrl;
@property NSFileHandle *fileHandle;
@property NSUInteger bytesWritten;
@end
@implementation GNFileWriterSharerFileInfo
@end

@interface GNFileWriterSharer() <UIDocumentInteractionControllerDelegate>
@property NSMutableDictionary *idToFileInfo;
@property UIDocumentInteractionController *documentInteractionController;
@property GNFileWriterSharerFileInfo *interactingFile;
@property NSString *nextFileName;
@end

@implementation GNFileWriterSharer

-(instancetype) init
{
    self = [super init];
    if (self) {
        self.idToFileInfo = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
    
    if (![LEANUtilities checkNativeBridgeUrl:message.frameInfo.request.URL.absoluteString]) {
        NSLog(@"Invalid url %@ for call to %@", message.frameInfo.request.URL.absoluteString,
              GNFileWriterSharerName);
        return;
    }
    
    if (![message.body isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Message to %@ must be an object/dictionary", GNFileWriterSharerName);
        return;
    }
    
    if (![message.name isEqualToString:GNFileWriterSharerName]) {
        NSLog(@"Message name %@ does not match %@", message.name, GNFileWriterSharerName);
        return;
    }
    
    NSString *event = message.body[@"event"];
    if ([@"fileStart" isEqualToString:event]) {
        [self receivedFileStart:message.body];
    } else if ([@"fileChunk" isEqualToString:event]) {
        [self receivedFileChunk:message.body];
    } else if ([@"fileEnd" isEqualToString:event]) {
        [self receivedFileEnd:message.body];
    } else if([@"nextFileInfo" isEqualToString:event]) {
        [self receivedNextFileInfo:message.body];
    } else {
        NSLog(@"Message to %@ has invalid event %@", message.name, event);
    }
}

- (void)receivedFileStart:(NSDictionary*)message
{
    NSString *identifier = message[@"id"];
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) {
        NSLog(@"Invalid file id");
        return;
    }
    
    NSString *fileName = message[@"name"];
    if (![fileName isKindOfClass:[NSString class]] || fileName.length == 0) {
        if (self.nextFileName) {
            fileName = self.nextFileName;
            self.nextFileName = nil;
        } else {
            fileName = @"download";
        }
    }
    
    NSNumber *fileSize = message[@"size"];
    if (![fileSize isKindOfClass:[NSNumber class]]) {
        NSLog(@"Invalid file size");
        return;
    }
    NSUInteger size = [fileSize unsignedIntegerValue];
    if (size <= 0 || size > GNFileWriterSharerMaxSize) {
        NSLog(@"Invalid file size");
        return;
    }
    
    NSString *type = message[@"type"];
    if (![type isKindOfClass:[NSString class]] || type.length == 0) {
        NSLog(@"Invalid file type");
        return;
    }
    
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSURL *fileWriterDir = [fileManager.temporaryDirectory URLByAppendingPathComponent:@"fileWriterSharer" isDirectory:YES];
    NSURL *containerDir = [fileWriterDir URLByAppendingPathComponent:[NSUUID UUID].UUIDString isDirectory:YES];
    [fileManager createDirectoryAtURL:containerDir withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        NSLog(@"Error creating directory %@: %@", fileWriterDir, error);
        return;
    }
    
    NSURL *savedFileUrl = [containerDir URLByAppendingPathComponent:fileName isDirectory:NO];
    [fileManager createFileAtPath:savedFileUrl.path contents:nil attributes:nil];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:savedFileUrl error:&error];
    if (error) {
        NSLog(@"Error creating file handler for %@: %@", savedFileUrl, error);
        return;
    }
    
    GNFileWriterSharerFileInfo *info = [[GNFileWriterSharerFileInfo alloc] init];
    info.identifier = identifier;
    info.fileName = fileName;
    info.size = size;
    info.type = type;
    info.containerDir = containerDir;
    info.savedFileUrl = savedFileUrl;
    info.fileHandle = fileHandle;
    info.bytesWritten = 0;
    
    self.idToFileInfo[identifier] = info;
}

- (void)receivedFileChunk:(NSDictionary*)message
{
    NSString *identifier = message[@"id"];
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) {
        return;
    }
    
    GNFileWriterSharerFileInfo *fileInfo = self.idToFileInfo[identifier];
    if (!fileInfo) {
        return;
    }
    
    NSString *data = message[@"data"];
    if (![data isKindOfClass:[NSString class]]) {
        return;
    }
    
    NSRange range = [data rangeOfString:@";base64,"];
    if (range.location == NSNotFound) {
        return;
    }
    
    NSString *base64 = [data substringFromIndex:range.location + range.length];
    NSData *chunk = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    
    if (fileInfo.bytesWritten + chunk.length > fileInfo.size) {
        NSLog(@"Received too many bytes. Expected %ld", fileInfo.size);
        [fileInfo.fileHandle closeFile];
        [[NSFileManager defaultManager] removeItemAtURL:fileInfo.savedFileUrl error:nil];
        [self.idToFileInfo removeObjectForKey:identifier];
        return;
    }
    
    [fileInfo.fileHandle writeData:chunk];
    fileInfo.bytesWritten += chunk.length;
}

-(void)receivedFileEnd:(NSDictionary*)message
{
    NSString *identifier = message[@"id"];
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) {
        NSLog(@"Invalid identifier %@ for fileEnd", identifier);
        return;
    }
    GNFileWriterSharerFileInfo *fileInfo = self.idToFileInfo[identifier];
    if (!fileInfo) {
        NSLog(@"Invalid identifier %@ for fileEnd", identifier);
        return;
    }
    [fileInfo.fileHandle closeFile];
    
    if (fileInfo.bytesWritten != fileInfo.size) {
        NSLog(@"We only got %ld bytes, expected %ld", fileInfo.bytesWritten, fileInfo.size);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIDocumentInteractionController *document = [UIDocumentInteractionController interactionControllerWithURL:fileInfo.savedFileUrl];
        self.documentInteractionController = document;
        self.interactingFile = fileInfo;
        document.name = fileInfo.fileName;
        document.UTI = [LEANUtilities utiFromMimetype:fileInfo.type];
        document.delegate = self;
        [document presentOptionsMenuFromRect:CGRectZero inView:self.webView animated:YES];
    });
}

-(void)receivedNextFileInfo:(NSDictionary*)message
{
    NSString *name = message[@"name"];
    if (![name isKindOfClass:[NSString class]] || name.length == 0) {
        NSLog(@"Invalid name for nextFileInfo");
        return;
    }
    
    self.nextFileName = name;
}

-(void)downloadBlobUrl:(NSString *)url
{
    NSURL *jsFile = [[NSBundle mainBundle] URLForResource:@"BlobDownloader" withExtension:@"js"];
    NSString *js = [NSString stringWithContentsOfURL:jsFile encoding:NSUTF8StringEncoding error:nil];
    [self.wvc runJavascript:js];
    js = [NSString stringWithFormat:@"gonativeDownloadBlobUrl(%@)", [LEANUtilities jsWrapString:url]];
    [self.wvc runJavascript:js];
}

#pragma mark UIDocumentInteractionControllerDelegate
-(void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller
{
    if (self.documentInteractionController == controller) {
        self.documentInteractionController = nil;
        if (self.interactingFile) {
            [[NSFileManager defaultManager] removeItemAtURL:self.interactingFile.savedFileUrl error:nil];
            [[NSFileManager defaultManager] removeItemAtURL:self.interactingFile.containerDir error:nil];
        }
    }
}

@end
