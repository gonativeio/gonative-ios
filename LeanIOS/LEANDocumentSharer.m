//
//  LEANDocumentSharer.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/26/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANDocumentSharer.h"

@interface LEANDocumentSharer ()
@property UIDocumentInteractionController *interactionController;
@end

@implementation LEANDocumentSharer
+ (BOOL)isSharableRequest:(NSURLRequest *)req
{
    NSArray *shareExtensions = @[@"pdf", @"xls", @"xlsx", @"doc", @"docx", @"ppt", @"pptx"];
    NSString *extension = [req.URL pathExtension];
    if ([shareExtensions containsObject:extension]) {
        return YES;
    }
    else
        return NO;
}

- (void)shareRequest:(NSURLRequest *)req fromButton:(UIBarButtonItem*) button;
{
    button.enabled = NO;
    
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


@end
