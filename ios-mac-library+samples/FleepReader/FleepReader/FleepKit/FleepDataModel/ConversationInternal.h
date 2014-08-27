#define PENDING_MESSAGE_BASE 1000000000

@interface Conversation (Internal)
@property (readonly) NSInteger numberOfLocalMessagesRequired;
@property (readonly) NSInteger numberOfLocalMessagesPresent;

- (void)setInboxMessageNr:(NSInteger)inboxMessageNr;
- (void)setUnreadCount:(NSInteger)count;
- (void)updateUnreadCount;
- (void)addMessage:(Message*)message;
- (void)encounteredMessageNr:(NSInteger)messageNr;
- (void)loadMessageCacheRange:(NSRange)range;
- (void)commitChanges;
- (void)deletePinnedMessage:(Message*)message;
- (void)releaseMessages;
- (void)notifyContactChange:(NSSet*)contactIds;
- (void)updateInboxMessage;
- (void)updateTopicNotifyImmediately:(BOOL)notifyImmediately;
- (Message*)createMessageType:(FLMessageType)type body:(NSString*)body;
- (void)deleteMessageNr:(NSInteger)messageNr;
- (void)updateActivityBy:(NSString*)accountId writing:(BOOL)writing
    messageNr:(NSInteger)messageNr;
- (void)notifyFileDeleted:(NSInteger)messageNr;
- (void)addMatchingMessage:(Message*)m;
- (void)commitNewMessages;
- (ConversationWriters*)createWriters;
- (void)resetWriters;
- (void)resendMessage:(Message*)message;
@end