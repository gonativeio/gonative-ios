//
//  GNRegistrationService.h
//  GoNativeIOS
//
//  Created by Weiyin He on 10/3/15.
//  Copyright © 2015 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GNRegistrationManager : NSObject
+(instancetype)sharedManager;
-(void)processConfig:(NSArray*)endpoints;
-(void)checkUrl:(NSURL*)url;
-(void)setOneSignalUserId:(NSString *)userId pushToken:(NSString*)pushToken subscribed:(BOOL)subscribed;
-(void)setCustomData:(NSDictionary*)data;
-(void)sendToAllEndpoints;
@end
