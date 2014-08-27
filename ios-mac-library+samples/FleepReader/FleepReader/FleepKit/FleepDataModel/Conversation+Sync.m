//
//  Conversation+Sync.m
//  Fleep
//
//  Created by Erik Laansoo on 04.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "Conversation+Sync.h"
#import "FLDataModel.h"
#import "FLDataModelInternal.h"
#import "ConversationInternal.h"

@implementation Conversation (Sync)

- (FLApiRequest*)getMarkUnreadRequest
{
    return [[FLApiRequest alloc]
        initWithMethod:@"message/mark_unread/%@" methodArg:self.conversation_id arguments:
            @{ @"message_nr" : self.inbox_message_nr }];
}

- (FLApiRequest*)getHideRequest
{
    NSString* method = [NSString stringWithFormat:@"conversation/%@/%%@",
        self.hide_message_nr.integerValue > 0 ? @"hide" : @"unhide"];
    FLApiRequest* request = [[FLApiRequest alloc]
        initWithMethod:method methodArg: self.conversation_id arguments:
        @{ @"from_message_nr" : self.last_message_nr}];
    request.priority = FLApiRequestPriorityHigher;
    return request;
}

- (FLApiRequest*)getSetTopicRequest
{
    return[[FLApiRequest alloc]
        initWithMethod: @"conversation/set_topic/%@" methodArg: self.conversation_id
            arguments:@{ @"topic" : self.topic }];
}

- (FLApiRequest*)getSetAlertLevelRequest
{
    return [[FLApiRequest alloc]
        initWithMethod: @"conversation/set_alerts/%@" methodArg: self.conversation_id
            arguments: @{ @"mk_alert_level" : [FLClassificators mk_alert_level_str:self.alert_level.integerValue] } ];
}

- (FLApiRequest*)getMarkReadRequest
{
    NSInteger syncedReadMessageNr = self.read_message_nr.integerValue;
    FLApiRequest* request;
    if (NO/*self.read_message_nr.integerValue == self.last_message_nr.integerValue*/) {
        request = [[FLApiRequest alloc]
            initWithMethod:@"conversation/mark_read/%@" methodArg:self.conversation_id arguments: nil];
    } else {
        request = [[FLApiRequest alloc] initWithMethod: @"message/mark_read/%@" methodArg: self.conversation_id
            arguments:@{
                @"message_nr" : self.read_message_nr}];
    }

    request.handler = ^NSError*(FLJsonParser* json) {
        if ((self.read_message_nr.integerValue <= syncedReadMessageNr)) {
            [self setField:FLConversationFieldHorizonForward asDirty:NO];
        }
        return nil;
    };

    return request;
}

- (FLApiRequest*)getMessageSyncRequest
{
    Message* m = [[FLDataModel dataModel] uncommittedMessageInConversation:self.conversation_id];
    if (m == nil) {
        return nil;
    }

    return [m getSyncRequest];
}

- (FLApiRequest*)getSetPinOrderRequest
{
    return nil;
}

- (FLApiRequest*)getMessageLoadRequest
{
    NSDictionary* args = nil;
    BOOL syncForward = (self.fw_message_nr == nil) ||
        (self.fw_message_nr.integerValue < self.last_message_nr.integerValue);
    NSNumber* fromMessage = syncForward ? self.fw_message_nr : self.bw_message_nr;

    if (fromMessage != nil) {
        args = @{@"from_message_nr" : fromMessage};
    }

    FLApiRequest *request = [[FLApiRequest alloc]initWithMethod:
        [NSString stringWithFormat:@"conversation/%@/%@",
            syncForward ? @"sync" : @"sync_backward",
            self.conversation_id]
         arguments: args];

    request.handler = ^NSError*(FLJsonParser* json) {
        if (fromMessage != nil) {
            NSNumber* toMessage = [json extractInt:syncForward ? @"header/fw_message_nr" : @"header/bw_message_nr" defaultValue:nil];
            if (toMessage != nil) {
                NSInteger from = MIN(fromMessage.integerValue, toMessage.integerValue);
                NSInteger to = MAX(fromMessage.integerValue, toMessage.integerValue);
                NSRange range = NSMakeRange(from, to - from + 1);
                [self loadMessageCacheRange:range];
            }
        }

        return nil;
    };

    return request;
}

- (FLApiRequest*)getFileLoadRequest
{
    FLApiRequest* request = [[FLApiRequest alloc]
        initWithMethod:@"conversation/sync_files/%@" methodArg:self.conversation_id
        arguments:@{ @"from_message_nr" : self.file_horizon }];
    request.priority = FLApiRequestPriorityHigher;
    return request;
}

- (FLApiRequest*)getPinLoadRequest
{
    FLApiRequest* request = [[FLApiRequest alloc]
        initWithMethod:@"conversation/sync_pins/%@" methodArg:self.conversation_id
        arguments:@{ @"from_message_nr" : self.pin_horizon }];
    request.priority = FLApiRequestPriorityHigher;
    return request;
}

- (FLApiRequest*) getContextLoadRequestAroundMessageNr:(NSInteger)messageNr;
{
    FLApiRequest* request = [[FLApiRequest alloc]
        initWithMethod:@"conversation/sync/%@" methodArg:self.conversation_id
        arguments:@{ @"from_message_nr" : @(messageNr),
          @"mk_direction" : @"ic_flow" }];
    request.priority = FLApiRequestPriorityHigher;
    request.handler = ^NSError*(FLJsonParser* json) {
        [self loadMessageCacheRange:NSMakeRange(messageNr - 50, 100)];
        return nil;
    };
    return request;
}

- (FLApiRequest*) getFillGapRequestBefore:(BOOL)before messageNr:(NSInteger)messageNr
{
    FLApiRequest* request = [[FLApiRequest alloc]
        initWithMethod:@"conversation/sync/%@" methodArg:self.conversation_id
            arguments: @{
                @"from_message_nr" : @(messageNr),
                @"mk_direction" : before ? @"ic_backward" : @"ic_forward"
            }];

    request.handler = ^NSError*(FLJsonParser* json) {
        [self loadMessageCacheRange:NSMakeRange(messageNr - (before ? 100 : 0), 100)];
        return nil;
    };
    request.priority = FLApiRequestPriorityHigher;
    return request;
}

@end
