//
//  UserSubscription.m
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "UserSubscription.h"
#import "FLApi.h"
#import "FLApi+Actions.h"
#import "DataModel.h"

@implementation UserSubscription

@dynamic contact_id;
@dynamic feed_id;
@dynamic conversation_id;
@dynamic read_message_nr;

- (void)postArticle:(Article*)article
{
    [[FLApi api] postMessage:[article formattedArticle]
     intoConversationWithId:self.conversation_id onSuccess:nil onError:nil];
}

- (void)postBacklogFromFeed:(Feed*)feed fromArticle:(NSInteger)fromArticle
{
    if (fromArticle >= feed.articles.count) {
        return;
    }

    Article* article = feed.articles[fromArticle];
    [[FLApi api] postMessage:[article formattedArticle] intoConversationWithId:self.conversation_id
    onSuccess:^(NSInteger nr) {
        [self postBacklogFromFeed:feed fromArticle:fromArticle + 1];
    } onError:nil];
}

- (void)postBacklog:(Feed*)feed
{
    NSInteger postFrom = (feed.articles.count >= 10) ? feed.articles.count - 10 : 0;
    [self postBacklogFromFeed:feed fromArticle:postFrom];
}

- (BOOL) isSubscribed
{
    return (self.feed_id != nil) && ![self.feed_id hasPrefix:@"="];
}

- (void)unsubscribe
{
    if (self.isSubscribed) {
        Feed* f = [[DataModel dataModel] feedById:self.feed_id];
        self.feed_id = [NSString stringWithFormat:@"=%@", f.title];
    }
}

@end
