//
//  GNSubscriptionsModel.h
//  GonativeIO
//
//  Created by Weiyin He on 10/20/17.
//  Copyright © 2017 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GNSubscriptionItem : NSObject
@property NSString *identifier;
@property NSString *name;
@property BOOL isSubscribed;
@end

@interface GNSubscriptionsSection : NSObject
@property NSString *name;
@property NSArray<GNSubscriptionItem*> *items;
@end

@interface GNSubscriptionsModel : NSObject
@property NSArray<GNSubscriptionsSection*> *sections;

+(GNSubscriptionsModel*)modelWithJSONData:(NSData*)data;

@end
