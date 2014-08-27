//
//  FLConversationMatch.m
//  Fleep
//
//  Created by Erik Laansoo on 25.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLConversationMatch.h"
#import "FLDataModel.h"
#import "FLConversationLists.h"

@implementation FLConversationMatch
{
    NSAttributedString* _topic;
    NSAttributedString* _members;
}

@synthesize topic = _topic;
@synthesize members = _members;

- (id)initWithTopic:(NSAttributedString*)topic members:(NSAttributedString*)members
{
    if (self = [super init]) {
        _topic = topic;
        _members = members;
    }
    return self;
}

+ (FLConversationMatch*)matchConversation:(Conversation*)conversation
    searchString:(NSString*)searchString
{
    // Match topic
    NSAttributedString* topicMatch = nil;
    NSRange topicRange = [conversation.topicText rangeOfPrefixString:searchString];
    if (topicRange.location != NSNotFound) {
        topicMatch = [conversation.topicText attributedStringHighlightingRange:topicRange];
    }

    // Match members
    NSAttributedString* memberMatch = nil;
    NSSet* contactsMatchingSearch = [FLConversationLists conversationLists].contactsMatchingSearch;
    if (contactsMatchingSearch != nil) {
        __block NSMutableSet* matchingMembers = nil;
        [conversation.members enumerateObjectsUsingBlock:^(Member* m, BOOL *stop) {
            if ([contactsMatchingSearch containsObject:m.account_id]) {
                if (matchingMembers == nil) {
                    matchingMembers = [[NSMutableSet alloc] init];
                }
                [matchingMembers addObject:m.account_id];
            }
        }];

        if (matchingMembers != nil) {
            NSMutableAttributedString* mm = [[NSMutableAttributedString alloc] init];
            for (NSString* cid in matchingMembers.allObjects) {
                Contact* c = [[FLDataModel dataModel] contactFromId:cid];
                if (mm.length > 0) {
                    [mm appendAttributedString:[[NSAttributedString alloc] initWithString:@", "]];
                }

                [mm appendAttributedString:c.highlightedName];
            }
            memberMatch = mm;
        }
    }

    if ((topicMatch == nil) && (memberMatch == nil)) {
        return nil;
    }

    return [[FLConversationMatch alloc] initWithTopic:topicMatch members:memberMatch];
}

@end
