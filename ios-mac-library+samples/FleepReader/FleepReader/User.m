//
//  User.m
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "User.h"
#import "DataModel.h"
#import "ReaderApi.h"
#import "OPMLParser.h"
#import "FLApi+Actions.h"

@implementation User
{
    NSMutableArray* _subscriptions;
}

@dynamic contact_id;
@dynamic email;

- (void)awakeFromFetch
{
    NSFetchRequest* fr = [[NSFetchRequest alloc] initWithEntityName:@"UserSubscription"];
    NSPredicate* pred = [NSPredicate predicateWithFormat:@"contact_id=$cid"];
    pred = [pred predicateWithSubstitutionVariables:@{ @"cid" : self.contact_id}];
    [fr setPredicate:pred];
    NSArray* subscriptions = [[DataModel dataModel] executeFetchRequest:fr];
    _subscriptions = [subscriptions mutableCopy];
}

- (NSString*)loadFeedsFromOPMLFile:(NSString*)opml
{
    OPMLParser* parser = [[OPMLParser alloc] initWithData:[opml dataUsingEncoding:NSUTF8StringEncoding]];
    if (![parser parse]) {
        return parser.parserError.description;
    }

    if (!parser.isOPML) {
        return @"Not a valid OPML file";
    }

    NSInteger previousCount = 0;
    for (UserSubscription* us in _subscriptions) {
        if (!us.isSubscribed) {
            continue;
        }
        previousCount++;
        [us unsubscribe];
    }

    for (OPMLFeed* of in parser.feeds) {
        [self subscribeToUrl:of.url postResultToConversation:nil];
    }

    return [NSString stringWithFormat:@"%ld existing feeds replaced with %ld new feeds",
        previousCount, parser.feeds.count];
}

- (NSString*)feedsAsOPML
{
    NSMutableArray* feeds = [[NSMutableArray alloc] init];
    DataModel* dm = [DataModel dataModel];
    for (UserSubscription* us in _subscriptions) {
        if (!us.isSubscribed) {
            continue;
        }
        
        Feed* f = [dm feedById:us.feed_id];
        if (f.url.length == 0) {
            continue;
        }

        [feeds addObject:[[OPMLFeed alloc] initWithUrl:f.url andTitle:f.title]];
    }

    return [OPMLParser feedListToOPML:feeds];
}

- (UserSubscription*)subscriptionByTopic:(NSString*)topic
{
    NSString* topicStr = [NSString stringWithFormat:@"=%@", topic];
    return [self subscriptionByFeedId:topicStr];
}

- (UserSubscription*)subscriptionByFeedId:(NSString*)feedId
{
    for (UserSubscription* us in _subscriptions) {
        if ([us.feed_id isEqualToString:feedId]) {
            return us;
        }
    }
    return nil;
}

- (UserSubscription*)subscriptionByConversationId:(NSString*)conversationId
{
    for (UserSubscription* us in _subscriptions) {
        if ([us.conversation_id isEqualToString:conversationId]) {
            return us;
        }
    }

    UserSubscription* us = [NSEntityDescription insertNewObjectForEntityForName:@"UserSubscription"
        inManagedObjectContext:[DataModel dataModel].context];
    us.conversation_id = conversationId;
    us.contact_id = self.contact_id;
    [_subscriptions addObject:us];
    return us;
}

- (UserSubscription*)subscriptionByURL:(NSString*)url
{
   Feed* feed = [[DataModel dataModel] feedByURL:url];
   return [self subscriptionByFeedId:feed.feed_id];
 }

- (void)subscribeToFeed:(Feed*)feed
{
    UserSubscription* newSubscription = [self subscriptionByTopic:feed.title];
    if (newSubscription == nil) {
        newSubscription = [NSEntityDescription insertNewObjectForEntityForName:@"UserSubscription"
            inManagedObjectContext:[DataModel dataModel].context];
    }
    newSubscription.contact_id = self.contact_id;
    newSubscription.feed_id = feed.feed_id;
    [_subscriptions addObject:newSubscription];
    if (newSubscription.conversation_id != nil) {
        [newSubscription postBacklog:feed];
    } else {
        [[FLApi api] createConversationWithTopic:feed.title members:@[self.email] onSuccess:^(NSString *objectId) {
            newSubscription.conversation_id = objectId;
            [newSubscription postBacklog:feed];
        } onError:nil];
    }
}

- (NSString*)subscribeToUrl:(NSString*)url postResultToConversation:(NSString*)conversationId
{
    Feed* feed = [[DataModel dataModel] feedByURL:url];
    if ([self subscriptionByFeedId:feed.feed_id] != nil) {
        return [NSString stringWithFormat:@"You are already subscribed to \"%@\"", feed.title];
    }

    if (feed.status.integerValue == FeedStatusInactive) {
        feed.status = @(FeedStatusActive);
    }

    if (feed.status.integerValue == FeedStatusActive) {
        [self subscribeToFeed:feed];
        return [NSString stringWithFormat:@"Feed \"%@\" successfully subscribed", feed.title];
    }

    [feed pollWithCompletion: ^(void) {
        [self subscribeToFeed:feed];
        if (conversationId != nil) {
            [[FLApi api] postMessage:[NSString stringWithFormat:@"Feed \"%@\" successfully subscribed", feed.title] intoConversationWithId:conversationId onSuccess:nil onError:nil];
        }
    } onError: ^(NSError* error) {
        if (conversationId != nil) {
            [[FLApi api] postMessage:error.localizedDescription intoConversationWithId:conversationId onSuccess:nil onError:nil];
        }
    }];

    return @"Verifying feed, please wait...";
}

- (NSString*)unsubscribeFromConversation:(NSString*)conversation
{
    UserSubscription* sub = [self subscriptionByConversationId:conversation];

    if (!sub.isSubscribed) {
        return @"This conversation is not associated with any subscriptions";
    }

    Feed* f = [[DataModel dataModel] feedById:sub.feed_id];

    [sub unsubscribe];
    return [NSString stringWithFormat: @"You are now unsubscribed from \"%@\"", f.title];
}

- (NSInteger)activeSubscriptionCount
{
    NSInteger result = 0;
    for (UserSubscription* us in _subscriptions) {
        if (us.isSubscribed) {
            result++;
        }
    }
    return result;
}

@end
