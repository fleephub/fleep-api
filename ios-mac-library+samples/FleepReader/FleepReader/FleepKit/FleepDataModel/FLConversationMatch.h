//
//  FLConversationMatch.h
//  Fleep
//
//  Created by Erik Laansoo on 25.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Conversation;

@interface FLConversationMatch : NSObject
@property (nonatomic, readonly) NSAttributedString* topic;
@property (nonatomic, readonly) NSAttributedString* members;
+ (FLConversationMatch*)matchConversation:(Conversation*)conversation
    searchString:(NSString*)searchString;
@end
