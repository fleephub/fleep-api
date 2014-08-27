#define NEW_CONVERSATION_ID @"new"

@interface FLDataModel (Internal)
@property (readonly) BOOL inTransaction;

- (NSManagedObject*)createObjectOfClass:(NSString*)class;
- (void)deleteObject:(NSManagedObject*)object;
- (Member*) memberFromConversation:(Conversation*)conversation withAccountId:(NSString*)accountId;
- (FLMessageArray*) loadMessagesFromConversation:(Conversation*)conversation from:(NSInteger)from to:(NSInteger)to;
- (NSInteger) messageNrFromInboxMessageNr:(NSInteger)inboxMessageNr inConversation:(Conversation*)conversation;
- (FLMessageArray*) loadRecentMessagesInConversation:(Conversation*)conversation;
- (FLMessageArray*) loadFileMessagesFromConversation:(Conversation*)conversation;
- (FLMessageArray*) loadPinnedMessagesFromConversation:(Conversation*)conversation;
- (void)conversationChanged:(Conversation*)conv;
- (Conversation*)conversationChangedWithId:(NSString*)conversationId;
- (void)startTransaction;
- (void)endTransaction;
- (NSString*)techInfo;
- (Conversation*) conversationFromJson:(FLJsonParser*) json isNew:(BOOL)isNew  error:(NSError**)error;
- (Contact*) contactFromJson:(FLJsonParser*)json error:(NSError**)error;
- (Contact*) contactFromEmail:(NSString*)email withUUID:(NSString*)uuid;
- (Message*) messageFromJson:(FLJsonParser*)json error:(NSError**)error;
- (Message*) messageFromId:(NSString*)conversationId atIndex:(NSInteger)index;
- (Message*) messageFromId:(NSString*)conversationId atInboxIndex:(NSInteger)inboxIndex;
- (Hook*) hookFromJson:(FLJsonParser*) json error:(NSError**)error;
- (Team*) teamFromJson:(FLJsonParser*) json error:(NSError**)error;
- (NSString*)hookName:(NSString*)hookKey;
- (Message*) uncommittedMessageInConversation:(NSString*)conversationId;
- (void)synchronizeAllConversations;
- (void)logout;
@end