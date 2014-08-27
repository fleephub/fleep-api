//
//  Conversation.m
//  Fleep
//
//  Created by Erik Laansoo on 05.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "Conversation.h"
#import "FLDataModel.h"
#import "FLDataModelInternal.h"
#import "FLApi.h"
#import "FLApi+Actions.h"
#import "FLApiInternal.h"
#import "FLApiWithLocalStorage.h"
#import "FLUtils.h"
#import "FLFileUploader.h"
#import "FLLocalization.h"
#import "FLClassificators.h"
#import "ConversationInternal.h"
#import "Conversation+Sync.h"
#import "FLUserProfile.h"
#import "FLMessageStripper.h"

// Minimum number of local messages to store, client will request sync
// until this number reached.
const NSInteger MIN_LOCAL_MESSAGES = 20;

@interface Message (Internal)
- (void)setSending:(BOOL)sending notify:(BOOL)notify;
@end

@implementation FLConversationLoadRequest
{
    FLConversationLoadType _type;
    NSInteger _messageNr;
}
@synthesize type = _type;
@synthesize messageNr = _messageNr;

- (BOOL)isFlowLoadRequest
{
    return (_type != FLConversationLoadFiles) && (_type != FLConversationLoadPins);
}

- (id)initWithType:(FLConversationLoadType)type messageNr :(NSInteger)messageNr
{
    if (self = [super init]) {
        _type = type;
        _messageNr = messageNr;
    }
    return self;
}

@end

@implementation Conversation
{
    Message* _inboxMessage;
    NSMutableSet* _messageObservers;
    FLConversationLoadRequest* _loadRequest;
    NSString* _topicText;

    NSNumber* _new_last_message_nr;
    NSNumber* _new_fw_message_nr;
    NSNumber* _new_last_inbox_nr;
    NSRange _cacheRange;
    FLMessageArray* _cachedMessages;

    FLMessageComposition* _messageComposition;
    FLConversationMembers* _sortedMembers;
    FLMessageArray* _messages;
    FLMessageArray* _fileMessages;
    FLMessageArray* _pinnedMessages;
    FLMessageArray* _newMessages;
    FLMessageArray* _searchMatchMessages;

    NSString* _searchText;
    FLConversationMatch* _filterMatch;
    NSInteger _searchIndex;
    NSInteger _firstLoadedMessage;

    ConversationWriters* _writers;
    NSMutableArray* _resendingMessages;
}

@dynamic bw_message_nr;
@dynamic can_post;
@dynamic conversation_id;
@dynamic fw_message_nr;
@dynamic file_horizon;
@dynamic last_message_nr;
@dynamic read_message_nr;
@dynamic topic;
@dynamic members;
@dynamic inbox_message_nr;
@dynamic join_message_nr;
@dynamic last_message_time;
@dynamic pin_weight;
@dynamic alert_level;
@dynamic pin_horizon;
@dynamic hide_message_nr;
@dynamic pending_message_nr;
@dynamic unread_count;
@dynamic last_inbox_nr;
@dynamic cmail;
@dynamic teams;

@synthesize topicText = _topicText;
@synthesize messages = _messages;
@synthesize filterMatch = _filterMatch;
@synthesize searchMatchMessages = _searchMatchMessages;
@synthesize firstLoadedMessage = _firstLoadedMessage;
@synthesize writers = _writers;
@synthesize loadRequest = _loadRequest;

- (ConversationWriters*)createWriters
{
    if (_writers == nil) {
        _writers = [[ConversationWriters alloc] initWithConversation:self];
    }
    return _writers;
}

- (void)resetWriters
{
    _writers = nil;
}

- (BOOL)searchInProgress
{
    return _searchIndex > 0;
}

- (NSString*)searchText
{
    return _searchText;
}

- (NSInteger)searchStarted
{
    BOOL started = _searchIndex == 0;
    if (started) {
        [self willChangeValueForKey:@"searchInProgress"];
    }
    _searchIndex++;
    if (started) {
        [self didChangeValueForKey:@"searchInProgress"];
    }
    return _searchIndex;
}

- (void)searchEndedWithIndex:(NSInteger)index
{
    if (index == _searchIndex) {
        [self willChangeValueForKey:@"searchInProgress"];
        _searchIndex = 0;
        [self didChangeValueForKey:@"searchInProgress"];
    }
}

- (void)runServerSearch
{
    if (_searchText == nil) {
        return;
    }

    NSInteger searchIndex = [self searchStarted];
    if (_searchMatchMessages != nil) {
        [self willChangeValueForKey:@"searchMatchMessages"];
        _searchMatchMessages = nil;
        [self didChangeValueForKey:@"searchMatchMessages"];
    }

    [[FLApi api] searchMessages:_searchText inConversation:self.conversation_id
        onResult:^(NSString *conversationId, NSInteger messageNr) {
            [[FLDataModel dataModel]conversationChanged:self];
            Message* m = [self messageByNumber:messageNr searchOutsideSyncRange:YES];
            if (m != nil) {
                [self addMatchingMessage:m];
            }
        } onSuccess:^{
            [self searchEndedWithIndex:searchIndex];
        } onError:^(NSError *error) {
            [self searchEndedWithIndex:searchIndex];
        }
    ];

}

- (void)addMatchingMessage:(Message *)m
{
    [self willChangeProperty:@"searchMatchMessages"];
    if (_searchMatchMessages == nil) {
        _searchMatchMessages = [[FLMessageArray alloc] initWithOrder:FLMessageOrderSearchWeight];
    }
    [_searchMatchMessages addMessage:m];
    [self addMessage:m];
}

- (void)setSearchText:(NSString *)searchText
{
    if ((searchText == nil) && (_searchText == nil)) {
        return;
    }

    if ([searchText isEqualToString:_searchText]) {
        return;
    }

    _searchText = searchText;
    if (_searchText == nil) {
        _filterMatch = nil;
    } else {
        _filterMatch = [FLConversationMatch matchConversation:self searchString:_searchText];
    }
    
    if (_searchMatchMessages != nil) {
        [self willChangeValueForKey:@"searchMatchMessages"];
        _searchMatchMessages = nil;
        [self didChangeValueForKey:@"searchMatchMessages"];
    }

    if (_messages != nil) {
        [self willChangeValueForKey:@"messages"];
        [self didChangeValueForKey:@"messages"];
    }
}

- (void)updateActivityBy:(NSString *)accountId writing:(BOOL)writing messageNr:(NSInteger)messageNr
{
    ConversationWriters* writers = [self createWriters];
    [writers updateActivityBy:accountId writing:writing messageNr:messageNr];
}

- (BOOL)isLoading
{
    return _loadRequest != nil;
}


- (BOOL)alertsEnabled
{
    return self.alert_level.integerValue != FLAlertLevelNever;
}

- (BOOL)isUnread
{
    return (self.unread_count.integerValue > 0) || (self.pending_message_nr.integerValue > 0);
}

- (BOOL)isNotifyingUnread
{
    return self.isUnread && self.alertsEnabled && !self.isHidden;
}

- (BOOL)isHidden
{
    return self.hide_message_nr.integerValue >= self.last_message_nr.integerValue;
}

- (NSString*)objectState
{
    NSMutableString* result = [[NSMutableString alloc] init];
    [result appendFormat:@"Conversation: %@\n", self.topicText];
    if (_inboxMessage != nil) {
        [result appendFormat:@"InboxMessage: %ld, '%@\n'", (long)_inboxMessage.message_nr.integerValue,
            _inboxMessage.localizedMessage];
    } else {
        [result appendString:@"InboxMessage: nil\n"];
    }

    [result appendFormat:@"CacheRange: %ld + %ld\n", (long)_cacheRange.location, (long)_cacheRange.length];
    [result appendFormat:@"Messages: %@\n", _messages];
    [result appendFormat:@"NewMessages: %@\n", _newMessages];
    [result appendFormat:@"new_last_message_nr: %@\n", _new_last_message_nr];
    [result appendFormat:@"new_fw_message_nr: %@\n", _new_fw_message_nr];

    return result;
}

- (FLMessageComposition*)messageComposition
{
    if (_messageComposition == nil) {
        _messageComposition = [[FLMessageComposition alloc] initWithConversation:self];
    }
    return _messageComposition;
}

- (FLMessageArray*)fileMessages
{
    if (_fileMessages == nil) {
        _fileMessages= [[FLDataModel dataModel] loadFileMessagesFromConversation:self];
    };
    return _fileMessages;
}

- (FLMessageArray*)pinnedMessages
{
    if (_pinnedMessages == nil) {
        _pinnedMessages= [[FLDataModel dataModel] loadPinnedMessagesFromConversation:self];
        if (_searchMatchMessages != nil) {
            for (Message* m in _searchMatchMessages) {
                if (m.isPinned) {
                    [_pinnedMessages addMessage:m];
                }
            }
        }
    };
    return _pinnedMessages;
}

- (FLConversationMembers*)sortedMembers
{
    if (_sortedMembers == nil) {
        _sortedMembers = [[FLConversationMembers alloc] initWithConversation: self];
    }
    return _sortedMembers;
}

- (NSString*)inboxMessageText
{
    if (_inboxMessage != nil) {
        if (_inboxMessage.isTextMessage && !(_inboxMessage.isFailed || _inboxMessage.isSending)) {
            return [NSString stringWithFormat:@"%@: %@", _inboxMessage.poster_name, _inboxMessage.localizedMessage];
        } else {
            return _inboxMessage.localizedMessage;
        }
    } else {
        return @"<null>";
    }
}

- (NSDate*)inboxDate
{
    if (_inboxMessage != nil) {
        return _inboxMessage.posted_time;
    } else {
        return nil;
    }
}

- (BOOL)isMessageUnread:(Message *)message
{
    return
        (message.message_nr.integerValue <= self.last_message_nr.integerValue) &&
        (message.message_nr.integerValue > self.readMessageNumber);
}

- (void)setUnreadCount:(NSInteger)count
{
    if (count == self.unread_count.integerValue) {
        return;
    }
    BOOL unreadChanged = self.isUnread != (count > 0);
    [self willChangeProperties:unreadChanged ? @[@"unread_count", @"isUnread", @"isNotifyingUnread"] : @[@"unread_count"]];
    self.unread_count = @(count);
    if (unreadChanged) {
        [[FLDataModel dataModel]conversationChanged:self];
    }
}

- (void)updateUnreadCount
{
    if (_inboxMessage != nil) {
        NSInteger unreadCount = self.last_inbox_nr.integerValue - labs(_inboxMessage.inbox_nr.integerValue);
        if (self.read_message_nr.integerValue < self.inbox_message_nr.integerValue) {
            unreadCount += 1;
        }

        [self setUnreadCount:unreadCount];
    }
}

- (void)setInboxMessageNr:(NSInteger)inboxMessageNr
{
    if (inboxMessageNr == self.inbox_message_nr.integerValue) {
        return;
    }

    [self willChangeProperty:@"inbox_message_nr"];
    self.inbox_message_nr = @(inboxMessageNr);
    [self updateInboxMessage];
    [self updateUnreadCount];
}

- (BOOL)allMessagesLoaded
{
    return (self.firstLoadedMessage > 0) && (self.firstLoadedMessage <= self.join_message_nr.integerValue);
}

- (BOOL)allFilesLoaded
{
    return self.file_horizon.integerValue == 0;
}

- (BOOL)allPinsLoaded
{
    return self.pin_horizon.integerValue == 0;
}

- (NSComparisonResult) compare:(Conversation*) otherConversation
{
    return [self.conversation_id compare:otherConversation.conversation_id];
}

- (NSComparisonResult) compareTimestamp:(Conversation*) otherConversation
{
    BOOL ownIsUnread = self.isNotifyingUnread;
    BOOL otherIsUnread = otherConversation.isNotifyingUnread;

    if (ownIsUnread != otherIsUnread) {
        return ownIsUnread ? NSOrderedAscending : NSOrderedDescending;
    }

    NSTimeInterval ownTimestamp = self.last_message_time.timeIntervalSinceReferenceDate;
    NSTimeInterval otherTimestamp = otherConversation.last_message_time.timeIntervalSinceReferenceDate;

    if (ownTimestamp > otherTimestamp) {
        return NSOrderedAscending;
    } else if (ownTimestamp < otherTimestamp) {
        return NSOrderedDescending;
    } else {
        return [self compare:otherConversation];
    }
}

- (NSComparisonResult) comparePinOrder:(Conversation*) otherConversation
{
    if (self.pin_weight == nil) {
        return NSOrderedAscending;
    }
    if (otherConversation.pin_weight == nil) {
        return NSOrderedDescending;
    }

    NSComparisonResult res = [self.pin_weight compare:otherConversation.pin_weight];
    return res != NSOrderedSame ? res : [self compare:otherConversation];
}

- (void)loadMessageCacheRange:(NSRange)range
{
    NSInteger from = range.location;
    NSInteger to = from + range.length - 1;
    from = MAX(from, 0);
    to = MIN(to, self.last_message_nr.integerValue);

    range = NSMakeRange(from, to - from + 1);

    if (NSEqualRanges(range, _cacheRange)) {
        return;
    }

    _cacheRange = range;
    _cachedMessages = [[FLDataModel dataModel] loadMessagesFromConversation:self
        from:range.location to:range.location + range.length - 1];
}

- (void)loadMessages
{
    if (_messages != nil) {
        _firstLoadedMessage = (_messages.count > 0) ? _messages[0].message_nr.integerValue : 0;
        return;
    }

    [self willChangeValueForKey:@"messages"];
    _messages = [[FLDataModel dataModel] loadRecentMessagesInConversation:self];
    _firstLoadedMessage = (_messages.count > 0) ? _messages[0].message_nr.integerValue : 0;
    [self didChangeValueForKey:@"messages"];
}

- (BOOL)contiguousMessagesExistAround:(NSInteger)messageNr count:(NSInteger)count direction:(NSInteger)direction
{
    NSInteger index = [_messages indexOfMessageNr:messageNr];
    if (index == NSNotFound) {
        return NO;
    }

    NSInteger inboxNr = _messages[index].inbox_nr.integerValue;
    while (count > 0) {
        index += direction;

        if (index >= _messages.count) {
            return YES;
        }

        if (index < 0) {
            return _messages[0].message_nr.integerValue <= self.join_message_nr.integerValue;
        }

        NSInteger nr = _messages[index].inbox_nr.integerValue;
        if (labs(nr - inboxNr) > 1) {
            return NO;
        }
        if (labs(nr - inboxNr) == 1) {
            count--;
        }
    }

    return YES;
}

- (BOOL)contextMessagesExistAround:(NSInteger)messageNr
{
    return [self contiguousMessagesExistAround:messageNr count:5 direction:1] &&
        [self contiguousMessagesExistAround:messageNr count:5 direction:-1];
}

- (Message*)loadMessage:(NSInteger)messageNr
{
    Message* result = [_messages messageByNr:messageNr];
    if (result != nil) {
        return result;
    }

    NSInteger loadFrom = MAX(messageNr - 10, self.join_message_nr.integerValue);
    NSInteger loadTo = MIN(messageNr + 10, self.last_message_nr.integerValue);

    FLMessageArray* newMessages =
        [[FLDataModel dataModel] loadMessagesFromConversation:self from:loadFrom
            to:loadTo];

    if (newMessages.count > 0) {
        [self willChangeValueForKey:@"messages"];
        [_messages addMessages:newMessages];
        [self didChangeValueForKey:@"messages"];
    }

    if (![self contextMessagesExistAround:messageNr]) {
        [self setLoadRequest:FLConversationLoadContext messageNr:messageNr];
    }

    return [_messages messageByNr:messageNr];
}

- (void)loadMoreMessages
{
    if (_messages == nil) {
        [self loadMessages];
        return;
    }

    if (self.allMessagesLoaded) {
        return;
    }

    if (_firstLoadedMessage > _messages[0].message_nr.integerValue) {
        [self fillGapFromMessageNr:_messages[0].message_nr.integerValue directionBefore:YES];
        return;
    }

    NSInteger requiredMessageNr = 0;

    if (_messages.count > 0) {
        Message* firstMessage = [self messageByNumber:self.firstLoadedMessage];
        requiredMessageNr = [[FLDataModel dataModel] messageNrFromInboxMessageNr:MAX(0, firstMessage.inbox_nr.integerValue - 30)
            inConversation:self];
        requiredMessageNr = MAX(requiredMessageNr, self.bw_message_nr.integerValue);

        FLMessageArray* newMessages =
            [[FLDataModel dataModel] loadMessagesFromConversation:self from:requiredMessageNr
                to:self.firstLoadedMessage - 1];
        if (newMessages.count > 0) {
            _firstLoadedMessage = MIN(_firstLoadedMessage, newMessages[0].message_nr.integerValue);
            [self willChangeValueForKey:@"messages"];
            [_messages addMessages:newMessages];
            [self didChangeValueForKey:@"messages"];
            return;
        }
    }

    if (!self.allMessagesLoaded) {
        [self setLoadRequest:FLConversationLoadMessages messageNr:0];
    }
}

- (void)setLoadRequest:(FLConversationLoadType)type messageNr:(NSInteger)messageNr
{
    [self willChangeValueForKey:@"isLoading"];
    [self willChangeValueForKey:@"loadRequest"];
    _loadRequest = [[FLConversationLoadRequest alloc] initWithType:type messageNr:messageNr];
    [self didChangeValueForKey:@"isLoading"];
    [self didChangeValueForKey:@"loadRequest"];
    if (_loadRequest != nil) {
        [[FLApiWithLocalStorage apiWithLocalStorage] synchronizeConversation:self];
    }
}

- (void)loadMoreFiles
{
    if (self.allFilesLoaded) {
        return;
    }
    [self setLoadRequest:FLConversationLoadFiles messageNr:0];
}

- (void)loadMorePins
{
    if (self.allPinsLoaded) {
        return;
    }
    [self setLoadRequest:FLConversationLoadPins messageNr:0];
}

- (void)notifyFileDeleted:(NSInteger)messageNr
{
    if ((_fileMessages != nil) && ([_fileMessages indexOfMessageNr:messageNr] != NSNotFound)) {
        [self willChangeProperty:@"fileMessages"];
        [_fileMessages removeMessageNr:messageNr];
    }
}

- (void)releaseMessages
{
    FLLogDebug(@"Conv <%x>: releaseMessages", (uint)self);
    _messages = nil;
    _fileMessages = nil;
    _pinnedMessages = nil;
    _loadRequest = nil;
    _sortedMembers = nil;
    _messageComposition = nil;
    [_inboxMessage updateRepresentation];
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    return NO;
}

- (void)updateInboxMessage
{
    Message* newInboxMessage = nil;

    if (self.pending_message_nr.integerValue > 0) {
        newInboxMessage = [self messageByNumber:self.pending_message_nr.integerValue];
    } else {
        newInboxMessage = [self messageByNumber:self.inbox_message_nr.integerValue];
    }

    BOOL messageChanged = newInboxMessage != _inboxMessage;

    if (messageChanged) {
        [self willChangeValueForKey:@"inboxDate"];
        [self willChangeValueForKey:@"inboxMessageText"];

        _inboxMessage = newInboxMessage;
        
        [self didChangeValueForKey:@"inboxDate"];
        [self didChangeValueForKey:@"inboxMessageText"];
    }

    if (messageChanged) {
        [[FLDataModel dataModel]conversationChanged:self];
    }
}

- (NSString*)computeTopic
{
    if ((self.topic != nil) && (self.topic.length > 0)) {
        return self.topic;
    }

    if (self.isNewConversation) {
        if (_sortedMembers.count == 2) {
            return [FLLocalization nameListAsString:_sortedMembers.nameList];
        } else {
            return FLLocalize(@"new_conversation", @"New conversation");
        }
    }

    NSArray* nameList = nil;
    if (_sortedMembers != nil) {
        nameList = _sortedMembers.nameList;
    } else {
        FLConversationMembers* members = [[FLConversationMembers alloc] initWithConversation:self];
        nameList = members.nameList;
    }

    if (nameList.count > 0) {
        return [FLLocalization nameListAsString:nameList];
    }

    return [self containsMemberWithId:[FLUserProfile userProfile].contactId] ?
        FLLocalize(@"topic_monologue", @"Monologue with myself") : FLLocalize(@"topic_empty", @"Abandoned conversation");
}

- (void)updateTopicNotifyImmediately:(BOOL)notifyImmediately
{
    NSString* newTopic = [self computeTopic];
    if ((_topicText == nil) || ![_topicText isEqualToString:newTopic]) {
        [self willChangeProperties:@[@"topicText"]];
        _topicText = newTopic;
        if (notifyImmediately) {
            [self notifyPropertyChanges];
        }
    }
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    [self updateInboxMessage];
    [self updateTopicNotifyImmediately:NO];
    [self notifyPropertyChanges];
}

- (NSString*) shortTopicText
{
    return [FleepUtils shortenString:self.topicText toLength:30];
}

- (BOOL)needsMessageLoad
{
    return (self.numberOfLocalMessagesPresent < self.numberOfLocalMessagesRequired);
}

- (BOOL)needsSync
{
    return [super needsSync] || self.needsMessageLoad || (_loadRequest != nil);
}

- (NSInteger)numberOfLocalMessagesRequired
{
    if (self.last_message_nr.integerValue <= 0) {
        return 0;
    }

    NSInteger requiredFirstMessage = self.read_message_nr.integerValue - MIN_LOCAL_MESSAGES;
    if ([FLDataModel dataModel].syncFullHistory) {
        requiredFirstMessage = self.join_message_nr.integerValue;
    }

    requiredFirstMessage = MAX(requiredFirstMessage, self.join_message_nr.integerValue);

    return self.last_message_nr.integerValue - requiredFirstMessage;
}

- (NSInteger)numberOfLocalMessagesPresent
{
    if ((self.fw_message_nr != nil) && (self.bw_message_nr != nil)) {
        return self.fw_message_nr.integerValue - self.bw_message_nr.integerValue + 1;
    } else {
        return _inboxMessage != nil ? 1 : 0;
    }
}

- (void)deletePinnedMessage:(Message*)message
{
    message.pin_weight = nil;
    if (_pinnedMessages != nil) {
        [self willChangeValueForKey:@"pinnedMessages"];
        [_pinnedMessages removeMessageNr:message.message_nr.integerValue];
        [self didChangeValueForKey:@"pinnedMessages"];
    }
}

- (void)encounteredMessageNr:(NSInteger)messageNr
{
    NSNumber* prev_last_message_nr = (_new_last_message_nr != nil) ? _new_last_message_nr : self.last_message_nr;
    NSNumber* prev_fw_message_nr = (_new_fw_message_nr != nil) ? _new_fw_message_nr : self.fw_message_nr;

    if (messageNr > prev_last_message_nr.integerValue) {
        _new_last_message_nr = [NSNumber numberWithInteger:messageNr];
    }

    if ((prev_fw_message_nr != nil) && (messageNr == prev_fw_message_nr.integerValue + 1)) {
        _new_fw_message_nr = [NSNumber numberWithInteger:messageNr];
    }
}

- (void)addMessage:(Message*)message
{
    if (NSLocationInRange(message.message_nr.integerValue, _cacheRange)) {
        [_cachedMessages addMessage:message];
    }
    
    [self encounteredMessageNr:message.message_nr.integerValue];
    NSNumber* prev_last_inbox_nr = _new_last_inbox_nr != nil ? _new_last_inbox_nr : self.last_inbox_nr;
    if (message.inbox_nr.integerValue > prev_last_inbox_nr.integerValue) {
        _new_last_inbox_nr = message.inbox_nr;
    }

    if (_newMessages == nil) {
        _newMessages = [[FLMessageArray alloc] initWithOrder:FLMessageOrderAscending];
    }
    [_newMessages addMessage:message];
}

- (void)commitNewMessages
{
    if (_newMessages == nil) {
        return;
    }

    for (Message* message in _newMessages) {
        if (message.message_nr.integerValue == self.inbox_message_nr.integerValue) {
            [self willChangeProperties:@[@"inboxDate", @"inboxMessageText"]];
        }

        if ((_fileMessages != nil) && ([message isOfType:FLMessageTypeFile])) {
            [self willChangeProperties:@[@"fileMessages"]];
            [_fileMessages addMessage:message];
        }

        if ((_fileMessages != nil) && ([message isOfType:FLMessageTypeDeletedFile])) {
            [self willChangeProperties:@[@"fileMessages"]];
            [_fileMessages removeMessageNr:message.message_nr.integerValue];
        }

        if ((_pinnedMessages != nil) && message.isPinned) {
            [self willChangeProperties:@[@"pinnedMessages"]];
            [_pinnedMessages addMessage:message];
        }

        BOOL flowLoadRequested = (_loadRequest != nil) && _loadRequest.isFlowLoadRequest;
        if ((_messages != nil) && (flowLoadRequested || (message.message_nr.integerValue > _firstLoadedMessage))) {
            [self willChangeProperties:@[@"messages"]];
            [_messages addMessage:message];
        }

        if (message.message_nr.integerValue > self.read_message_nr.integerValue) {
            [self updateActivityBy:message.account_id writing:NO messageNr:0];
        }
    }

    _newMessages = nil;
}

- (void) commitChanges
{
    if (_new_fw_message_nr != nil) {
        self.fw_message_nr = _new_fw_message_nr;
        _new_fw_message_nr = nil;
    }

    if (_new_last_message_nr != nil) {
        self.last_message_nr = _new_last_message_nr;
        _new_last_message_nr = nil;
    }

    if (_new_last_inbox_nr != nil ) {
        self.last_inbox_nr = _new_last_inbox_nr;
        _new_last_inbox_nr = nil;
    }

    if (_newMessages != nil) {
        [self commitNewMessages];
    }

    if ((_sortedMembers != nil) && !self.isNewConversation) {
        [_sortedMembers refreshAndNotify:YES];
    }

    [self updateInboxMessage];
    [self updateTopicNotifyImmediately:NO];

    _cachedMessages = nil;
    _cacheRange = NSMakeRange(0, 0);

    [self notifyPropertyChanges];
}

- (void)dealloc
{
    FLLogDebug(@"Conv %@ : dealloc", self.topicText);
}

- (BOOL)containsMemberWithId:(NSString*) accountId
{
    if (_sortedMembers != nil) {
        return [_sortedMembers containsId:accountId];
    }
    
    for (Member* m in self.members) {
        if ([m.account_id isEqualToString:accountId]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)containsMemberWithEmail:(NSString *)email
{
    if (_sortedMembers != nil) {
        return [_sortedMembers containsEmail:email];
    }

    Contact* c = [[FLDataModel dataModel]contactFromEmail:email];
    return ((c != nil) && [self containsMemberWithId:c.account_id]);
}

- (BOOL)localUserIsMember
{
    return [self containsMemberWithId:[FLUserProfile userProfile].contactId];
}

- (NSInteger)readMessageNumber
{
    if (self.read_message_nr == nil) {
        return 0;
    } else {
        return self.read_message_nr.integerValue;
    }
}

- (BOOL)messageExistsForNr:(NSInteger)messageNr
{
    if (messageNr == _inboxMessage.message_nr.integerValue) {
        return YES;
    }

    if ((self.bw_message_nr == nil) || (self.fw_message_nr == nil)) {
        return YES;
    }

    if (messageNr < self.bw_message_nr.integerValue) {
        return NO;
    }
    return YES;
}

- (Message*)messageByNumber:(NSInteger)messageNr
{
    return [self messageByNumber:messageNr searchOutsideSyncRange:NO];
}

- (Message*)messageByNumber:(NSInteger)messageNr searchOutsideSyncRange:(BOOL)searchOutsideSyncRange
{
    static NSInteger totalMbnRequests = 0;
    static NSInteger cacheHits = 0;

    totalMbnRequests++;
    if (NSLocationInRange(messageNr, _cacheRange)) {
        cacheHits++;
        // Failure is authoritative!
        return [_cachedMessages messageByNr:messageNr];
    }

    if ((_inboxMessage != nil) && (messageNr == _inboxMessage.message_nr.integerValue)) {
        return _inboxMessage;
    }

    if (_newMessages != nil) {
        Message* m = [_newMessages messageByNr:messageNr];
        if (m != nil) {
            return m;
        }
    }
    
    NSInteger idx = NSNotFound;
    if (_messages != nil) {
        idx = [_messages indexOfMessageNr:messageNr];
    }

    if (idx == NSNotFound) {
        if (![self messageExistsForNr:messageNr] && !searchOutsideSyncRange) {
            return nil;
        }

        Message* m = [[FLDataModel dataModel]messageFromId:self.conversation_id
            atIndex:messageNr];
        [m setConversation:self];
        return m;
    } else {
        return _messages[idx];
    }
}

- (Message*)nextMessageFromNr:(NSInteger)messageNr direction:(NSInteger)direction
{
    while (((messageNr + direction) >= self.join_message_nr.integerValue) &&
        ((messageNr + direction) <= self.last_message_nr.integerValue)) {

        messageNr += direction;
        if (![self messageExistsForNr:messageNr]) {
            return nil;
        }
        Message* res = [self messageByNumber:messageNr];
        if (res != nil) {
            return res;
        }
    }

    return nil;
}

- (BOOL) isNewConversation
{
    return [self.conversation_id isEqualToString:NEW_CONVERSATION_ID];
}

- (void)addObserver:(NSObject*)observer forKeyPaths:(NSArray*)keyPaths
{
    [super addObserver:observer forKeyPaths: keyPaths];

    if ([keyPaths containsObject:@"messages"]) {
        NSNumber* mo = [NSNumber numberWithInteger:(NSInteger)observer];
        if (_messageObservers == nil) {
            _messageObservers = [[NSMutableSet alloc] init];
        }
        [_messageObservers addObject:mo];
    }
}

- (void)removeObserver:(NSObject*)observer forKeyPaths:(NSArray*)keyPaths
{
    [super removeObserver:observer forKeyPaths:keyPaths];

    if ([keyPaths containsObject:@"messages"]) {
        NSNumber* mo = [NSNumber numberWithInteger:(NSInteger)observer];
        [_messageObservers removeObject:mo];
        if (_messageObservers.count == 0) {
            _messageObservers = nil;
            [self releaseMessages];
        }
    }
}

- (void)notifyContactChange:(NSSet*)contactIds
{
    if ((_inboxMessage != nil) && ([contactIds containsObject:_inboxMessage.account_id])) {
        [self willChangeProperty:@"inboxMessageText"];
        [_inboxMessage updateRepresentation];
    }

    if (_messages != nil) {
        BOOL changes = NO;
        for (Message* m in _messages) {
            if ([contactIds containsObject:m.account_id]) {
                if (m.representation != nil) {
                    [m.representation updatePosterName];
                }
                changes = YES;
            }
        }

        if (changes) {
            [self willChangeProperty:@"messages"];
        }
    }

    if (_searchMatchMessages != nil) {
        BOOL changes = NO;
        for (Message* m in _searchMatchMessages) {
            if ([contactIds containsObject:m.account_id]) {
                if (m.representation != nil) {
                    [m.representation updatePosterName];
                }
                changes = YES;
            }
        }

        if (changes) {
            [self willChangeProperty:@"searchMatch"];
        }
    }

    for (NSString* cid in contactIds.allObjects) {
        if ([self containsMemberWithId:cid]) {
            [self willChangeProperty:@"members"];
            break;
        }
    }
}

- (Message*)createMessageType:(FLMessageType)type body:(NSString*)body
{
    [self willChangeProperties:@[@"messages"]];
    if (_messages == nil) {
        if (self.isNewConversation) {
            _messages = [[FLMessageArray alloc] initWithOrder:FLMessageOrderAscending];
        } else {
            [self loadMessages];
        }
    }
    
    NSManagedObject* m = [[FLDataModel dataModel] createObjectOfClass:@"Message"];
    if (m == nil) {
        FLLogError(@"Conversation::CreateMessageType failed");
    }
    assert([m isKindOfClass:[Message class]]);

    NSInteger newMessageNr = PENDING_MESSAGE_BASE;
    if (_messages.count > 0) {
        newMessageNr = MAX(newMessageNr, _messages[_messages.count - 1].message_nr.integerValue + 1);
    }

    self.pending_message_nr = [NSNumber numberWithInteger:newMessageNr];
    Message* message = (Message*)m;
    message.conversation_id = self.conversation_id;
    message.message_nr = [NSNumber numberWithInteger:newMessageNr];
    message.mk_message_type = [NSNumber numberWithInteger:type];
    message.posted_time = [NSDate date];
    message.account_id = [FLUserProfile userProfile].contactId;
    message.message = body;
    [message setConversation:self];
    [message setSending:YES notify:NO];

    NSError* err;
    [message validateForInsert:&err];
    if (err != nil) {
        FLLogError(@"Conversation::CreateMessageType: %@", err);
        return nil;
    }

    [message awakeFromFetch];
    [_messages addMessage:message];
    
    return message;
}

- (void)deleteMessageNr:(NSInteger)messageNr
{
    Message* m = [self messageByNumber:messageNr searchOutsideSyncRange:YES];

    if (_cachedMessages != nil) {
        [_cachedMessages removeMessageNr:messageNr];
    }
    if ((_pinnedMessages != nil) && ([_pinnedMessages messageByNr:messageNr] != nil)) {
        [self willChangeProperties:@[@"pinnedMessages"]];
        [_pinnedMessages removeMessageNr:messageNr];
    }
    if ((_fileMessages != nil) && ([_fileMessages messageByNr:messageNr] != nil)) {
        [self willChangeProperties:@[@"fileMessages"]];
        [_fileMessages removeMessageNr:messageNr];
    }
    if ((_messages != nil) && ([_messages messageByNr:messageNr] != nil)) {
        [self willChangeProperties:@[@"messages"]];
        [_messages removeMessageNr:messageNr];
        if (_messages.count == 0) {
            _messages = nil;
        }
    }

    if (self.pending_message_nr.integerValue == messageNr) {
        Message* pm = nil;
        for (NSInteger mnr = messageNr - 1; mnr >= PENDING_MESSAGE_BASE; mnr--) {
            pm = [self messageByNumber:mnr];
            if (pm != nil) {
                break;
            }
        }
        if (pm != nil) {
            self.pending_message_nr = [NSNumber numberWithInteger:pm.message_nr.integerValue];
        } else {
            self.pending_message_nr = [NSNumber numberWithInteger:0];
        }
    }

    if (messageNr == self.last_message_nr.integerValue) {
        self.last_message_nr = [NSNumber numberWithInteger:self.last_message_nr.integerValue - 1];
        if (messageNr == self.read_message_nr.integerValue) {
            self.read_message_nr = [NSNumber numberWithInteger:self.read_message_nr.integerValue - 1];
        }
    }

    if (messageNr == self.fw_message_nr.integerValue) {
        self.fw_message_nr = [NSNumber numberWithInteger:self.fw_message_nr.integerValue - 1];
    }

    if (messageNr == self.inbox_message_nr.integerValue) {
        self.inbox_message_nr = nil;
    }

    [self updateInboxMessage];
    if (m != nil) {
        [[FLDataModel dataModel] deleteObject:m];
    }
}

- (void)setWritingStatus:(BOOL)writing messageNr:(NSInteger)messageNr
{
    if (self.isNewConversation || (messageNr > self.last_message_nr.integerValue)) {
        return;
    }

    [[self createWriters] setWritingStatus:writing messageNr:messageNr];
}

- (void)reportConversationOpened
{
    if (![self localUserIsMember] || self.isNewConversation) {
        return;
    }

    [[FLApi api] queueRequest:[[FLApiRequest alloc] initWithMethod:@"conversation/show_activity/%@"
        methodArg:self.conversation_id arguments:nil] name:[NSString stringWithFormat: @"show_activity_%@", self.conversation_id]];
}

- (void)setField:(NSInteger)field asDirty:(BOOL)dirty
{
    [super setField:field asDirty:dirty];
    if (dirty) {
        [[FLApiWithLocalStorage apiWithLocalStorage] synchronizeConversation:self];
    }
}

- (FLApiRequest*)getSyncRequestForField:(NSInteger)field
{
    switch (field) {
        case FLConversationFieldHorizonBack:
            return [self getMarkUnreadRequest];
        case FLConversationFieldHorizonForward: {
            FLApiRequest* request = [self getMarkReadRequest];
            request.priority = FLApiRequestPriorityLowest;
            return request;
        }
        case FLConversationFieldAlertLevel:
            return [self getSetAlertLevelRequest];
        case FLConversationFieldHide:
            return [self getHideRequest];
        case FLConversationFieldPinOrder:
            return [self getSetPinOrderRequest];
        case FLConversationFieldTopic:
            return [self getSetTopicRequest];
        case FLConversationFieldMessages:
            return [self getMessageSyncRequest];
        default: assert(NO);
    };
}

- (void)fillGapFromMessageNr:(NSInteger)messageNr directionBefore:(BOOL)before
{
    [self setLoadRequest:before ? FLConversationLoadMessagesBefore :
        FLConversationLoadMessagesAfter messageNr:messageNr];
}

- (FLApiRequest*)getSyncRequest
{
    FLApiRequest* request = [super getSyncRequest];
    if (request != nil) {
        return request;
    }

    if (_loadRequest != nil) {
        switch (_loadRequest.type) {
            case FLConversationLoadMessages:
                request = [self getMessageLoadRequest];
                break;
            case FLConversationLoadFiles:
                request = [self getFileLoadRequest];
                break;
            case FLConversationLoadPins:
                request = [self getPinLoadRequest];
                break;
            case FLConversationLoadContext:
                request = [self getContextLoadRequestAroundMessageNr:_loadRequest.messageNr];
                break;
            case FLConversationLoadMessagesAfter:
                request = [self getFillGapRequestBefore:NO messageNr:_loadRequest.messageNr];
                break;
            case FLConversationLoadMessagesBefore:
                request = [self getFillGapRequestBefore:YES messageNr:_loadRequest.messageNr];
                break;
            default:
                break;
        }
    } else {
        if (self.needsMessageLoad) {
            request = [self getMessageLoadRequest];
        }
    }

    if ((request != nil) && (_loadRequest != nil)) {
        request.priority = FLApiRequestPriorityHigher;
    }

    request.successHandler = ^(void) {
        [self willChangeValueForKey:@"isLoading"];
        [self willChangeValueForKey:@"loadRequest"];
        _loadRequest = nil;
        [self didChangeValueForKey:@"loadRequest"];
        [self didChangeValueForKey:@"isLoading"];
    };

    return request;
}

- (void)resendNextPendingMessage
{
    if ((_resendingMessages == nil) || (_resendingMessages.count == 0)) {
        return;
    }

    Message* message = _resendingMessages[0];
    FLCompletionHandlerWithNr onCompletion = ^(NSInteger messageNr) {
        [message deletePending];
        [_resendingMessages removeObjectAtIndex:0];
        if (_resendingMessages.count == 0) {
            _resendingMessages = nil;
        } else {
            [self resendNextPendingMessage];
        }
    };

    FLErrorHandler onError =^(NSError* error) {
        for (Message* m in _resendingMessages) {
            [m setSending:NO notify:YES];
        }
        _resendingMessages = nil;
    };

    if ([message isOfType:FLMessageTypeText]) {
        NSString* rawMessage = [[FLMessageStripper alloc] initWithMessage:message.message].plainTextWithMarkup;

        [[FLApi api] postMessage:rawMessage andFiles:nil intoConversationWithId:self.conversation_id
            onSuccess:onCompletion onError:onError];
    }

    if ([message isOfType:FLMessageTypeFile]) {
        NSMutableDictionary* fileDict = [@{ @"file_id" : message.representation.fileId } mutableCopy];
        if ((message.representation.imageSize.width * message.representation.imageSize.height) > 0.0f) {
            fileDict[@"width"] = [NSNumber numberWithInteger:(NSInteger)message.representation.imageSize.width];
            fileDict[@"height"] = [NSNumber numberWithInteger:(NSInteger)message.representation.imageSize.height];
        }

        [[FLApi api] postFiles:@[fileDict] toConversationWithId:self.conversation_id
            onSuccess:onCompletion onError:onError];
    }
}

- (void)resendMessage:(Message *)message
{
    assert([message isOfType:FLMessageTypeText] || [message isOfType:FLMessageTypeFile]);
    if ([message isSending]) {
        return;
    }

    if ((_resendingMessages != nil) && ([_resendingMessages containsObject:message])) {
        return;
    }

    if (_resendingMessages == nil) {
        _resendingMessages = [[NSMutableArray alloc] init];
    }

    [message setSending:YES notify:YES];
    [_resendingMessages addObject:message];
    if (_resendingMessages.count == 1) {
        [self resendNextPendingMessage];
    }
}

@end
