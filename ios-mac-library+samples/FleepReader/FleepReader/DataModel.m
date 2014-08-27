//
//  DataModel.m
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "DataModel.h"
#import "FLApi.h"
#import "FLApiInternal.h"
#import "FLUtils.h"

DataModel* _dataModel = nil;

@implementation DataModel
{
    NSManagedObjectModel* _model;
    NSManagedObjectContext* _context;

    NSMutableDictionary* _feeds;
    NSMutableDictionary* _users;

    NSInteger _nextFeedToPoll;
    NSTimer* _pollTimer;
}

- (id)init
{
    if (self = [super init]) {
        [self initContext];
        _dataModel = self;

        _feeds = [[NSMutableDictionary alloc] init];
        NSFetchRequest* fr = [[NSFetchRequest alloc] initWithEntityName:@"Feed"];
        NSArray* feeds = [[DataModel dataModel] executeFetchRequest:fr];
        for (Feed* f in feeds) {
            _feeds[f.feed_id] = f;
        }

        _users = [[NSMutableDictionary alloc] init];
        fr = [[NSFetchRequest alloc] initWithEntityName:@"User"];
        NSArray* users = [[DataModel dataModel] executeFetchRequest:fr];
        for (User* u in users) {
            _users[u.contact_id] = u;
        }
    }
    return self;
}

+ (DataModel*) dataModel
{
    return _dataModel;
}

- (void)initContext
{
    if (_model == nil) {
        NSString *path = @"FleepReader";
        path = [path stringByDeletingPathExtension];
        NSURL *modelURL = [NSURL fileURLWithPath:[path stringByAppendingPathExtension:@"momd"]];
        _model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];

        assert(_model != nil);
    }

    _context = [[NSManagedObjectContext alloc] init];

    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];
    [_context setPersistentStoreCoordinator:coordinator];
        
    NSString *STORE_TYPE = NSSQLiteStoreType;
        
    NSString *path = [[NSProcessInfo processInfo] arguments][0];
    path = [path stringByDeletingPathExtension];
    path = [path stringByAppendingPathExtension:@"sqlite"];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSFileManager* fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:path]) {
        [FLApi api].eventHorizon = 0;
    }
    
    NSError *error;
    NSPersistentStore *newStore = [coordinator addPersistentStoreWithType:STORE_TYPE configuration:nil URL:url options:nil error:&error];
        
    if (newStore == nil) {
        NSLog(@"Error initializing datastore: %@", error);
        [FLApi api].eventHorizon = 0;
        [fm removeItemAtPath:path error:nil];
        newStore = [coordinator addPersistentStoreWithType:STORE_TYPE configuration:nil URL:url options:nil error:&error];
        if (newStore == nil) {
            NSLog(@"FATAL: %@", error);
            exit(1);
        }
    }
}

- (void)saveContext
{
    NSError* error = nil;
    [_context save:&error];
    if (error != nil) {
        NSLog(@"Warning: Save failed: %@", error);
    }
}

- (NSManagedObjectContext*)context
{
    return _context;
}

- (Feed*)feedById:(NSString *)feedId
{
    return _feeds[feedId];
}

- (Feed*)feedByURL:(NSString *)feedUrl
{
    __block Feed* result = nil;
    [_feeds enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        Feed* f = obj;
        if ([f.url isEqualToString:feedUrl]) {
            result = f;
            *stop = YES;
        }
    }];

    if (result != nil) {
        return result;
    }

    Feed* newFeed = [NSEntityDescription insertNewObjectForEntityForName:@"Feed"
        inManagedObjectContext:[DataModel dataModel].context];

    newFeed.feed_id = [FleepUtils generateUUID];
    newFeed.url = feedUrl;
    newFeed.status = [NSNumber numberWithInteger:FeedStatusUnconfirmed];
    newFeed.update_interval = [NSNumber numberWithInteger:SECONDS_IN_HOUR * 3];
    newFeed.last_checked = [NSDate dateWithTimeIntervalSinceReferenceDate:0.0f];
    _feeds[newFeed.feed_id] = newFeed;
    [newFeed awakeFromFetch];
    return newFeed;
}

- (void)pollFeeds
{
    if ([FLApi api].eventHorizon <= 0) {
        return;
    }
    
    if (_feeds.count == 0) {
        return;
    }
    
    NSArray* allFeeds = _feeds.allValues;
    if (_nextFeedToPoll < allFeeds.count) {
        Feed* f = allFeeds[_nextFeedToPoll];
        [f poll];
    }
    _nextFeedToPoll = (_nextFeedToPoll + 1) % allFeeds.count;
    if (_nextFeedToPoll == 0) {
        [self setPollInterval:60.0f];
    }
    [self saveContext];
}

- (void)forcePoll
{
    for (Feed* f in _feeds.allValues) {
        f.last_checked = [NSDate dateWithTimeIntervalSinceReferenceDate:0.0f];
    }
    _nextFeedToPoll = 0;
    [self setPollInterval:10.0f];
}

- (User*)userById:(NSString *)contactId
{
    User* result = _users[contactId];
    if (result == nil) {
        result = [NSEntityDescription insertNewObjectForEntityForName:@"User"
            inManagedObjectContext:[DataModel dataModel].context];
        result.contact_id = contactId;
        [result awakeFromFetch];
        _users[contactId] = result;
    }

    return result;
}

- (NSArray*)executeFetchRequest:(NSFetchRequest*)request
{
    NSError* error;
    NSArray* result = [_context executeFetchRequest:request error:&error];
    if (error != nil) {
        FLLogError(@"ExecuteFetchRequest: %@", error);
    }
    return result;
}

- (NSString*)forgetFeed:(NSString*)feedURL
{
    Feed* f = [self feedByURL:feedURL];
    if (f == nil) {
        return [NSString stringWithFormat: @"No feed with URL \"%@\"", feedURL];
    }

    NSInteger subCount = [f unsubscribeAll];
    
    NSFetchRequest* fr = [[NSFetchRequest alloc] initWithEntityName:@"Article"];
    NSPredicate* pred = [NSPredicate predicateWithFormat:@"feed_id=$fid"];
    pred = [pred predicateWithSubstitutionVariables:@{ @"fid" : f.feed_id}];
    [fr setPredicate:pred];
    NSArray* articles = [[[DataModel dataModel] executeFetchRequest:fr] mutableCopy];
    for (Article* a in articles) {
        [_context deleteObject:a];
    }
    NSString* response = [NSString stringWithFormat:@"%ld subscribers unsubscribed, %ld articles deleted",
        (long)subCount, (long)articles.count];
    FLLogInfo(@"\"%@\"%@", f.title, response);
    [_feeds removeObjectForKey:f.feed_id];
    [_context deleteObject:f];
    [self saveContext];
    return response;
}

- (void)setPollInterval:(NSTimeInterval)interval
{
    if (_pollTimer != nil) {
        [_pollTimer invalidate];
    }
    _pollTimer = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(pollFeeds) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_pollTimer forMode:NSDefaultRunLoopMode];
}

- (NSString*)subscripionStats
{
    NSMutableString* result = [[NSMutableString alloc] init];
    [result appendString:@":::\n"];
    for (User* u in _users.allValues) {
        NSString* e = [u.email stringByPaddingToLength:40 withString:@" " startingAtIndex:0];
        NSString* sc = [[NSString stringWithFormat:@"%ld", (long)u.activeSubscriptionCount]
            stringByPaddingToLength:5 withString:@" " startingAtIndex:0];
        [result appendFormat:@"|%@|%@|\n", e, sc];
    }
    return result;
}

@end
