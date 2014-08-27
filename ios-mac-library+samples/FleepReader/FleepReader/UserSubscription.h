//
//  UserSubscription.h
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Article.h"
#import "Feed.h"

@interface UserSubscription : NSManagedObject

@property (readonly) BOOL isSubscribed;

@property (nonatomic, retain) NSString * contact_id;
@property (nonatomic, retain) NSString * feed_id;
@property (nonatomic, retain) NSString * conversation_id;
@property (nonatomic, retain) NSNumber * read_message_nr;

- (void) postArticle:(Article*)article;
- (void) postBacklog:(Feed*)feed;
- (void) unsubscribe;
@end
