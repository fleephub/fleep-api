//
//  Conversation+Actions.m
//  Fleep
//
//  Created by Erik Laansoo on 09.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLDataModel.h"
#import "FLDataModelInternal.h"
#import "ConversationInternal.h"
#import "FLApi.h"
#import "FLApi+Actions.h"
#import "FLConversationLists.h"

@implementation Conversation (Actions)

- (void)markRead
{
    Message* lm = [[FLDataModel dataModel] messageFromId:self.conversation_id atInboxIndex:self.last_inbox_nr.integerValue];
    [self markReadUntil:lm.message_nr.integerValue];
}

- (void)markUnread
{
    if (self.isUnread) {
        return;
    }

    [self markUnreadUntil:self.inbox_message_nr.integerValue];
}

- (void)setReadMessageNr:(NSInteger)readMessageNr
{
    if (readMessageNr < self.join_message_nr.integerValue) {
        return;
    }

    if (readMessageNr > self.last_message_nr.integerValue) {
        return;
    }

    Message* m = [self messageByNumber:readMessageNr];
    if (m == nil) {
        return;
    }

    self.read_message_nr = [NSNumber numberWithInteger:readMessageNr];
    NSInteger inboxMessageNr = MIN(self.last_inbox_nr.integerValue, labs(m.inbox_nr.integerValue) + 1);
    Message* newInboxMessage = [[FLDataModel dataModel]messageFromId:self.conversation_id atInboxIndex:inboxMessageNr];
    if (newInboxMessage != nil) {
        [self setInboxMessageNr:newInboxMessage.message_nr.integerValue];
    }
    [self updateUnreadCount];
    [self notifyPropertyChanges];
}

- (void)markReadUntil:(NSInteger)readMessageNr
{
    if ((readMessageNr <= self.readMessageNumber) || (readMessageNr > self.last_message_nr.integerValue))  {
        return;
    }

    [self setField:FLConversationFieldHorizonBack asDirty:NO];
    [self setField:FLConversationFieldHorizonForward asDirty:YES];

    [self setReadMessageNr:readMessageNr];

}

- (void)markUnreadUntil:(NSInteger)unreadMessageNr;
{
    Message* prevMessage = [self nextMessageFromNr:unreadMessageNr
        direction:-1];

    if (prevMessage.message_nr.integerValue >= self.readMessageNumber) {
        return;
    }

    [self setField:FLConversationFieldHorizonBack asDirty:YES];
    [self setField:FLConversationFieldHorizonForward asDirty:NO];

    [self setReadMessageNr:prevMessage.message_nr.integerValue];
}

- (void)unpin
{
    self.pin_weight = nil;
    [[FLDataModel dataModel] conversationChanged:self];
}

- (void)pinAfter:(Conversation*)otherConversation
{
    if (otherConversation == self) {
        return;
    }

    Conversation* prev = otherConversation;
    Conversation* next = nil;
    double lastWeight = 200.0f;
    FLSortedArray* pinnedList = [FLConversationLists conversationLists].pinnedList;

    if (pinnedList.count > 0) {
        lastWeight = ((Conversation*)pinnedList.lastObject).pin_weight.doubleValue;
    };

    NSInteger nextIndex = 0;
    if (otherConversation != nil) {
        nextIndex = [pinnedList indexOfObject:otherConversation];
        if (nextIndex == NSNotFound) {
            prev = nil;
            nextIndex = 0;
        } else {
            nextIndex++;
        }
    }

    if ((nextIndex >= 0) && (nextIndex < pinnedList.count)) {
        next = pinnedList[nextIndex];
    }

    double prevWeight = (prev != nil) ? prev.pin_weight.doubleValue : 0.0f;
    double nextWeight = (next != nil) ? next.pin_weight.doubleValue : lastWeight + 10.0f;

    self.pin_weight = [NSNumber numberWithDouble:(prevWeight + nextWeight) / 2];
    FLLogInfo(@"%@: NewPinWeight = %@", self.shortTopicText, self.pin_weight);
    [[FLDataModel dataModel]conversationChanged:self];
}

- (void)removeMembers:(NSArray*)emails onSuccess:(FLCompletionHandler)onSuccess
    onError:(FLErrorHandler)onError
{
    if (self.isNewConversation) {
        for (NSString* email in emails) {
            [self.sortedMembers revokeAdd:email];
        }

        return;
    }

    [[FLApi api]removeMembers:emails
        fromConversationWithId:self.conversation_id
        onSuccess:onSuccess onError:onError];
}

- (void)leave
{
    [[FLApi api]leaveConversationWithId:self.conversation_id];
}

- (void)changeTopic:(NSString*)topic
{
    if ([topic isEqualToString:self.topic]) {
        return;
    }
    self.topic = topic;
    [self updateTopicNotifyImmediately:YES];
    if (![self.conversation_id isEqualToString:NEW_CONVERSATION_ID]) {
        [self setField:FLConversationFieldTopic asDirty:YES];
    }
    if (self.isNewConversation) {
        [self willChangeValueForKey:@"topicText"];
        [self awakeFromFetch];
        [self didChangeValueForKey:@"topicText"];
    }
}

- (void)changeAlertLevel:(NSInteger)newAlertLevel
{
    if (self.alert_level.integerValue == newAlertLevel) {
        return;
    }

    self.alert_level = [NSNumber numberWithInteger:newAlertLevel];
    [self setField:FLConversationFieldAlertLevel asDirty:YES];
}

- (void)archive
{
    if (self.isHidden) {
        return;
    }
    
    [self willChangeValueForKey:@"isHidden"];
    self.hide_message_nr = self.last_message_nr;
    [self setField:FLConversationFieldHide asDirty:YES];
    [self didChangeValueForKey:@"isHidden"];
}

- (void)unarchive
{
    if (!self.isHidden) {
        return;
    }
    
    [self willChangeValueForKey:@"isHidden"];
    self.hide_message_nr = [NSNumber numberWithInteger:0];
    [self setField:FLConversationFieldHide asDirty:YES];
    [self didChangeValueForKey:@"isHidden"];
}

- (void)postMessage:(NSString*) message andFiles:(NSArray*)fileList
    onSuccess:(FLCompletionHandlerWithNr)onSuccess onError:(FLErrorHandler)onError
{
    if (self.isNewConversation) {
        [[FLApi api] createConversationWithTopic:self.topic members:[self.sortedMembers addedMembers]
            onSuccess: ^(NSString *objectId) {
                [self postMessage:message andFiles:fileList onSuccess:onSuccess onError:onError];
            }
            onError:onError];
    } else {
        [[FLApi api] postMessage:message andFiles:fileList intoConversationWithId:self.conversation_id
            onSuccess:onSuccess onError:onError];
    }
}

@end
