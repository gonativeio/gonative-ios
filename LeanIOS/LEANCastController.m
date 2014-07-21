//
//  LEANCastController.m
//  LeanIOS
//
//  Created by Weiyin He on 2/20/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANCastController.h"
#import <GoogleCast/GoogleCast.h>

@interface LEANCastController () <GCKDeviceScannerListener,GCKDeviceManagerDelegate,GCKMediaControlChannelDelegate,GCKMediaControlChannelDelegate,UIActionSheetDelegate>

@property GCKDeviceScanner *scanner;
@property GCKDevice *selectedDevice;
@property GCKDeviceManager *deviceManager;
@property NSString *sessionID;
@property GCKMediaControlChannel *mediaControlChannel;

@end

@implementation LEANCastController

bool _canCast = NO;
bool _playing = NO;
bool _paused = NO;


- (id)init
{
    self = [super init];
    
    UIImage *castImage = [UIImage imageNamed:@"cast_off"];
    UIButton *innerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [innerButton addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
    innerButton.frame = CGRectMake(0, 0, castImage.size.width, castImage.size.height);
    [innerButton setImage:castImage forState:UIControlStateNormal];
    innerButton.hidden = YES;
    self.castButton = [[UIBarButtonItem alloc] initWithCustomView:innerButton];
    
    
    self.scanner = [[GCKDeviceScanner alloc] init];
    
    return self;
}

- (void)performScan:(BOOL)start
{
    if (start) {
        [self.scanner addListener:self];
        [self.scanner startScan];
    }
    else {
        [self.scanner stopScan];
        [self.scanner removeListener:self];
    }
}

- (void)buttonPressed
{
    UIActionSheet *sheet = [[UIActionSheet alloc] init];
    sheet.delegate = self;
    
    // Choose device
    if (self.selectedDevice == nil) {
        sheet.title = @"Connect to Device";
        for (GCKDevice *device in self.scanner.devices) {
            [sheet addButtonWithTitle:device.friendlyName];
        }
    }
    else {
        sheet.title = [NSString stringWithFormat:@"Connected to %@", self.selectedDevice.friendlyName];
        
        // play: if we are either paused, or we are not playing and there is media
        if (_paused || (!_playing && self.urlToPlay) ) {
            [sheet addButtonWithTitle:@"Play"];
        }
        // pause : if we are currently playing
        if (_playing) {
            [sheet addButtonWithTitle:@"Pause"];
        }
        // stop: if paused or playing
        if (_playing || _paused) {
            [sheet addButtonWithTitle:@"Stop"];
        }
        // disconnect: if we have selected a device
        [sheet addButtonWithTitle:@"Disconnect"];
        sheet.destructiveButtonIndex = sheet.numberOfButtons - 1;
    }
    
    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
    
    [sheet showFromBarButtonItem:self.castButton animated:YES];
}

- (void)updateState
{
    // show button if there are devices
    _canCast = [self.scanner.devices count] > 0;
    self.castButton.customView.hidden = !_canCast;
    
    // change tint color to blue if connected
    if (self.deviceManager && self.deviceManager.isConnectedToApp) {
        self.castButton.customView.tintColor = [UIColor colorWithRed:0 green:122.0/255 blue:255.0/255 alpha:1];
    }
    else {
        self.castButton.customView.tintColor = nil;
    }
    
    // are we playing?
    _playing = self.deviceManager && self.deviceManager.isConnected && self.mediaControlChannel && (self.mediaControlChannel.mediaStatus.playerState == GCKMediaPlayerStatePlaying || self.mediaControlChannel.mediaStatus.playerState == GCKMediaPlayerStateBuffering);
    
    // are we paused?
    _paused = self.deviceManager && self.deviceManager.isConnected && self.mediaControlChannel && self.mediaControlChannel.mediaStatus.playerState == GCKMediaPlayerStatePaused;
}

- (void)connectToDevice
{
    if (self.selectedDevice == nil)
        return;
    
    if (![self.scanner.devices containsObject:self.selectedDevice]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error connecting" message:[NSString stringWithFormat:@"%@ is no longer available", self.selectedDevice.friendlyName] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert show];
        [self disconnect];
    }
    
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    self.deviceManager =
    [[GCKDeviceManager alloc] initWithDevice:self.selectedDevice
                           clientPackageName:[info objectForKey:@"CFBundleIdentifier"]];
    self.deviceManager.delegate = self;
    [self.deviceManager connect];
}

- (void)disconnect
{
    [self.deviceManager stopApplicationWithSessionID:self.sessionID];
    [self.deviceManager disconnect];
    self.mediaControlChannel = nil;
    self.deviceManager = nil;
    self.selectedDevice = nil;
    
    [self updateState];
}

- (void)launchApplication
{
    [self.deviceManager launchApplication:kGCKMediaDefaultReceiverApplicationID relaunchIfRunning:NO];
}

- (void)launchMedia
{
    if (self.urlToPlay) {
        if (!self.mediaControlChannel) {
            self.mediaControlChannel = [[GCKMediaControlChannel alloc] init];
            self.mediaControlChannel.delegate = self;
            [self.deviceManager addChannel:self.mediaControlChannel];
        }

        GCKMediaInformation *mediaInfo = [[GCKMediaInformation alloc] initWithContentID:[self.urlToPlay absoluteString] streamType:GCKMediaStreamTypeNone contentType:nil metadata:nil streamDuration:0 customData:nil];
        [self.mediaControlChannel loadMedia:mediaInfo autoplay:YES];
    }
}


#pragma mark UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.selectedDevice == nil) {
        if (buttonIndex < self.scanner.devices.count) {
            self.selectedDevice = self.scanner.devices[buttonIndex];
            [self connectToDevice];
        }
    }
    else {
        NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
        if ([title isEqualToString:@"Play"]) {
            if (_paused) {
                [self.mediaControlChannel play];
            }
            else {
                [self launchMedia];
                [self launchApplication];
                if (!self.deviceManager || !self.deviceManager.isConnected) {
                    [self connectToDevice];
                }
            }
        }
        else if ([title isEqualToString:@"Pause"]) {
            [self.mediaControlChannel pause];
        }
        else if ([title isEqualToString:@"Stop"]) {
            [self.mediaControlChannel stop];
        }
        else if ([title isEqualToString:@"Disconnect"]) {
            [self disconnect];
        }
    }
}


#pragma mark - GCKDeviceScannerListener
- (void)deviceDidComeOnline:(GCKDevice *)device {
    [self updateState];
}

- (void)deviceDidGoOffline:(GCKDevice *)device
{
    if (self.selectedDevice == device) {
        [self disconnect];
    }
    [self updateState];
}

#pragma mark - GCKDeviceManagerDelegate
- (void)deviceManagerDidConnect:(GCKDeviceManager *)deviceManager {
    [self launchApplication];
    [self updateState];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didConnectToCastApplication:(GCKApplicationMetadata *)applicationMetadata sessionID:(NSString *)sessionID launchedApplication:(BOOL)launchedApplication
{
    [self updateState];
    
    self.sessionID = sessionID;
    
    if (launchedApplication) {
        [self launchMedia];
    }
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didReceiveStatusForApplication:(GCKApplicationMetadata *)applicationMetadata
{
    [self updateState];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didDisconnectWithError:(NSError *)error
{
    [self updateState];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didDisconnectFromApplicationWithError:(NSError *)error
{
    [self updateState];
}

#pragma mark - GCKMediaControlChannelDelegate
- (void)mediaControlChannelDidUpdateStatus:(GCKMediaControlChannel *)mediaControlChannel
{
    [self updateState];
}

@end
