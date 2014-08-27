//
//  Message.m
//  Fleep
//
//  Created by Erik Laansoo on 05.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLDataModel.h"
#import "FLApi.h"
#import "FLApi+Actions.h"
#import "FLMessageParser.h"
#import "FLUtils.h"
#import "FLClassificators.h"
#import "FLMessageComposition.h"
#import "FLDataModelInternal.h"
#import "ConversationInternal.h"
#import "FLMarkupEncoder.h"
#import "FLUserProfile.h"
#import "FLMEssageStripper.h"

@interface Message ()
- (Conversation*)conversation;
@end

@implementation FLMessageRepresentation

@synthesize posterName = _posterName;
@synthesize expandable = _expandable;

- (BOOL)expanded
{
    return _expanded;
}

- (NSAttributedString*)searchMatchText
{
    if (_message.isTextMessage) {
        FLMessageParser* mp = [[FLMessageParser alloc] initWithMessage:_message.markedText
            flags:FLMessageParserFlagHighlightMatches];
        return mp.attributedText;

    } else {
        return [[NSAttributedString alloc] initWithString:self.localizedText attributes:nil];
    }
}

- (void)refresh
{
    if (_message.isTextMessage) {
        FLMessageStripper* ms = [[FLMessageStripper alloc] initWithMessage:_message.message];
        _plainText = ms.plainText;
    }
}

- (void)highlightSearchMatches
{
}

- (void)setExpanded:(BOOL)expanded
{
    if (_expanded == expanded) {
        return;
    }

    _expanded = expanded;
    [self refresh];
}

- (void)updatePosterName
{
    if (_message.hook_key == nil) {
        _posterName = [[FLDataModel dataModel]fullNameOfContact:_message.account_id];
    } else {
        _posterName = [[FLDataModel dataModel]hookName:_message.hook_key];
    }
}

- (id)initWithMessage:(Message *)message
{
    if (self = [super init]) {
        _message = message;
        if ([_message.message hasPrefix:@"{"]) {
            _json = [FLJsonParser jsonParserForString:_message.message];
        } else {
            FLMessageStripper* ms = [[FLMessageStripper alloc] initWithMessage:_message.message];
            _plainText = ms.plainText;
        }

        [self updatePosterName];
    }
    return self;
}

- (NSAttributedString*)attributedText
{
    if (_attributedText != nil) {
        return _attributedText;
    }

    [self refresh];
    return _attributedText;
}

- (NSString*)fileName
{
    assert([_message isOfType:FLMessageTypeFile] || [_message isOfType:FLMessageTypeDeletedFile]);
    return [_json extractString:@"file_name"];
}

- (NSString*)fileUrl
{
    assert([_message isOfType:FLMessageTypeFile] || [_message isOfType:FLMessageTypeDeletedFile]);
    return [_json extractString:@"file_url"];
}

- (NSString*)fileOriginalUrl
{
    assert([_message isOfType:FLMessageTypeFile] || [_message isOfType:FLMessageTypeDeletedFile]);
    return [_json extractString:@"file_original_url"];
}

- (BOOL)fileIsDeleted
{
    assert([_message isOfType:FLMessageTypeFile] || [_message isOfType:FLMessageTypeDeletedFile]);
    return [_json extractBool:@"is_deleted" defaultValue:NO].boolValue;
}

- (NSString*)previewUrl
{
    assert([_message isOfType:FLMessageTypeFile] || [_message isOfType:FLMessageTypeDeletedFile]);
    NSString* def = [_json extractString:@"thumb_url_50" defaultValue:nil];
    NSString* retina = [_json extractString:@"thumb_url_100" defaultValue:nil];

    return ([UIScreen mainScreen].scale > 1.99f) && (retina != nil) ? retina : def;
}

- (NSString*)thumbnailUrl
{
    assert([_message isOfType:FLMessageTypeFile] || [_message isOfType:FLMessageTypeDeletedFile]);
    NSInteger requiredSize = (NSInteger)MAX(self.thumbnailSize.width, self.thumbnailSize.height);
    NSInteger fullSize = (NSInteger)MAX(self.imageSize.width, self.imageSize.height);

    if ([UIScreen mainScreen].scale > 1.99f) {
        requiredSize *= 2;
    }

    if (requiredSize == 0) {
        return nil;
    }

    __block NSMutableArray* availableSizes = [[NSMutableArray alloc] init];
    [_json enumerateKeysUsingBlock:^(NSString *key) {
        if ([key hasPrefix:@"thumb_url_"]) {
            [availableSizes addObject:[NSNumber numberWithInteger:[key substringFromIndex:10].integerValue]];
        }
    }];
    [availableSizes addObject:@(fullSize)];

    [availableSizes sortUsingSelector:@selector(compare:)];
    NSInteger chosenSize = 0;
    for (NSNumber* size in availableSizes) {
        if (size.integerValue <= requiredSize) {
            chosenSize = size.integerValue;
            continue;
        }

        if (fabs(size.doubleValue - requiredSize) < fabs(size.doubleValue - (double)chosenSize)) {
            chosenSize = size.integerValue;
        }

        break;
    }

    if (chosenSize == 0) {
        return nil;
    }

    if (chosenSize == fullSize) {
        return self.fileUrl;
    }

    return [_json extractString:[NSString stringWithFormat:@"thumb_url_%ld", (long)chosenSize]];
}

- (CGSize)imageSize
{
    NSNumber* w = [_json extractInt:@"width" defaultValue:nil];
    NSNumber* h = [_json extractInt:@"height" defaultValue:nil];
    if ((w == nil) || (h == nil) || (w.integerValue < 1) || (h.integerValue < 1)) {
        return CGSizeZero;
    }

    return CGSizeMake(w.doubleValue, h.doubleValue);
}

+ (BOOL)previewAvailableForFileType:(NSString*)extension
{
    static NSSet* extensions = nil;
    if (extensions == nil) {
        extensions = [[NSSet alloc] initWithArray:@[
            @"jpg", @"jpeg", @"png", @"gif", @"pdf"
        ]];
    }

    return [extensions containsObject:[extension lowercaseString]];
}

- (CGSize)thumbnailSize
{
    CGSize size = self.imageSize;
    if ((size.width < 40.0f) || (size.height < 40.0f)) {
        return CGSizeZero;
    }

    if (![FLMessageRepresentation previewAvailableForFileType:self.fileName.pathExtension]) {
        return CGSizeZero;
    }

    CGFloat width = 288.0f;

/*
    if ([FLUserProfile userProfile].avatarsEnabled) {
        width -= 42.0f;
    }
*/    
    CGFloat scale = MIN(1.0f, MIN(width / size.width, 400 / size.height));
    CGFloat aspect = size.width / size.height;

    return CGSizeMake(ceil(size.width * scale), ceil((size.width * scale) / aspect));
}

- (NSUInteger)fileSize
{
    assert([_message isOfType:FLMessageTypeFile] || [_message isOfType:FLMessageTypeDeletedFile]);
    return [_json extractInt:@"file_size" defaultValue: [NSNumber numberWithInteger:0]].integerValue;
}

- (NSString*)fileId
{
    assert([_message isOfType:FLMessageTypeFile] || [_message isOfType:FLMessageTypeDeletedFile]);
    return [_json extractString:@"file_id" defaultValue: nil];
}

- (NSString*)localizedText
{
    return _plainText;
}

- (NSArray*)links
{
    FLMessageParser* mp = [[FLMessageParser alloc] initWithMessage:_message.message];
    return mp.links;
}

- (CGFloat)formattedHeightForWidth:(CGFloat)width limit:(BOOL)limit
{
    return 0.0f;
}

@end

Class _representationClass = nil;

@implementation Message
{
    __weak Conversation* _conversation;
    FLMessageRepresentation* _representation;
    BOOL _isSending;
    NSString* _lockAccountId;
    NSInteger _searchWeight;
    NSString* _markedText;
}

@dynamic account_id;
@dynamic conversation_id;
@dynamic message;
@dynamic message_nr;
@dynamic mk_message_type;
@dynamic posted_time;
@dynamic edit_account_id;
@dynamic edited_time;
@dynamic pin_weight;
@dynamic tags;
@dynamic inbox_nr;
@dynamic hook_key;
@dynamic prev_message_nr;
@dynamic is_new_sheet;

@synthesize isSending = _isSending;
@synthesize searchWeight = _searchWeight;
@synthesize markedText = _markedText;

+ (void)setRepresentationClass:(Class)representationClass
{
    _representationClass = representationClass;
}

- (Conversation*)conversation
{
    return _conversation;
}

- (FLMessageRepresentation*)representation
{
    if (_representation == nil) {
        Class c = (_representationClass != nil) ? _representationClass : [FLMessageRepresentation class];
        _representation = [[c alloc] initWithMessage:self];
    }

    return _representation;
}

- (NSString*)poster_name
{
    return self.representation.posterName;
}

- (NSString*)localizedMessage
{
    return self.representation.localizedText;
}

+ (NSNumber*)extractMessageType:(FLJsonParser*)json
{
    NSString* mt = [json extractString:@"mk_message_type"];
    if (mt == nil) {
        return nil;
    }

    NSNumber* res = FLClassificators.mk_message_type[mt];
    return res != nil ? res : @(FLMessageTypeSystem);
}

+ (NSInteger)extractMessageTags:(FLJsonParser *)json
{
    return [FLClassificators extractTags:json values:FLClassificators.mk_message_tag];
}

- (BOOL)isEdited
{
    return self.edit_account_id != nil;
}

- (void)detectDeletedFile
{
    if ([self isOfType:FLMessageTypeFile]) {
        FLJsonParser* jp = [FLJsonParser jsonParserForString:self.message];
        if ([jp extractBool:@"is_deleted" defaultValue:NO].boolValue) {
            self.mk_message_type = @(FLMessageTypeDeletedFile);
        }
    }
}

- (NSError*) deserializeFromJson:(FLJsonParser*) json
{
    self.conversation_id = [json extractString:@"conversation_id"];
    self.message_nr = [json extractInt:@"message_nr"];
    self.account_id = [json extractString:@"account_id"];
    NSString* markedText = [json extractString:@"marked_text" defaultValue:nil];
    NSString* message = [json extractString:@"message"];
    if ([message rangeOfString:@"<mark>"].location != NSNotFound) {
        markedText = message;
    }

    self.markedText = markedText;
    self.message = [json extractString:@"message"];
    self.pin_weight = [json extractFloat:@"pin_weight" defaultValue:nil];
    self.mk_message_type = [Message extractMessageType:json];
    self.posted_time = [json extractDate:@"posted_time"];
    self.edit_account_id = [json extractString:@"edit_account_id" defaultValue:nil];
    self.edited_time = [json extractDate:@"edited_time" defaultValue:nil];
    self.inbox_nr = [json extractInt:@"inbox_nr" defaultValue:@(0)];
    self.tags = [NSNumber numberWithInteger:[Message extractMessageTags:json]];
    self.hook_key = [json extractString:@"hook_key" defaultValue:nil];
    self.prev_message_nr = [json extractInt:@"prev_message_nr" defaultValue:nil];
    self.searchWeight = [json extractInt:@"search_weight" defaultValue:@(0)].integerValue;
    self.is_new_sheet = [json extractBool:@"is_new_sheet" defaultValue:NO];

    [self detectDeletedFile];
    return json.error;
}

- (NSError*) updateFromJson:(FLJsonParser*) json
{
    NSString* accountId = [json extractString:@"account_id" defaultValue:self.account_id];
    if (![accountId isEqualToString:self.account_id]) {
        self.account_id = accountId;
    }
    NSString* markedText = [json extractString:@"marked_text" defaultValue:self.markedText];
    NSString* message = [json extractString:@"message" defaultValue:nil];
    if (message != nil) {
        if ([message rangeOfString:@"<mark>"].location != NSNotFound) {
            markedText = message;
        }
        self.message = message;
    }

    NSString* lockAccountId = [json extractString:@"lock_account_id" defaultValue:nil];
    if (lockAccountId != nil) {
        [_conversation.writers updateActivityBy:lockAccountId writing:YES messageNr:self.message_nr.integerValue];
    }

    NSInteger tags = [Message extractMessageTags:json];
    if ((tags & FLMessageTagUnlock) && (self.lockAccountId != nil)) {
        [_conversation.writers updateActivityBy:self.lockAccountId writing:NO messageNr:self.message_nr.integerValue];
    }

    self.markedText = markedText;

    self.pin_weight = [json extractFloat:@"pin_weight" defaultValue:self.pin_weight];
    self.posted_time = [json extractDate:@"posted_time" defaultValue:self.posted_time];
    self.inbox_nr = [json extractInt:@"inbox_nr" defaultValue:self.inbox_nr];
    self.edit_account_id = [json extractString:@"edit_account_id" defaultValue:nil];
    self.edited_time = [json extractDate:@"edited_time" defaultValue:nil];
    self.searchWeight = [json extractInt:@"search_weight" defaultValue:@(0)].integerValue;
    self.prev_message_nr = [json extractInt:@"prev_message_nr" defaultValue:self.prev_message_nr];
    self.is_new_sheet = [json extractBool:@"is_new_sheet" defaultValue:self.is_new_sheet.boolValue];
    [self detectDeletedFile];

    if (self.markedText == nil) {
        if ((_representation != nil) && self.isTextMessage) {
            [_representation refresh];
        } else {
            _representation = nil;
        }
    }
    return json.error;
}

- (NSComparisonResult)compareTo:(Message*)otherMessage
{
    return [self.message_nr compare:otherMessage.message_nr];
}

- (BOOL)isTextMessage
{
    return [self isOfType:FLMessageTypeText] || [self isOfType:FLMessageTypeEmail];
}

- (BOOL)isPin
{
    return (self.tags.integerValue & MESSAGE_TAG_PIN) != 0;
}

- (BOOL)isUnpin
{
    return (self.tags.integerValue & MESSAGE_TAG_UNPIN) != 0;
}

- (void)setConversation:(id)conversation
{
    if (conversation != nil) {
        assert([conversation isKindOfClass:[Conversation class]]);
    }
    _conversation = conversation;
}

- (BOOL)isDeleted
{
    return self.message.length == 0;
}

- (BOOL)isUnconsumed
{
    return ![self isPending] && [_conversation isMessageUnread:self];
}

- (NSString*)guid
{
    return [NSString stringWithFormat:@"%@-%ld", self.conversation_id, (long)self.message_nr.integerValue];
}

- (BOOL)canEdit
{
    if (self.isFailed) {
        return YES;
    }
    
    BOOL amInConversation = _conversation.can_post.boolValue;
    BOOL isFromSelf = [[FLUserProfile userProfile]isSelf:self.account_id];
    BOOL isText = [self isOfType:FLMessageTypeText];
    BOOL isDeleted = (self.message == nil) || (self.message.length == 0);
    BOOL isPinned = (self.tags.integerValue & MESSAGE_TAG_PIN) != 0;
    BOOL isLocked = self.lockAccountId != nil;

    NSTimeInterval age = -[self.posted_time timeIntervalSinceNow];
    return amInConversation && isText && !isLocked && !isDeleted && (isPinned ||
        (isFromSelf && (age < 59 * SECONDS_IN_MINUTE)));
}

- (BOOL)isOfType:(FLMessageType)type
{
    return self.mk_message_type.integerValue == type;
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    if (self.needsSync) {
        [self setSending:YES notify:YES];
    }
}

- (void)setField:(NSInteger)field asDirty:(BOOL)dirty
{
    [super setField:field asDirty:dirty];
    if (dirty) {
        [_conversation setField:FLConversationFieldMessages asDirty:YES];
    } else {
        [self setSending:NO notify:YES];
    }
}

- (void)deleteMessage
{
    if ([self isPending]) {
        [self cancel];
        return;
    }

    _representation = nil;
    if ([self isOfType:FLMessageTypeFile]) {
        self.message = @"{\
           \"is_deleted\"': true,\
           \"file_type\": \"deleted\",\
           \"file_name\": \"deleted\",\
           \"file_url\" : \"\",\
           \"file_size\": 0 }";
        self.mk_message_type = @(FLMessageTypeDeletedFile);
        [_conversation notifyFileDeleted:self.message_nr.integerValue];
    } else {
        self.message = @"";
    }

    [self setField:FLMessageFieldBody asDirty:YES];
    [_conversation willChangeProperty:@"messages"];
    [_conversation performSelector:@selector(notifyPropertyChanges) withObject:nil afterDelay:0.1f];
}

- (void)edit:(NSString *)message
{
    [self willChangeValueForKey:@"message"];
    self.message = [FLMarkupEncoder xmlWithMessage:message];
    _representation = nil;
    if (!self.isFailed) {
        [self setField:FLMessageFieldBody asDirty:YES];
    }
    [_conversation willChangeProperty:@"messages"];
    if ((self.message_nr.integerValue == _conversation.inbox_message_nr.integerValue) ||
        (self.message_nr.integerValue == _conversation.pending_message_nr.integerValue)) {
        [_conversation willChangeProperty:@"inboxMessageText"];
    }
    if (self.isPinned) {
        [_conversation willChangeProperty:@"pinnedMessages"];
    }
    [self didChangeValueForKey:@"message"];
    [_conversation performSelector:@selector(notifyPropertyChanges) withObject:nil afterDelay:0.1f];
}

- (void)pinWithCompletion:(FLCompletionHandler)onCompletion
{
    [[FLApi api]pinMessageNr:self.message_nr.integerValue inConversationWithId:self.conversation_id
        onSuccess:onCompletion];
}

- (void)unpin
{
    [[FLApi api]unpinMessageNr:self.message_nr.integerValue inConversationWithId:self.conversation_id];
}

- (BOOL)isPinned
{
    return (self.pin_weight != nil) && (self.pin_weight.floatValue > 0.00f);
}

- (void)updateRepresentation
{
    if ((_representation != nil) && self.isTextMessage && (self.message_nr.integerValue < PENDING_MESSAGE_BASE)) {
        [_representation refresh];
    } else {
        _representation = nil;
    }
}

- (NSString*)plainMessageWithMarkup
{
    FLMessageStripper* ms = [[FLMessageStripper alloc] initWithMessage:self.message];
    return ms.plainTextWithMarkup;
}

- (void)setSending:(BOOL)sending notify:(BOOL)notify
{
    if (notify) {
        [_conversation willChangeProperties:@[@"messages"]];
        if (self.isPinned) {
            [_conversation willChangeProperties:@[@"pinnedMessages"]];
        }

        [self willChangeValueForKey:@"isSending"];
    }
    _isSending = sending;

    if (notify) {
        [self didChangeValueForKey:@"isSending"];
        [self willChangeValueForKey:@"isFailed"];
        [self didChangeValueForKey:@"isFailed"];
        [_conversation notifyPropertyChanges];
    }
}

- (void)resend
{
    [_conversation resendMessage:self];
}

- (NSString*)lockAccountId
{
    if (_conversation.writers == nil) {
        return nil;
    } else {
        return [_conversation.writers userEditingMessageNr:self.message_nr.integerValue];
    }
}

- (BOOL)isPending
{
    return self.message_nr.integerValue >= PENDING_MESSAGE_BASE;
}

- (BOOL)isFailed
{
    return [self isPending] && !_isSending;
}

- (void)deletePending
{
    assert([self isPending]);
    assert(_conversation != nil);
    [_conversation deleteMessageNr: self.message_nr.integerValue];
}

- (void)cancel
{
    [self deletePending];
    [_conversation performSelector:@selector(notifyPropertyChanges) withObject:nil
        afterDelay:0.1f];
}

- (FLApiRequest*)getSyncRequestForField:(NSInteger)field
{
    assert(field == FLMessageFieldBody);

    if ((self.message.length == 0) || [self isOfType:FLMessageTypeDeletedFile]) {
        return [[FLApiRequest alloc] initWithMethod:@"message/delete/%@" methodArg: self.conversation_id
        arguments:@{ @"message_nr": self.message_nr }];
    }

    NSString* message = [[FLMessageStripper alloc] initWithMessage:self.message].plainTextWithMarkup;

    return [[FLApiRequest alloc] initWithMethod:@"message/edit/%@" methodArg: self.conversation_id
        arguments:@{
            @"message_nr": self.message_nr,
            @"message" : message
        }];
}

@end

@implementation FLMessageArray
{
    NSComparator _comparator;
    NSMutableArray* _messages;
    FLMessageOrder _order;
}

@synthesize order = _order;

- (NSUInteger)count
{
    return _messages.count;
}

- (NSArray*)messages
{
    return _messages;
}

- (Message*)lastMessage
{
    return _messages.lastObject;
}

- (void)setOrder:(FLMessageOrder)order
{
    _order = order;
    switch (order) {
        case FLMessageOrderAscending: {
            _comparator = ^ NSComparisonResult(NSObject* m1, NSObject* m2) {
                NSNumber* n1 = [m1 isKindOfClass:Message.class] ? ((Message*)m1).message_nr : (NSNumber*)m1;
                NSNumber* n2 = [m2 isKindOfClass:Message.class] ? ((Message*)m2).message_nr : (NSNumber*)m2;
                return [n1 compare:n2];
            };
        }
        break;
        case FLMessageOrderDescending: {
            _comparator = ^ NSComparisonResult(NSObject* m1, NSObject* m2) {
                NSNumber* n1 = [m1 isKindOfClass:Message.class] ? ((Message*)m1).message_nr : (NSNumber*)m1;
                NSNumber* n2 = [m2 isKindOfClass:Message.class] ? ((Message*)m2).message_nr : (NSNumber*)m2;
            return [n2 compare:n1];
            };
        }
        break;
        case FLMessageOrderPinWeight: {
            _comparator = ^ NSComparisonResult(Message* m1, Message* m2) {
                return [m1.pin_weight compare:m2.pin_weight];
            };
        }
        break;
        case FLMessageOrderSearchWeight: {
            _comparator = ^ NSComparisonResult(Message* m1, Message* m2) {
                if (m2.searchWeight > m1.searchWeight) {
                    return NSOrderedDescending;
                } else if (m2.searchWeight < m1.searchWeight) {
                    return NSOrderedAscending;
                } else {
                    return [m1.posted_time compare:m2.posted_time];
                }
                };
            }
            break;
        default: assert(NO);
    }
}

- (id)init
{
    if (self = [super init]) {
        _messages = [[NSMutableArray alloc] init];
        [self setOrder:FLMessageOrderAscending];
    }
    return self;
}

- (id)initWithOrder:(FLMessageOrder)order
{
    if (self = [super init]) {
        _messages = [[NSMutableArray alloc] init];
        [self setOrder:order];
    }
    return self;
}

- (id)initWithMessages:(NSArray*)messages order:(FLMessageOrder)order
{
    if (self = [self init]) {
        _messages = [messages mutableCopy];
        [self setOrder:order];
        [_messages sortUsingComparator:_comparator];
    }
    return self;
}

- (Message*)objectAtIndexedSubscript:(NSInteger)index
{
    return _messages[index];
}

- (NSInteger)indexOfMessageNr:(NSInteger)nr
{
    if ((_order != FLMessageOrderAscending) && (_order != FLMessageOrderDescending)) {
        for (NSInteger i = 0; i < _messages.count; i++) {
            Message* m = _messages[i];
            if (m.message_nr.integerValue == nr) {
                return i;
            }
        }
        return NSNotFound;
    }

    return [_messages indexOfObject:@(nr) inSortedRange:NSMakeRange(0, _messages.count)
        options:NSBinarySearchingFirstEqual usingComparator:_comparator];
}

- (Message*)messageByNr:(NSInteger)nr
{
    NSInteger index = [self indexOfMessageNr:nr];
    if (index == NSNotFound) {
        return nil;
    } else {
        return self[index];
    }
}

- (NSInteger)insertionIndexForMessage:(NSObject*)m
{
    assert([m isKindOfClass:Message.class] || [m isKindOfClass:NSNumber.class]);

    NSRange range = NSMakeRange(0, _messages.count);
    NSInteger result = [_messages indexOfObject:m inSortedRange:range
        options:NSBinarySearchingFirstEqual | NSBinarySearchingInsertionIndex usingComparator:_comparator];

    assert(result != NSNotFound);
    return result;
}

- (BOOL)addMessage:(Message*)message
{
    NSInteger index = [self insertionIndexForMessage:message];
    if (
        (index < _messages.count) &&
        (self[index].message_nr.integerValue == message.message_nr.integerValue)) {
        return NO;
    } else {
        [_messages insertObject:message atIndex:index];
        return YES;
    }
}

- (void)addMessages:(FLMessageArray *)messages
{
    if (messages.order != self.order) {
        for (Message* m in messages) {
            [self addMessage:m];
        }
        return;
    }

    assert(messages.order == self.order);
    NSArray* m = [messages messages];
    if (m.count == 0) {
        return;
    }
    
    NSInteger headIndex = [self insertionIndexForMessage:messages[0]];
    NSInteger tailIndex = [self insertionIndexForMessage:messages[messages.count - 1]];

    if (headIndex == tailIndex) {
        [_messages insertObjects:m atIndexes:
            [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(headIndex, m.count)]];
    } else {
        for (Message* m in messages) {
            [self addMessage:m];
        }
    }
}

- (void)removeMessageNr:(NSInteger)messageNr
{
    NSInteger index = [self indexOfMessageNr:messageNr];
    if (index != NSNotFound) {
        [_messages removeObjectAtIndex:index];
    }
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len
{
    return [_messages countByEnumeratingWithState:state objects:stackbuf count:len];
}

- (NSString*)description
{
    NSMutableString* result = [[NSMutableString alloc] init];
    [result appendString:@"["];
    for (Message* m in _messages) {
        if (result.length > 1) {
            [result appendString:@" "];
        }
        [result appendFormat:@"%ld", (long)m.message_nr.integerValue];
    }
    [result appendFormat: @"] (%ld)", (long)_messages.count];
    return result;
}

@end

