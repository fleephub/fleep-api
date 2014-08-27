//
//  Feed.m
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "Feed.h"
#import "DataModel.h"
#import "RSSParser.h"
#import "FLUtils.h"

@implementation FeedError
- (id)initWithMessage:(NSString*)message
{
    return [super initWithDomain:@"FleepReader" code:-1 userInfo: @{ @"message" : message}];
}

- (NSString*)localizedDescription
{
    return self.userInfo[@"message"];
}

@end

@implementation Feed
{
    FeedStatus _status;
    NSError* _error;
    NSMutableArray* _articles;
    FLCompletionHandler _pollCompletion;
    FLErrorHandler _pollError;
    FeedRequest* _request;
}

@synthesize error = _error;
@synthesize articles = _articles;

@dynamic title;
@dynamic url;
@dynamic last_checked;
@dynamic feed_id;
@dynamic update_interval;
@dynamic failure_count;
@dynamic status;

- (Article*)handleItem:(RSSItem*)item
{
    for (Article* a in _articles) {
        if ([a.guid isEqualToString:item.guid]) {
            return nil;
        }
    }

    Article* article = [NSEntityDescription insertNewObjectForEntityForName:@"Article"
        inManagedObjectContext:[DataModel dataModel].context];

    NSInteger articleNr = ((Article*)_articles.lastObject).article_nr.integerValue;

    article.feed_id = self.feed_id;
    article.article_nr = [NSNumber numberWithInteger:articleNr + 1];
    [article setFromRSSItem:item];
    [_articles addObject:article];
    if (_articles.count > 100) {
        [_articles removeObjectAtIndex:0];
    }
    return article;
}

- (NSArray*)loadSubscriptions
{
    NSFetchRequest* fr = [[NSFetchRequest alloc] initWithEntityName:@"UserSubscription"];
    NSPredicate* pred = [NSPredicate predicateWithFormat:@"feed_id=$fid"];
    pred = [pred predicateWithSubstitutionVariables:@{ @"fid" : self.feed_id}];
    [fr setPredicate:pred];
    return [[DataModel dataModel].context executeFetchRequest:fr error:nil];
}

- (NSInteger)unsubscribeAll
{
    NSArray* subscriptions = [self loadSubscriptions];
    for (UserSubscription* us in subscriptions) {
        User* user = [[DataModel dataModel] userById:us.contact_id];
        [user unsubscribeFromConversation:us.conversation_id];
    }
    return subscriptions.count;
}

- (void)processRSS:(RSSParser*)rss
{
    NSString* feedType = (rss.type == FeedTypeAtom) ? @"atom" : @"rss";
    FLLogInfo(@"Received %ld articles in %@ feed \"%@\"", (long)rss.items.count, feedType, self.title);

    NSArray* subscriptions = nil;
    
    for (NSInteger i = MIN(99, rss.items.count - 1); i >= 0; i--) {
        RSSItem* item = rss.items[i];
        
        Article* a = [self handleItem:item];
        if (a == nil) {
            continue;
        }

        if (subscriptions == nil) {
            subscriptions = [self loadSubscriptions];
        }

        if (subscriptions.count == 0) {
            continue;
        }
        FLLogInfo(@"Posting new article \"%@\" to %ld subscribers", a.title, (long)subscriptions.count);
        for (UserSubscription* u in subscriptions) {
            [u postArticle:a];
        }
    }
}

- (void)awakeFromFetch
{
    if (_articles == nil) {
        NSFetchRequest* fr = [[NSFetchRequest alloc] initWithEntityName:@"Article"];
        NSPredicate* pred = [NSPredicate predicateWithFormat:@"feed_id=$fid"];
        pred = [pred predicateWithSubstitutionVariables:@{ @"fid" : self.feed_id}];
        [fr setPredicate:pred];
        _articles = [[[DataModel dataModel] executeFetchRequest:fr] mutableCopy];
        [_articles sortUsingComparator:^NSComparisonResult(Article* obj1, Article* obj2) {
            return [obj1.article_nr compare:obj2.article_nr];
        }];

        while (_articles.count > 100) {
            [_articles removeObjectAtIndex:0];
        }
    }
}

- (void)poll
{
    if (self.status.integerValue != FeedStatusActive) {
        return;
    }

    NSTimeInterval lastCheckInterval = 0.0f;
    if (self.last_checked != nil) {
        lastCheckInterval = -[self.last_checked timeIntervalSinceNow];
    }

    if ((self.last_checked == nil) || (lastCheckInterval > self.update_interval.integerValue)) {
        [self pollWithCompletion:nil onError:nil];
    }
}

- (void)pollWithCompletion:(FLCompletionHandler)completion onError:(FLErrorHandler)onError
{
    if (completion != nil) {
        if (_pollCompletion == nil) {
            _pollCompletion = completion;
        } else {
            FLCompletionHandler oldPollCompletion = _pollCompletion;
            _pollCompletion = ^(void) {
                completion();
                oldPollCompletion();
            };
        }
    }

    if (onError != nil) {
        if (_pollError == nil) {
            _pollError = onError;
        } else {
            FLErrorHandler oldError = _pollError;
            _pollError = ^(NSError* error) {
                onError(error);
                oldError(error);
            };
        }
    }

    if (_request == nil) {
        _request = [[FeedRequest alloc] initWithURL:self.url delegate:self];
        self.last_checked = [NSDate date];
    }
}

- (void)feedRequestCompletedWithResult:(RSSParser *)result
{
    self.failure_count = [NSNumber numberWithInteger:0];
    _error = nil;
    _status = FeedStatusActive;
    if (self.title.length == 0) {
        self.title = result.title;
    }

    [self processRSS:result];

    if (_pollCompletion != nil) {
        _pollCompletion();
    }

    _pollCompletion = nil;
    _pollError = nil;
    _request = nil;
}

- (void)feedRequestFailedWithError:(NSError *)error
{
    self.failure_count = [NSNumber numberWithInteger:self.failure_count.integerValue + 1];
    _error = error;

    FLLogError(@"Request <%@> failed with error: %@", self.url, error);

    if (self.status.integerValue == FeedStatusUnconfirmed) {
        self.status = [NSNumber numberWithInteger:FeedStatusInvalid];
    }

    if (self.failure_count.integerValue > 5) {
        self.status = [NSNumber numberWithInteger:FeedStatusInvalid];
        [self unsubscribeAll];
    }
    
    if (_pollError != nil) {
        _pollError(error);
    }

    _pollCompletion = nil;
    _pollError = nil;
    _request = nil;
}

@end
