//
//  User.h
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "UserSubscription.h"

@interface User : NSManagedObject

@property (nonatomic, retain) NSString * contact_id;
@property (nonatomic, retain) NSString * email;
@property (readonly) NSInteger activeSubscriptionCount;

- (NSString*)loadFeedsFromOPMLFile:(NSString*)opml;
- (NSString*)feedsAsOPML;
- (NSString*)subscribeToUrl:(NSString*)url postResultToConversation:(NSString*)conversationId;
- (NSString*)unsubscribeFromConversation:(NSString*)conversation;
- (UserSubscription*)subscriptionByConversationId:(NSString*)conversationId;
- (UserSubscription*)subscriptionByURL:(NSString*)url;

@end
