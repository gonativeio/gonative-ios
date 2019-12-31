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
@end

@implementation GNBackgroundAudio

-(instancetype)init
{
    self = [super init];
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:NO error:nil];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    [session setActive:YES error:nil];
    
    
    NSString* path = [[NSBundle mainBundle]
                      pathForResource:@"appbeep" ofType:@"wav"];
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

-(void)start
{
    self.keepAwake = YES;
    [self startKeepingAwake];
}

-(void)end
{
    self.keepAwake = NO;
    [self stopKeepingAwake];
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
