//
//  ConversationWriters.h
//  Fleep
//
//  Created by Erik Laansoo on 25.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Conversation;

@interface ConversationWriters : NSObject

@property (nonatomic, readonly) NSInteger count;
@property (nonatomic, readonly) NSArray* nameList;

- (id)initWithConversation:(Conversation*)conversation;
- (void)updateActivityBy:(NSString*)accountId writing:(BOOL)writing
    messageNr:(NSInteger)messageNr;
- (void)setWritingStatus:(BOOL)writing messageNr:(NSInteger)messageNr;
- (NSString*)userEditingMessageNr:(NSInteger)messageNr;
@end
