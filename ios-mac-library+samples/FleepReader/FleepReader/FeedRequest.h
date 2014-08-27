//
//  FeedRequest.h
//  FleepReader
//
//  Created by Erik Laansoo on 07.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSSParser.h"

@protocol FeedRequestDelegate <NSObject>

- (void)feedRequestCompletedWithResult:(RSSParser*)result;
- (void)feedRequestFailedWithError:(NSError*)error;

@end

@interface FeedRequest : NSObject <NSURLConnectionDataDelegate>
- (id)initWithURL:(NSString*)url delegate:(id<FeedRequestDelegate>)delegate;

@end
