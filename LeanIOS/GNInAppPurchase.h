//
//  GNInAppPurchase.h
//  GoNativeIOS
//
//  Created by Weiyin He on 12/1/16.
//  Copyright © 2016 GoNative.io LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface GNInAppPurchase : NSObject <SKPaymentTransactionObserver>
+(instancetype)sharedInstance;
-(void)initialize;

-(void)getInAppPurchaseInfoWithBlock:(void (^)(NSDictionary *))block;
-(void)purchaseProduct:(NSString*)productId;
@end
