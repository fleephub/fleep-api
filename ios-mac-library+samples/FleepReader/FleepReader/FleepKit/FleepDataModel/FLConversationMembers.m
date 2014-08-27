//
//  FLConversationMembers.m
//  Fleep
//
//  Created by Erik Laansoo on 09.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLConversationMembers.h"
#import "FLDataModel.h"
#import "ConversationInternal.h"
#import "FLApi.h"
#import "FLApi+Actions.h"
#import "FLUserProfile.h"

@implementation FLConversationMembers
{
    NSMutableArray* _members;
    __weak Conversation* _conversation;
}

@synthesize asArray = _members;

- (id)initWithConversation:(Conversation*)conversation
{
    if (self = [super init]) {
        _conversation = conversation;
        _members = [[NSMutableArray alloc] init];
        [self refreshAndNotify:NO];
    }

    return self;
}

- (NSArray*)nameList
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    FLUserProfile* up = [FLUserProfile userProfile];
    for (FLMember* m in _members) {
        if (![up isSelf:m.accountId]) {
            [result addObject:m.displayName];
        }
    }
    return result;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len
{
    return [_members countByEnumeratingWithState:state objects:stackbuf count:len];
}

- (FLMember*)memberByAccountId:(NSString*)accountId
{
    for (FLMember* m in _members) {
        if ([m.accountId isEqualToString:accountId]) {
            return m;
        }
    }
    return nil;
}

- (FLMember*)memberByEmail:(NSString *)email
{
    for (FLMember* m in _members) {
        if ((m.email != nil) && ([m.email compare:email options:NSCaseInsensitiveSearch] == NSOrderedSame)) {
            return m;
        }
    }
    return nil;
}

- (BOOL)containsEmail:(NSString *)email
{
    return [self memberByEmail:email] != nil;
}

- (BOOL)containsId:(NSString *)accountId
{
    return [self memberByAccountId:accountId] != nil;
}

- (void)refreshAndNotify:(BOOL)notify
{
    BOOL changed = NO;

    NSMutableSet* removed = [[NSMutableSet alloc] init];

    for (FLMember* m in _members) {
        if (!m.isAdded) {
            [removed addObject:m];
        }
    }
    
    for (Member* m in _conversation.members.allObjects) {
        FLMember* sm = [self memberByAccountId:m.account_id];


        if (sm == nil) {
            Contact* c = [[FLDataModel dataModel] contactFromId:m.account_id];
            if ((c != nil) && (c.email != nil)) {
                sm = [self memberByEmail:c.email];
                if ((sm != nil) && sm.isAdded) {
                    [removed addObject:sm];
                    sm = nil;
                }
            }
        }


        if (sm != nil) {
            [removed removeObject:sm];
            sm.isAdded = NO;
        } else {
            [_members addObject:[[FLMember alloc] initWithMember:m]];
            changed = YES;
        }
    }

    for (FLMember* m in removed.allObjects) {
        changed = YES;
        [_members removeObject:m];
    }
    
    if (changed) {
        if (notify) {
            [_conversation willChangeProperties:@[@"sortedMembers"]];
        }
        [_members sortUsingComparator:^NSComparisonResult(FLMember* obj1, FLMember* obj2) {
            return [obj1 compareWith:obj2];
        }];
    }
}

- (NSArray*)addedMembers
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    for (FLMember* m in _members) {
        if (m.isAdded && !m.isLocalContact) {
            [result addObject:m.email];
        }
    }
    return result;
}

- (NSInteger)count
{
    return _members.count;
}

- (NSInteger)countWithoutSelf
{
    return _members.count -
        (([self containsId:[FLUserProfile userProfile].contactId]) ? 1 : 0);
}

- (void)revokeAdd:(NSString *)email
{
    for (NSInteger i = 0; i < _members.count; i++) {
        FLMember* m = _members[i];
        if (m.isAdded && [m.email isEqualToString:email]) {
            [_conversation willChangeValueForKey:@"sortedMembers"];
            [_members removeObjectAtIndex:i];
            [_conversation didChangeValueForKey:@"sortedMembers"];
            [_conversation updateTopicNotifyImmediately:YES];
            return;
        }
    }

}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
    return _members[index];
}

- (void)cancelAdds
{
    if (_conversation.isNewConversation) {
        return;
    }

    [_conversation willChangeValueForKey:@"sortedMembers"];

    NSInteger i = 0;
    while (i < _members.count) {
        FLMember* member = _members[i];
        if (member.isAdded) {
            [_members removeObjectAtIndex:i];
        } else {
            i++;
        }
    }

    [_conversation didChangeValueForKey:@"sortedMembers"];
    [_conversation updateTopicNotifyImmediately:YES];
}

- (void)commitAdds
{
    if (_conversation.isNewConversation) {
        return;
    }

    NSArray* addedMembers = [self addedMembers];
    if (addedMembers.count == 0) {
        return;
    }
    
    [[FLApi api]addMembers:addedMembers
        toConversationWithId:_conversation.conversation_id
        onSuccess:nil
        onError:nil];
}

- (void)add:(NSString *)email name:(NSString *)name
{
    email = [email lowercaseString];
    if (![self containsEmail:email]) {
        FLMember* newMember = [[FLMember alloc] initWithEmail:email andName:name];
        newMember.isAdded = !newMember.isLocalContact;
        [_conversation willChangeValueForKey:@"sortedMembers"];
        [_members addObject:newMember];
        [_conversation didChangeValueForKey:@"sortedMembers"];
        [_conversation updateTopicNotifyImmediately:YES];
    }
}

@end
