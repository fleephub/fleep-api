//
//  Message.h
//  Fleep
//
//  Created by Erik Laansoo on 05.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "FLJsonParser.h"
#import "FLUtils.h"
#import "FLClassificators.h"
#import "FLManagedObject.h"

typedef NS_ENUM(NSInteger, FLMessageOrder) {
    FLMessageOrderAscending = 1,
    FLMessageOrderDescending = 2,
    FLMessageOrderPinWeight = 3,
    FLMessageOrderSearchWeight = 4
};

typedef NS_ENUM(NSInteger, FLMessageField) {
    FLMessageFieldBody = 0
};

@class Message;

@interface FLMessageRepresentation : NSObject
{
    __weak Message* _message;
    NSString* _plainText;
    NSAttributedString* _attributedText;
    NSString* _posterName;
    FLJsonParser* _json;
    BOOL _expanded;
    BOOL _expandable;
}

@property (nonatomic, readonly) NSString* posterName;
@property (nonatomic, readonly) NSString* localizedText;
@property (nonatomic, readonly) NSAttributedString* searchMatchText;
@property (nonatomic, readonly) NSAttributedString* attributedText;
@property (nonatomic, readonly) NSString* fileName;
@property (nonatomic, readonly) NSString* fileId;
@property (nonatomic, readonly) NSUInteger fileSize;
@property (nonatomic, readonly) NSString* fileUrl;
@property (nonatomic, readonly) NSString* fileOriginalUrl;
@property (nonatomic, readonly) NSString* previewUrl;
@property (nonatomic, readonly) NSString* thumbnailUrl;
@property (nonatomic, readonly) CGSize imageSize;
@property (nonatomic, readonly) CGSize thumbnailSize;
@property (nonatomic, readonly) NSArray* links;
@property (nonatomic, readonly) BOOL expandable;
@property (nonatomic) BOOL expanded;

- (id)initWithMessage:(Message*)message;
- (void)refresh;
- (void)updatePosterName;
- (void)highlightSearchMatches;
- (CGFloat)formattedHeightForWidth:(CGFloat)width limit:(BOOL)limit;
@end

@interface Message : FLManagedObject <JsonSerialization>

+ (NSNumber*)extractMessageType:(FLJsonParser*)json;
+ (NSInteger)extractMessageTags:(FLJsonParser*)json;
+ (void)setRepresentationClass:(Class)representationClass;
- (void)updateRepresentation;

// Stored properties
@property (nonatomic, retain) NSString * account_id;
@property (nonatomic, retain) NSString * conversation_id;
@property (nonatomic, retain) NSString * message;
@property (nonatomic, retain) NSNumber * message_nr;
@property (nonatomic, retain) NSNumber * mk_message_type;
@property (nonatomic, retain) NSDate * posted_time;
@property (nonatomic, retain) NSDate * edited_time;
@property (nonatomic, retain) NSString * edit_account_id;
@property (nonatomic, retain) NSNumber * pin_weight;
@property (nonatomic, retain) NSNumber * tags;
@property (nonatomic, retain) NSNumber * inbox_nr;
@property (nonatomic, retain) NSString * hook_key;
@property (nonatomic, retain) NSNumber * prev_message_nr;
@property (nonatomic, retain) NSNumber * is_new_sheet;

// Locally calculated properties
@property (nonatomic, readonly) FLMessageRepresentation* representation;
@property (nonatomic) NSInteger searchWeight;
@property (nonatomic) NSString* markedText;
@property (nonatomic, readonly) NSString* poster_name;
@property (nonatomic, readonly) BOOL isUnconsumed;
@property (nonatomic, readonly) NSString* localizedMessage;
@property (nonatomic, readonly) BOOL isTextMessage;
@property (nonatomic, readonly) NSString* guid;
@property (nonatomic, readonly) BOOL canEdit;
@property (nonatomic, readonly) BOOL isEdited;
@property (nonatomic, readonly) BOOL isPinned;
@property (nonatomic, readonly) BOOL isPin;
@property (nonatomic, readonly) BOOL isUnpin;
@property (nonatomic, readonly) BOOL isSending;
@property (nonatomic, readonly) BOOL isFailed;
@property (nonatomic, readonly) BOOL isDeleted;
@property (nonatomic, readonly) NSString* plainMessageWithMarkup;
@property (nonatomic, readonly) NSString* lockAccountId;

- (NSComparisonResult)compareTo:(Message*)otherMessage;
- (void)setConversation:(id)conversation;
- (void)deleteMessage;
- (void)edit:(NSString*)message;
- (void)pinWithCompletion:(FLCompletionHandler)onCompletion;
- (void)unpin;
- (BOOL)isOfType:(FLMessageType)type;
- (void)deletePending;
- (void)resend;
- (void)cancel;

@end

@interface FLMessageArray : NSObject <NSFastEnumeration>
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) Message* lastMessage;
@property (nonatomic, readonly) FLMessageOrder order;

- (id)initWithOrder:(FLMessageOrder)order;
- (id)initWithMessages:(NSArray*)messages order:(FLMessageOrder)order;
- (NSInteger)indexOfMessageNr:(NSInteger)nr;
- (Message*)messageByNr:(NSInteger)nr;
- (NSInteger)insertionIndexForMessage:(NSObject*)m;
- (BOOL)addMessage:(Message*)message;
- (Message*)objectAtIndexedSubscript:(NSInteger)index;
- (void)addMessages:(FLMessageArray*)messages;
- (void)removeMessageNr:(NSInteger)messageNr;
@end
