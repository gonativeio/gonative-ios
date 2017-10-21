//
//  GNSubscriptionsModel.m
//  GonativeIO
//
//  Created by Weiyin He on 10/20/17.
//  Copyright © 2017 GoNative.io LLC. All rights reserved.
//

#import "GNSubscriptionsModel.h"

@implementation GNSubscriptionsModel

+(GNSubscriptionsModel*)modelWithJSONData:(NSData*)data
{
    NSDictionary *parsedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!parsedJSON) {
        return nil;
    }
    
    GNSubscriptionsModel *model = [[GNSubscriptionsModel alloc] init];
    NSMutableArray *sections = [NSMutableArray array];
    model.sections = sections;
    
    NSArray *parsedSections = parsedJSON[@"sections"];
    if ([parsedSections isKindOfClass:[NSArray class]]) {
        for (NSDictionary *parsedSection in parsedSections) {
            if ([parsedSection isKindOfClass:[NSDictionary class]]) {
                GNSubscriptionsSection *section = [[GNSubscriptionsSection alloc] init];
                section.name = parsedSection[@"name"];
                NSMutableArray *items = [NSMutableArray array];
                section.items = items;
                
                NSArray *parsedItems = parsedSection[@"items"];
                if ([parsedItems isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *parsedItem in parsedItems) {
                        GNSubscriptionItem *item = [[GNSubscriptionItem alloc] init];
                        item.identifier = parsedItem[@"identifier"];
                        item.name = parsedItem[@"name"];
                        item.isSubscribed = NO;
                        [items addObject:item];
                    }
                }
                
                [sections addObject:section];
            }
        }
    }
    
    return model;
}
@end

@implementation GNSubscriptionsSection
@end

@implementation GNSubscriptionItem
@end
