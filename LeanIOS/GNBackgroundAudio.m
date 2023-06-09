//
//  GNBackgroundAudio.m
//  GonativeIO
//
//  Created by Weiyin He on 12/30/19.
//  Copyright © 2019 GoNative.io LLC. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "GNBackgroundAudio.h"

@interface GNBackgroundAudio()
@property AVAudioPlayer *audioPlayer;
@property BOOL keepAwake;
@property BOOL isMixedSession;
@end

@implementation GNBackgroundAudio

-(instancetype)init
{
    self = [super init];
    
    NSString* path = [[NSBundle mainBundle] pathForResource:@"appbeep" ofType:@"wav"];
    NSURL* url = [NSURL fileURLWithPath:path];
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    self.audioPlayer.volume = 0;
    self.audioPlayer.numberOfLoops = -1;
    
    self.keepAwake = NO;
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)handleUrl:(NSURL *)url query:(NSDictionary*)query {
    if ([@"/start" isEqualToString:url.path]) {
        [self start];
    } else if ([@"/end" isEqualToString:url.path]) {
        [self end];
    }
}

-(void)start
{
    // Turn on mixed session
    if (!self.isMixedSession) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:NO error:nil];
        [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
        [session setActive:YES error:nil];
        self.isMixedSession = YES;
    }
    
    self.keepAwake = YES;
    [self startKeepingAwake];
}

-(void)end
{
    self.keepAwake = NO;
    [self stopKeepingAwake];
    
    // Turn off mixed session
    if (self.isMixedSession) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:NO error:nil];
        [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
        self.isMixedSession = NO;
    }
}

-(void)startKeepingAwake
{
    if (!self.keepAwake) return;
    [self.audioPlayer play];
}

-(void)stopKeepingAwake
{
    [self.audioPlayer pause];
}

@end
