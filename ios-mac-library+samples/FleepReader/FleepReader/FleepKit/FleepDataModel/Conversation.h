//
//  Conversation.h
//  Fleep
//
//  Created by Erik Laansoo on 05.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Message.h"
#import "FLFileUploader.h"
#import "FLUtils.h"
#import "FLClassificators.h"
#import "FLConversationMembers.h"
#import "FLMessageComposition.h"
#import "FLManagedObject.h"
#import "FLConversationLists.h"
#import "ConversationWriters.h"
#import "FLConversationMatch.h"

typedef NS_ENUM(NSInteger, FLConversationField) {
    FLConversationFieldHorizonBack    = 0,
    FLConversationFieldHorizonForward = 1,
    FLConversationFieldPinOrder       = 2,
    FLConversationFieldTopic          = 3,
    FLConversationFieldAlertLevel     = 4,
    FLConversationFieldHide           = 5,
    FLConversationFieldMessages       = 6
};

typedef NS_ENUM(NSInteger, FLConversationLoadType) {
    FLConversationLoadMessages = 1,
    FLConversationLoadFiles = 2,
    FLConversationLoadPins = 3,
    FLConversationLoadContext = 4,
    FLConversationLoadMessagesBefore,
    FLConversationLoadMessagesAfter
};

@interface FLConversationLoadRequest : NSObject
@property (nonatomic, readonly) FLConversationLoadType type;
@property (nonatomic, readonly) BOOL isFlowLoadRequest;
@property (nonatomic, readonly) NSInteger messageNr;
@end

@interface Conversation : FLManagedObject

// Stored properties
@property (nonatomic, retain) NSNumber * can_post;
@property (nonatomic, retain) NSString * conversation_id;
@property (nonatomic, retain) NSNumber * bw_message_nr;
@property (nonatomic, retain) NSNumber * fw_message_nr;
@property (nonatomic, retain) NSNumber * last_message_nr;
@property (nonatomic, retain) NSNumber * file_horizon;
@property (nonatomic, retain) NSNumber * pin_horizon;
@property (nonatomic, retain) NSNumber * read_message_nr;
@property (nonatomic, retain) NSString * topic;
@property (nonatomic, retain) NSSet * members;
@property (nonatomic, retain) NSNumber * inbox_message_nr;
@property (nonatomic, retain) NSNumber * join_message_nr;
@property (nonatomic, retain) NSDate * last_message_time;
@property (nonatomic, retain) NSNumber * pin_weight;
@property (nonatomic, retain) NSNumber * alert_level;
@property (nonatomic, retain) NSNumber * hide_message_nr;
@property (nonatomic, retain) NSNumber * pending_message_nr;
@property (nonatomic, retain) NSNumber * unread_count;
@property (nonatomic, retain) NSNumber * last_inbox_nr;
@property (nonatomic, retain) NSString * cmail;
@property (nonatomic, retain) NSString * teams;

// Locally calculated properties
@property (nonatomic, readonly) BOOL isUnread;
@property (nonatomic, readonly) BOOL isHidden;
@property (nonatomic, readonly) BOOL isNotifyingUnread;
@property (nonatomic, readonly) FLMessageArray* messages;
@property (nonatomic, readonly) FLMessageArray* fileMessages;
@property (nonatomic, readonly) FLMessageArray* pinnedMessages;
@property (nonatomic, readonly) FLMessageArray* searchMatchMessages;
@property (nonatomic, readonly) FLMessageComposition* messageComposition;

@property (nonatomic, readonly) NSInteger firstLoadedMessage;
@property (nonatomic, readonly) BOOL isLoading;
@property (nonatomic, readonly) FLConversationLoadRequest* loadRequest;
@property (nonatomic, readonly) NSDate* inboxDate;
@property (nonatomic, readonly) NSString* inboxMessageText;
@property (nonatomic, readonly) NSString* topicText;
@property (nonatomic, readonly) NSString* shortTopicText;
@property (nonatomic, readonly) NSInteger readMessageNumber;
@property (nonatomic, readonly) BOOL allMessagesLoaded;
@property (nonatomic, readonly) BOOL allFilesLoaded;
@property (nonatomic, readonly) BOOL allPinsLoaded;
@property (nonatomic, readonly) FLConversationMembers* sortedMembers;
@property (nonatomic, readonly) BOOL isNewConversation;
@property (nonatomic, readonly) BOOL alertsEnabled;
@property (nonatomic, readonly) ConversationWriters* writers;
@property (nonatomic, readonly) FLConversationMatch* filterMatch;
@property (nonatomic, readonly) BOOL searchInProgress;

@property (nonatomic, readwrite) NSString* searchText;

// Comparison functions for sorting. These methods return NSOrderedSame
// IIF argument is the same conversation as self.
- (NSComparisonResult) compareTimestamp:(Conversation*) otherConversation;
- (NSComparisonResult) comparePinOrder:(Conversation*) otherConversation;

- (void)loadMessages;
- (Message*)loadMessage:(NSInteger)messageNr;
- (void)loadMoreMessages;
- (void)loadMoreFiles;
- (void)loadMorePins;
- (void)fillGapFromMessageNr:(NSInteger)messageNr directionBefore:(BOOL)before;
- (Message*)messageByNumber:(NSInteger)messageNr;
- (Message*)messageByNumber:(NSInteger)messageNr searchOutsideSyncRange:(BOOL)searchOutsideSyncRange;
- (Message*)nextMessageFromNr:(NSInteger)messageNr direction:(NSInteger)direction;
- (BOOL)isMessageUnread:(Message*)message;

- (BOOL)containsMemberWithId:(NSString*)accountId;
- (BOOL)containsMemberWithEmail:(NSString*)email;
- (BOOL)localUserIsMember;

- (void)setWritingStatus:(BOOL)writing messageNr:(NSInteger)messageNr;
- (void)reportConversationOpened;

- (void)runServerSearch;
@end
