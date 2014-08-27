//
//  Feed.h
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "FLUtils.h"
#import "FeedRequest.h"

@interface FeedError : NSError
- (id)initWithMessage:(NSString*)message;
@end

typedef NS_ENUM(NSInteger, FeedStatus) {
    FeedStatusUnconfirmed = 1,
    FeedStatusActive = 2,
    FeedStatusInvalid = 3,
    FeedStatusInactive = 4
};

@interface Feed : NSManagedObject <FeedRequestDelegate>
@property NSError* error;
@property (readonly) NSArray* articles;

@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSDate * last_checked;
@property (nonatomic, retain) NSString * feed_id;
@property (nonatomic, retain) NSNumber * update_interval;
@property (nonatomic, retain) NSNumber * failure_count;
@property (nonatomic, retain) NSNumber * status;

- (void) pollWithCompletion:(FLCompletionHandler)completion onError:(FLErrorHandler)onError;
- (void) poll;
- (NSInteger) unsubscribeAll;
@end
