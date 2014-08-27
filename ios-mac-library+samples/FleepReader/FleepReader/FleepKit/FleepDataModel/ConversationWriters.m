//
//  ConversationWriters.m
//  Fleep
//
//  Created by Erik Laansoo on 25.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "ConversationWriters.h"
#import "FLDataModel.h"
#import "FLDataModelInternal.h"
#import "ConversationInternal.h"
#import "FLApi.h"
#import "FLApiInternal.h"

const NSTimeInterval WRITING_TIMEOUT = SECONDS_IN_MINUTE;

@implementation ConversationWriters
{
    __weak Conversation* _conversation;
    NSMutableDictionary* _writers;
    NSMutableDictionary* _lockedMessages;

    BOOL _writing;
    NSInteger _editMessageNr;
    NSTimer* _purgeWritersTimer;
}

- (id)initWithConversation:(Conversation *)conversation
{
    if (self = [super init]) {
        _conversation = conversation;
    }
    return self;
}

- (NSInteger)count
{
    if (_writers == nil) {
        return 0;
    }
    return _writers.count;
}

- (void)endWritingBy:(NSString*)accountId
{
    [_writers removeObjectForKey:accountId];
    __block NSNumber* lockedMessage = nil;
    [_lockedMessages enumerateKeysAndObjectsUsingBlock:^(NSNumber* key, NSString* obj, BOOL *stop) {
        if ([obj isEqualToString:accountId]) {
            lockedMessage = key;
            *stop = YES;
        }
    }];

    if (lockedMessage != nil) {
        [_lockedMessages removeObjectForKey:lockedMessage];
    }
}

- (void)purgeExpiredWriters
{
    if (_writers == nil) {
        return;
    }

    BOOL changed = NO;
    NSArray* keys = [_writers.allKeys copy];
    for (NSString* key in keys) {
        NSDate* d = _writers[key];
        if ([d timeIntervalSinceNow] < -WRITING_TIMEOUT) {
            [self endWritingBy:key];
            changed = YES;
        }
    }

    if (_writers.count == 0) {
        _writers = nil;
    }

    if ((_writers == nil) && !_writing) {
        [_conversation resetWriters];
    }

    if (changed) {
        [_conversation willChangeValueForKey:@"writers"];
        [_conversation didChangeValueForKey:@"writers"];
    }
}

- (NSArray*)nameList
{
    if (_writers == nil) {
        return nil;
    }

    NSArray* names = [_writers.allKeys arrayByMappingObjectsUsingBlock:^id(NSString* obj) {
        return [[FLDataModel dataModel] fullNameOfContact:obj];
    }];

    return names;
}

- (NSString*)userEditingMessageNr:(NSInteger)messageNr
{
    if (_lockedMessages == nil) {
        return nil;
    }

    return _lockedMessages[@(messageNr)];
}

- (void)tryPurgeWriters
{
    [self purgeExpiredWriters];
    if (_writers == nil) {
        [_purgeWritersTimer invalidate];
        _purgeWritersTimer = nil;
    }
}

- (void)updateActivityBy:(NSString*)accountId writing:(BOOL)writing
    messageNr:(NSInteger)messageNr
{
    if (![[FLUserProfile userProfile] isSelf:accountId]) {
        BOOL wasWriting = _writers[accountId] != nil;
        if (writing != wasWriting) {
            [_conversation willChangeProperty:@"writers"];
            [[FLDataModel dataModel] conversationChanged:_conversation];
            if (writing) {
                if (_writers == nil) {
                    _writers = [[NSMutableDictionary alloc] init];
                }
            } else {
                [self endWritingBy:accountId];
            }
        }

        if (writing) {
            _writers[accountId] = [NSDate date];
        } else {
            [self purgeExpiredWriters];
        }
    }

    if ((_writers != nil) && (_purgeWritersTimer == nil)) {
        _purgeWritersTimer = [NSTimer timerWithTimeInterval:10.0f target:self
            selector:@selector(tryPurgeWriters) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_purgeWritersTimer forMode:NSDefaultRunLoopMode];
    }

    if (messageNr != 0) {
        [[FLDataModel dataModel] conversationChanged:_conversation];
        if (writing) {
            if (_lockedMessages == nil) {
                _lockedMessages = [[NSMutableDictionary alloc] init];
            }

            _lockedMessages[@(messageNr)] = accountId;
        } else {
            [_lockedMessages removeObjectForKey:@(messageNr)];
            if (_lockedMessages.count == 0) {
                _lockedMessages = nil;
            }
        }

        if (_conversation.messages != nil) {
            Message* m = [_conversation.messages messageByNr:messageNr];
            if (m != nil) {
                [m willChangeValueForKey:@"lockAccountId"];
                [m didChangeValueForKey:@"lockAccountId"];
                if (m.isPinned) {
                    [_conversation willChangeProperty:@"pinnedMessages"];
                }
            }
        }
    }
}

- (void)setWritingStatus:(BOOL)writing messageNr:(NSInteger)messageNr
{
    if ((writing == _writing) && (_editMessageNr == messageNr)) {
        return;
    }

    _writing = writing;
    _editMessageNr = messageNr;

    if (!_writing) {
        [self purgeExpiredWriters];
    }

    if (_conversation.can_post.boolValue) {
        NSDictionary* activity = messageNr > 0 ?
            @{ @"is_writing": [NSNumber numberWithBool:writing], @"message_nr" : @(messageNr) } :
            @{ @"is_writing" : [NSNumber numberWithBool:writing] };

        [[FLApi api] queueRequest:[[FLApiRequest alloc] initWithMethod:@"conversation/show_activity/%@"
            methodArg:_conversation.conversation_id arguments:activity] name:[NSString stringWithFormat: @"show_activity_%@", _conversation.conversation_id]];
    }
}

- (void)dealloc
{
    if (_purgeWritersTimer != nil) {
        [_purgeWritersTimer invalidate];
        _purgeWritersTimer = nil;
    }
}

@end
