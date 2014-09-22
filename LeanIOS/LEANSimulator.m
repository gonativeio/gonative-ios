//
//  LEANSimulator.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/21/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANSimulator.h"
#import "LEANAppDelegate.h"
#import "LEANAppConfig.h"
#import "LEANLoginManager.h"
#import "LEANPushManager.h"
#import "LEANUrlInspector.h"
#import "LEANWebViewPool.h"
#import "LEANConfigUpdater.h"

static NSString * const simulatorConfigTemplate = @"https://gonative.io/api/simulator/appConfig/%@";

@interface FileToDownload : NSObject
@property NSURL *url;
@property NSURL *destination;
@end
@implementation FileToDownload
+(instancetype)fileToDownloadWithUrl:(NSURL*)url destination:(NSURL*)destination
{
    FileToDownload *instance = [[FileToDownload alloc] init];
    instance.url = url;
    instance.destination = destination;
    return instance;
}
@end


@interface LEANSimulator () <UIAlertViewDelegate>
@property NSURLSessionTask *downloadTask;
@property NSMutableArray *filesToDownload;
@property NSString *simulatePublicKey;
@property UIWindow *simulatorBarWindow;
@property UINavigationBar *simulatorBarBackground;
@property UIButton *simulatorBarButton;
@property UIAlertView *progressAlert;
@property NSTimer *showBarTimer;
@property NSTimer *spinTimer;
@property NSInteger state;
@end


@implementation LEANSimulator

+ (LEANSimulator *)sharedSimulator
{
    static LEANSimulator *sharedSimulator;
    
    @synchronized(self)
    {
        if (!sharedSimulator){
            sharedSimulator = [[LEANSimulator alloc] init];
        }
        return sharedSimulator;
    }
}

+(BOOL)openURL:(NSURL *)url
{
    return [[LEANSimulator sharedSimulator] openURL:url];
}

-(BOOL)openURL:(NSURL*)url
{
    if (![LEANAppConfig sharedAppConfig].isSimulator) {
        return NO;
    }
    
    if (![[url scheme] isEqualToString:@"gonative.io"] || ![[url host] isEqualToString:@"gonative.io"]) {
        return NO;
    }
    
    NSArray *components = [url pathComponents];
    NSUInteger pos = [components indexOfObject:@"simulate" inRange:NSMakeRange(0, [components count] - 1)];
    if (pos == NSNotFound) {
        return NO;
    }
    
    
    self.simulatePublicKey = components[pos+1];
    if ([self.simulatePublicKey length] == 0) {
        return NO;
    }
    
    // check public key is all lowercase and 5-10 characters long
    NSCharacterSet *invalidCharacters = [[NSCharacterSet lowercaseLetterCharacterSet] invertedSet];
    if ([self.simulatePublicKey length] < 5 || [self.simulatePublicKey length] > 10 ||
        [self.simulatePublicKey rangeOfCharacterFromSet:invalidCharacters].location != NSNotFound) {
        NSLog(@"Invalid public key for simulator");
        return NO;
    }
    
    NSURL *configUrl = [NSURL URLWithString:[NSString stringWithFormat:simulatorConfigTemplate, self.simulatePublicKey]];
    [self showProgress];
    
    self.downloadTask = [[NSURLSession sharedSession] dataTaskWithURL:configUrl completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        
        if (error || [httpResponse statusCode] != 200 || [data length] == 0) {
            NSLog(@"Error downloading simulator config (status code %ld) %@", (long)[httpResponse statusCode],  error);
            
            if ([error code] != NSURLErrorCancelled) {
                NSString *message;
                if ([httpResponse statusCode] == 404) {
                    message = @"Could not find application.";
                } else {
                    message = @"Unable to load app. Check your internet connection and try again.";
                }
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alert show];
                });
            }

            [self cancel];
        }
        else {
            // parse json to make sure it's valid
            NSError *jsonError;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
                NSLog(@"Invalid appConfig.json downloaded");
                return;
            }
            
            [data writeToURL:[LEANSimulator tempConfigUrl] atomically:YES];
            
            self.filesToDownload = [NSMutableArray array];
            
            if ([json[@"styling"][@"icon"] isKindOfClass:[NSString class]]) {
                NSURL *url = [NSURL URLWithString:json[@"styling"][@"icon"] relativeToURL:[NSURL URLWithString:@"https://gonative.io/"]];
                [self.filesToDownload addObject:[FileToDownload fileToDownloadWithUrl:url destination:[LEANSimulator tempIconUrl]]];
            }
            
            if ([json[@"styling"][@"iosHeaderImage"] isKindOfClass:[NSString class]]) {
                NSURL *iconUrl = [NSURL URLWithString:json[@"styling"][@"iosHeaderImage"] relativeToURL:[NSURL URLWithString:@"https://gonative.io/"]];
                [self.filesToDownload addObject:[FileToDownload fileToDownloadWithUrl:iconUrl destination:[LEANSimulator tempSidebarIconUrl]]];
            }
            
            if ([json[@"styling"][@"navigationTitleImageLocation"] isKindOfClass:[NSString class]]) {
                NSURL *iconUrl = [NSURL URLWithString:json[@"styling"][@"navigationTitleImageLocation"] relativeToURL:[NSURL URLWithString:@"https://gonative.io/"]];
                [self.filesToDownload addObject:[FileToDownload fileToDownloadWithUrl:iconUrl destination:[LEANSimulator tempNavigationTitleIconUrl]]];
            }
            
            
            [self downloadNextFile];
        }
    }];
    [self.downloadTask resume];
    
    return YES;
}

- (void)downloadNextFile
{
    if ([self.filesToDownload count] > 0) {
        FileToDownload *entry = [self.filesToDownload lastObject];
        [self.filesToDownload removeLastObject];
        
        self.downloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:entry.url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if (error || [httpResponse statusCode] != 200 || !location) {
                NSLog(@"Error downloading %@ (status code %ld) %@", entry.url, (long)[httpResponse statusCode],  error);
            } else {
                [LEANSimulator moveFileFrom:location to:entry.destination];
            }
            
            [self downloadNextFile];
        }];
        
        [self.downloadTask resume];
    } else {
        [self startspin];
    }
}

- (void)startSimulation
{
    [LEANSimulator moveFileFrom:[LEANSimulator tempConfigUrl] to:[LEANAppConfig urlForSimulatorConfig]];
    [LEANSimulator moveFileFrom:[LEANSimulator tempIconUrl] to:[LEANAppConfig urlForSimulatorIcon]];
    [LEANSimulator moveFileFrom:[LEANSimulator tempSidebarIconUrl] to:[LEANAppConfig urlForSimulatorSidebarIcon]];
    [LEANSimulator moveFileFrom:[LEANSimulator tempNavigationTitleIconUrl] to:[LEANAppConfig urlForSimulatorNavTitleIcon]];
    
    [LEANSimulator reloadApplication];
    NSString *simulatePublicKey = self.simulatePublicKey;
    if (!simulatePublicKey) simulatePublicKey = @"";
    [LEANConfigUpdater registerEvent:@"simulate" data:@{@"publicKey": simulatePublicKey}];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"is_simulating"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)moveFileFrom:(NSURL*)source to:(NSURL*)destination
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtURL:destination error:nil];
    [fileManager moveItemAtURL:source toURL:destination error:nil];
}

+ (NSURL*)tempUrlForFile:(NSString*)name
{
    if(!name) return nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *cacheDir = [[fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
    
    NSURL *directory = [cacheDir URLByAppendingPathComponent:@"simulatorFiles" isDirectory:YES];
    [directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    [fileManager createDirectoryAtURL:directory withIntermediateDirectories:NO attributes:nil error:nil];
    
    NSURL *url = [directory URLByAppendingPathComponent:name];
    [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    return url;
}

+ (NSURL*)tempConfigUrl
{
    return [LEANSimulator tempUrlForFile:@"appConfig.json"];
}

+ (NSURL*)tempIconUrl
{
    return [LEANSimulator tempUrlForFile:@"appIcon.image"];
}

+ (NSURL*)tempSidebarIconUrl
{
    return [LEANSimulator tempUrlForFile:@"sidebarIcon.image"];
}

+ (NSURL*)tempNavigationTitleIconUrl
{
    return [LEANSimulator tempUrlForFile:@"navTitleIcon.image"];
}

+ (void)checkStatus
{
    [[LEANSimulator sharedSimulator].showBarTimer invalidate];
    [LEANSimulator sharedSimulator].showBarTimer = nil;
    if ([LEANAppConfig sharedAppConfig].isSimulating) {
        [LEANSimulator sharedSimulator].showBarTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:[LEANSimulator sharedSimulator] selector:@selector(showSimulatorBar) userInfo:nil repeats:NO];
    } else {
        [[LEANSimulator sharedSimulator] hideSimulatorBar];
    }
}

+ (void)didChangeStatusBarOrientation
{
    [[LEANSimulator sharedSimulator] didChangeStatusBarOrientation];
    [[LEANSimulator sharedSimulator] hideSimulatorBar];
    [LEANSimulator checkStatus];
}

-(void)didChangeStatusBarOrientation
{
    [self hideSimulatorBar];
    [LEANSimulator checkStatus];
}

- (void)showSimulatorBar
{
    CGRect frame = [[UIApplication sharedApplication] statusBarFrame];
    
    // all work is done in fixed coordinate space, which is what iOS7 provides. iOS8 gives us orientation-dependent coordinates, so convert back to fixed.
    UIScreen *screen = [UIScreen mainScreen];
    if ([screen respondsToSelector:@selector(fixedCoordinateSpace)]) {
        frame = [screen.coordinateSpace convertRect:frame toCoordinateSpace:screen.fixedCoordinateSpace];
    }

    CGSize statusBarSize = CGSizeMake(MAX(frame.size.height, frame.size.width),
                                      MIN(frame.size.height, frame.size.width));
    
    if (!self.simulatorBarWindow) {
        self.simulatorBarWindow = [[UIWindow alloc] initWithFrame:frame];
        self.simulatorBarWindow.windowLevel = UIWindowLevelStatusBar + 1;
    }
    
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    BOOL wasHidden = self.simulatorBarWindow.hidden;
    if (wasHidden) {
        // move the bar slightly off-frame so it can be animated into place
        if (orientation == UIInterfaceOrientationPortrait) {
            self.simulatorBarWindow.center = CGPointMake(frame.origin.x + (frame.size.width / 2),
                                                         frame.origin.y - (frame.size.height / 2));
        } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
            self.simulatorBarWindow.center = CGPointMake(frame.origin.x - (frame.size.width / 2),
                                                         frame.origin.y + (frame.size.height / 2));
        } else if (orientation == UIInterfaceOrientationLandscapeRight) {
            self.simulatorBarWindow.center = CGPointMake(frame.origin.x + 3*(frame.size.width / 2),
                                                         frame.origin.y + (frame.size.height / 2));
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            self.simulatorBarWindow.center = CGPointMake(frame.origin.x + (frame.size.width / 2),
                                                         frame.origin.y + 3*(frame.size.height / 2));
        }
    }
    
    self.simulatorBarWindow.hidden = [UIApplication sharedApplication].statusBarHidden;
    
    
    if (orientation == UIInterfaceOrientationPortrait) {
        self.simulatorBarWindow.transform = CGAffineTransformIdentity;
    } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
        self.simulatorBarWindow.transform = CGAffineTransformMakeRotation(-M_PI_2);
    } else if (orientation == UIInterfaceOrientationLandscapeRight) {
        self.simulatorBarWindow.transform = CGAffineTransformMakeRotation(M_PI_2);
    } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
        self.simulatorBarWindow.transform = CGAffineTransformMakeRotation(M_PI);
    } else {
        self.simulatorBarWindow.transform = CGAffineTransformIdentity;
    }
    
    CGRect windowBounds = self.simulatorBarWindow.bounds;
    windowBounds.size = statusBarSize;
    self.simulatorBarWindow.bounds = windowBounds;
    
    if (!self.simulatorBarBackground) {
        self.simulatorBarBackground = [[UINavigationBar alloc] init];
        self.simulatorBarBackground.opaque = NO;
        [self.simulatorBarWindow addSubview:self.simulatorBarBackground];
    }
    self.simulatorBarBackground.frame = self.simulatorBarWindow.bounds;
    if ([[LEANAppConfig sharedAppConfig].iosTheme isEqualToString:@"dark"]) {
        self.simulatorBarBackground.barStyle = UIBarStyleBlack;
    } else {
        self.simulatorBarBackground.barStyle = UIBarStyleDefault;
    }
    
    if (!self.simulatorBarButton) {
        self.simulatorBarButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.simulatorBarButton.opaque = NO;
        self.simulatorBarButton.titleLabel.font = [UIFont systemFontOfSize:16.0];
        [self.simulatorBarButton setTitle:@"Tap to end GoNative.io simulator" forState:UIControlStateNormal];
        [self.simulatorBarButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.simulatorBarBackground addSubview:self.simulatorBarButton];
    }
    self.simulatorBarButton.frame = self.simulatorBarBackground.bounds;
    [self.simulatorBarButton setTitleColor:[LEANAppConfig sharedAppConfig].tintColor forState:UIControlStateNormal];
    
    if (wasHidden) {
        [UIView animateWithDuration:0.6 animations:^{
            self.simulatorBarWindow.center = CGPointMake(frame.origin.x + (frame.size.width / 2),
                                                         frame.origin.y + (frame.size.height / 2));
        }];
    }
}

- (void)hideSimulatorBar
{
    if (self.simulatorBarWindow) {
        self.simulatorBarWindow.hidden = YES;
    }
}

- (void) buttonPressed:(id)sender
{
    [self stopSimulation];
}

- (void)cancel
{
    [self hideProgress];
    [self.downloadTask cancel];
    self.downloadTask = nil;
    [self.spinTimer invalidate];
    self.spinTimer = nil;
}


+(void)reloadApplication
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[LEANLoginManager sharedManager] stopChecking];
        
        // clear cookies
        NSHTTPCookie *cookie;
        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (cookie in [storage cookies]) {
            [storage deleteCookie:cookie];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // Change out AppConfig.
        LEANAppConfig *appConfig = [LEANAppConfig sharedAppConfig];
        [appConfig setupFromJsonFiles];
        
        // Rerun some app delegate stuff
        [(LEANAppDelegate*)[UIApplication sharedApplication].delegate configureApplication];
        
        // recreate the entire view controller heirarchy
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        window.rootViewController = [window.rootViewController.storyboard instantiateInitialViewController];
        
        // refresh some singletons
        if (appConfig.loginDetectionURL) {
            [[LEANLoginManager sharedManager] checkLogin];
        }
        
        [[LEANUrlInspector sharedInspector] setup];
        [[LEANWebViewPool sharedPool] setup];
        [[LEANPushManager sharedManager] sendRegistration];
    });
}

- (void)startspin
{
    self.state = 0;
    [self spin];
}

- (void)spin
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.state == 1) {
            self.progressAlert.message = @"Unpacking ...";
        } else if (self.state == 2) {
            self.progressAlert.message = @"Processing ...";
        } else if (self.state == 3) {
            self.progressAlert.message = @"Launch!";
        } else if (self.state >= 4) {
            [self hideProgress];
            [self performSelector:@selector(startSimulation) withObject:nil afterDelay:0.5];
            return;
        }
        
        if (self.state < 3) {
            self.spinTimer = [NSTimer scheduledTimerWithTimeInterval:(0.5 + 1.0 * arc4random_uniform(1000)/1000.0) target:self selector:@selector(spin) userInfo:nil repeats:NO];
        } else {
            self.spinTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(spin) userInfo:nil repeats:NO];
        }
        
        self.state++;
    });
}

+(void)checkSimulatorSetting
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"is_simulating"]) {
        if (![LEANAppConfig sharedAppConfig].isSimulating) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"is_simulating"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    } else {
        if ([LEANAppConfig sharedAppConfig].isSimulating) {
            [[LEANSimulator sharedSimulator] stopSimulation];
        }
    }
}

-(void)stopSimulation
{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtURL:[LEANAppConfig urlForSimulatorConfig] error:nil];
    [fileManager removeItemAtURL:[LEANAppConfig urlForSimulatorIcon] error:nil];
    [fileManager removeItemAtURL:[LEANAppConfig urlForSimulatorSidebarIcon] error:nil];
    [fileManager removeItemAtURL:[LEANAppConfig urlForSimulatorNavTitleIcon] error:nil];
    
    [fileManager removeItemAtURL:[LEANSimulator tempConfigUrl] error:nil];
    [fileManager removeItemAtURL:[LEANSimulator tempIconUrl] error:nil];
    [fileManager removeItemAtURL:[LEANSimulator tempSidebarIconUrl] error:nil];
    [fileManager removeItemAtURL:[LEANSimulator tempNavigationTitleIconUrl] error:nil];
    
    [LEANSimulator reloadApplication];
    [LEANSimulator checkStatus];
}

-(void)showProgress
{
    self.progressAlert = [[UIAlertView alloc] initWithTitle:@"Simulator" message:@"Downloading your app" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles: nil];
    [self.progressAlert show];
}

- (void)hideProgress
{
    if (self.progressAlert) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressAlert dismissWithClickedButtonIndex:0 animated:NO];
            self.progressAlert.delegate = nil;
            self.progressAlert = nil;
        });
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    self.progressAlert.delegate = nil;
    self.progressAlert = nil;
    [self cancel];
}


@end
