//
//  FLConversationMembers.h
//  Fleep
//
//  Created by Erik Laansoo on 09.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Conversation;
@class FLMember;

@interface FLConversationMembers : NSObject
@property (nonatomic, readonly) NSInteger count;
@property (nonatomic, readonly) NSInteger countWithoutSelf;
@property (nonatomic, readonly) NSArray* asArray;

- (id)initWithConversation:(Conversation*)conversation;
- (FLMember*)memberByAccountId:(NSString*)accountId;
- (FLMember*)memberByEmail:(NSString*)email;
- (BOOL)containsId:(NSString*)accountId;
- (BOOL)containsEmail:(NSString*)email;
- (void)revokeAdd:(NSString*)email;
- (void)add:(NSString*)email name:(NSString*)name;
- (void)commitAdds;
- (void)cancelAdds;
- (void)refreshAndNotify:(BOOL)notify;
- (id)objectAtIndexedSubscript:(NSInteger)index;
- (NSArray*)nameList;
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
    objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len;
- (NSArray*)addedMembers;

@end
