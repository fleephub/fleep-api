//
//  DataModel.h
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "User.h"
#import "UserSubscription.h"
#import "Article.h"
#import "Feed.h"

@interface DataModel : NSObject
@property (readonly) NSManagedObjectContext* context;

+ (DataModel*)dataModel;
- (void)saveContext;

- (Feed*)feedById:(NSString*)feedId;
- (Feed*)feedByURL:(NSString*)feedUrl;
- (void)pollFeeds;
- (void)forcePoll;
- (User*)userById:(NSString*)contactId;
- (NSArray*)executeFetchRequest:(NSFetchRequest*)request;
- (NSString*)forgetFeed:(NSString*)feedURL;
- (void)setPollInterval:(NSTimeInterval)interval;
- (NSString*)subscripionStats;
@end
