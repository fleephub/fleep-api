//
//  FLDataModel.m
//  Fleep
//
//  Created by Erik Laansoo on 19.02.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLDataModel.h"
#import "FLDataModelInternal.h"
#import "FLApi.h"
#import "FLApiInternal.h"
#import "FLApiRequest.h"
#import "FLApi+Actions.h"
#import "FLApiWithLocalStorage.h"
#import "FLClassificators.h"
#import "ConversationInternal.h"
#import "FLNetworkOperations.h"
#import "FLConversationLists.h"
#import "FLUserProfile.h"

FLDataModel* _dataModel;

@interface FLConversationLists (Internal)
- (void)updateFilteredListsWithChanges:(NSDictionary*)changes;
- (void)notifyContactsChanged:(NSSet*)changedContacts;
@end

@interface FLUserProfile (Internal)
- (void)notifyContactsChanged:(NSSet*)changedContacts;
@end

@implementation FLDataModel
{
    BOOL _syncFullHistory;
// Core data
    NSManagedObjectModel* _managedObjectModel;
    NSManagedObjectContext* _managedObjectContext;
    NSPersistentStoreCoordinator* _persistentStoreCoordinator;

// Maintained lists
    NSMutableDictionary* _contacts;
    NSMutableDictionary* _hooks;
    NSMutableDictionary* _contactsByEmail;
    NSMutableDictionary* _conversations;
    NSMutableDictionary* _teams;

    NSInteger _syncBaseline;
    NSMutableDictionary* _changedConversations;
    NSMutableSet* _changedContacts;
    NSMutableDictionary* _fetchRequests;
    NSMutableDictionary* _predicates;
    Conversation* _newConversation;
    float _syncProgress;
}

@synthesize contacts = _contacts;
@synthesize conversations = _conversations;
@synthesize syncProgress = _syncProgress;

- (BOOL)syncFullHistory
{
    return _syncFullHistory;
}

- (void)setSyncFullHistory:(BOOL)syncFullHistory
{
    _syncFullHistory = syncFullHistory;
    [[NSUserDefaults standardUserDefaults] setBool:_syncFullHistory forKey:@"SyncFullHistory"];
    if (_syncFullHistory) {
        [self synchronizeAllConversations];
    }
}

- (NSArray*)fetchObjects:(NSString*)entityName withPredicate:(NSString*)predicate
    arguments:(NSDictionary*)arguments
{
    NSFetchRequest* fr = _fetchRequests[entityName];
    if (fr == nil) {
        fr = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:entityName
            inManagedObjectContext:_managedObjectContext];
    
        [fr setEntity:entity];

        _fetchRequests[entityName] = fr;
    }

    NSPredicate* pred = nil;
    if (predicate != nil) {
        pred = _predicates[predicate];
        if (pred == nil) {
            pred = [NSPredicate predicateWithFormat:predicate];
            _predicates[predicate] = pred;
        }

        if (arguments != nil) {
            pred = [pred predicateWithSubstitutionVariables:arguments];
        }

        [fr setPredicate:pred];
    }

    NSError* error = nil;
    NSArray* result = [_managedObjectContext executeFetchRequest:fr error:&error];
    if (error != nil) {
        FLLogError(@"Fetch %@ (%@, %@): %@", entityName, predicate, arguments, error);
        return nil;
    }
    return result;

}

- (NSArray*)fetchObjects:(NSString*)entityName
{
    return [self fetchObjects:entityName withPredicate:nil arguments:nil];
}

- (NSManagedObjectContext*)managedObjectContext
{
    return _managedObjectContext;
}

- (NSManagedObjectModel*) managedObjectModel
{
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator*)persistentStoreCoordinator
{
    return _persistentStoreCoordinator;
}

- (NSError*)createPersistentStoreCoordinator
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL *storeURL = [self repositoryURL];

    if (![fm fileExistsAtPath:storeURL.path]) {
        [FLApi api].eventHorizon = 0;
    }

    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        return error;
    }

    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:_persistentStoreCoordinator];

    return nil;
}

- (id)init
{
    assert(_dataModel == nil);
    if (self = [super init]) {

        NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Fleep" withExtension:@"momd"];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        NSError* error = [self createPersistentStoreCoordinator];
        if (error != nil) {
            FLLogError(@"Error initializing datastore: %@, deleting local db", error);
            [self deleteDatastore];
        }

        if (_persistentStoreCoordinator == nil) {
            FLLogError(@"Failed to open datastore, terminating application");
            abort();
        }

        _fetchRequests = [[NSMutableDictionary alloc] init];
        _predicates = [[NSMutableDictionary alloc] init];

        _dataModel = self;

        // Load repository data
        NSArray* allContacts = [self fetchObjects:@"Contact"];
        _contacts = [[NSMutableDictionary alloc] init];
        _contactsByEmail = [[NSMutableDictionary alloc] init];
        for (Contact* c in allContacts) {
            [_contacts setObject:c forKey:c.account_id];
            [_contactsByEmail setObject:c forKey:[c.email lowercaseString]];
        }
        FLLogInfo(@"Loaded %ld Contact objects", (long)_contacts.count);

        NSArray* allConversations = [self fetchObjects:@"Conversation"];
        NSMutableDictionary* conversations = [[NSMutableDictionary alloc] init];
        for (Conversation* c in allConversations) {
            if ([c.conversation_id isEqualToString:NEW_CONVERSATION_ID]) {
                continue;
            }
            [conversations setObject:c forKey:c.conversation_id];
        }
        _conversations = conversations;
        FLLogInfo(@"Loaded %ld Conversation objects", (long)_conversations.count);

        NSArray* hooks = [self fetchObjects:@"Hook"];
        _hooks = [[NSMutableDictionary alloc] init];
        for (Hook* h in hooks) {
            _hooks[h.hook_key] = h;
        }
        FLLogInfo(@"Loaded %ld Hook objects", (long)_hooks.count);

        NSArray* teams = [self fetchObjects:@"Team"];
        _teams = [[NSMutableDictionary alloc] init];
        for (Team* t in teams) {
            _teams[t.team_id] = t;
        }
        FLLogInfo(@"Loaded %ld Team objects", (long)_teams.count);

        _syncFullHistory = [[NSUserDefaults standardUserDefaults] boolForKey:@"SyncFullHistory"];

        [self performSelector:@selector(synchronizeAllConversations) withObject: nil afterDelay: 0.5f];
        [self updateSyncProgress];
    }

    return self;
}

- (FLMessageArray*) loadMessagesFromConversation:(Conversation*)conversation from:(NSInteger)from to:(NSInteger)to
{
    NSArray* result = [self fetchObjects:@"Message"
        withPredicate:@"(conversation_id = $id) and (message_nr >= $from) and (message_nr <= $to)"
        arguments: @{
            @"id": conversation.conversation_id,
            @"from": [NSNumber numberWithInteger:from],
            @"to": [NSNumber numberWithInteger:to]}];

    for (Message* m in result) {
        [m setConversation:conversation];
    }

    return [[FLMessageArray alloc] initWithMessages:result order:FLMessageOrderAscending];
}

- (NSInteger) messageNrFromInboxMessageNr:(NSInteger)inboxMessageNr inConversation:(Conversation*)conversation
{
    NSArray* result = [self fetchObjects:@"Message"
        withPredicate:@"(conversation_id = $id) and (inbox_nr == $inbox_nr)"
        arguments: @{
            @"id": conversation.conversation_id,
            @"inbox_nr": @(inboxMessageNr)}];

    if (result.count < 1) {
        return 0;
    };

    Message* m = result.lastObject;
    return m.message_nr.integerValue;
}

- (FLMessageArray*) loadRecentMessagesInConversation:(Conversation*)conversation
{
    NSInteger firstNr = [self messageNrFromInboxMessageNr:MAX(conversation.last_inbox_nr.integerValue - 10, 0)
        inConversation:conversation];
    firstNr = MAX(firstNr, conversation.bw_message_nr.integerValue);
    firstNr = MIN(firstNr, conversation.read_message_nr.integerValue);
    NSInteger lastNr = conversation.last_message_nr.integerValue;
    if (conversation.pending_message_nr != nil) {
        lastNr = MAX(lastNr, conversation.pending_message_nr.integerValue);
    }
    return [self loadMessagesFromConversation:conversation from:firstNr to:lastNr];
}

- (Message*) uncommittedMessageInConversation:(NSString*)conversationId
{
    NSArray* result = [self fetchObjects:@"Message"
        withPredicate:@"(conversation_id = $id) and (uncommitted_fields > 0)"
        arguments: @{ @"id": conversationId}];

    return result.lastObject;
}

- (FLMessageArray*) loadFileMessagesFromConversation:(Conversation*)conversation
{
    NSArray* result = [self fetchObjects: @"Message"
        withPredicate:@"(conversation_id = $id) and (mk_message_type = $type)"
        arguments: @{
            @"id": conversation.conversation_id,
            @"type": @(FLMessageTypeFile)
    }];

    for (Message* m in result) {
        [m setConversation:conversation];
    }
    return [[FLMessageArray alloc] initWithMessages:result order:FLMessageOrderDescending];
}

- (FLMessageArray*) loadPinnedMessagesFromConversation:(Conversation*)conversation
{
    NSArray* result = [self fetchObjects:@"Message"
        withPredicate:@"(conversation_id = $id) and (pin_weight > 0)"
        arguments: @{
            @"id": conversation.conversation_id
    }];

    for (Message* m in result) {
        [m setConversation:conversation];
    }
    return [[FLMessageArray alloc] initWithMessages:result order:FLMessageOrderPinWeight];
}

- (void)updateSyncProgress
{
    NSInteger totalMessagesToLoad = 0;
    NSInteger totalMessagesLoaded = 0;
    for (Conversation* c in _conversations.allValues) {
        totalMessagesToLoad += c.numberOfLocalMessagesRequired;
        totalMessagesLoaded += MIN(c.numberOfLocalMessagesPresent, c.numberOfLocalMessagesRequired);
    }

    if (totalMessagesLoaded >= totalMessagesToLoad) {
        _syncBaseline = totalMessagesToLoad;
    }

    totalMessagesToLoad -= _syncBaseline;
    totalMessagesLoaded -= _syncBaseline;

    [self willChangeValueForKey:@"syncProgress"];
    if (totalMessagesToLoad < 20) {
        _syncProgress = 1.0f;
    } else {
        _syncProgress = (float)totalMessagesLoaded / (float)totalMessagesToLoad;
    }
    if (_syncProgress < 1.0f) {
        FLLogDebug(@"FLDataModel: SyncProgress = %f", _syncProgress);
    }
    
    [self didChangeValueForKey:@"syncProgress"];
}

+ (FLDataModel*) dataModel
{
    assert(_dataModel != nil);
    return _dataModel;
}

- (void)dealloc
{
    FLLogInfo(@"FLDataModel: dealloc");
}

- (NSManagedObject*)updateObject:(NSManagedObject<JsonSerialization>*)object fromJson:(FLJsonParser*)json error:(NSError**)error
{
    assert(self.inTransaction);
    
    NSError* err = [object updateFromJson:json];
    if (err == nil) {
        [object validateForUpdate:error];
    }
            
    if ((error != nil) && (err != nil)) {
        *error = err;
    }
    
    return object;
}

- (NSManagedObject*)createObjectOfClass:(NSString*)class
{
    return [NSEntityDescription
        insertNewObjectForEntityForName:class
        inManagedObjectContext:_managedObjectContext];
}

- (void)deleteObject:(NSManagedObject*)object
{
    [_managedObjectContext deleteObject:object];
}

- (NSManagedObject*)insertObjectOfClass:(NSString*) class fromJson:(FLJsonParser*)json error:(NSError**)error
{
    assert(self.inTransaction);
    
    NSManagedObject<JsonSerialization>* newObject = (NSManagedObject<JsonSerialization>*)[self createObjectOfClass:class];

    NSError* err = nil;
    if (newObject == nil) {
        err = [FLError errorWithCode:FLEEP_ERROR_TECH_FAILURE andUserInfo:
            @{@"message": @"InsertNewObject failed", @"class":class, @"json": json}];
    }

    if ((err == nil) && (json != nil)) {
        err = [newObject deserializeFromJson:json];
    }
    if (err == nil) {
        [newObject validateForInsert:&err];
    }
    if (err == nil) {
        return newObject;
    } else {
        [_managedObjectContext deleteObject:newObject];
        if (error != nil) {
            *error = err;
        }
        return nil;
    }
}

- (Conversation*)conversationChangedWithId:(NSString*)conversationId
{
    Conversation* res;
    if (_changedConversations != nil) {
        res = [_changedConversations objectForKey:conversationId];
        if (res != nil) {
            return res;
        }
    }

    res = [self conversationFromId:conversationId];
    if (res != nil) {
        [self conversationChanged:res];
    }

    return res;
}

- (void)conversationChanged:(Conversation*)conv
{
    static BOOL inCommit = NO;

    if (inCommit) {
        return;
    }

    if (_changedConversations != nil) {
        [_changedConversations setObject:conv forKey:conv.conversation_id];
    } else {
        inCommit = YES;
        @try {
            [conv commitChanges];
        } @finally {
            inCommit = NO;
        }
        if (_conversations != nil) {
            [[FLConversationLists conversationLists] updateFilteredListsWithChanges: @{conv.conversation_id : conv }];
        }
        if (conv.needsSync) {
            [[FLApiWithLocalStorage apiWithLocalStorage]synchronizeConversation:conv];
            [self updateSyncProgress];
        }
    }
}

- (void)deleteMessagesFromConversation:(NSString*)conversationId
{
    NSArray* messages = [self fetchObjects:@"Message"
        withPredicate:@"(conversation_id = $id)"
        arguments: @{
            @"id": conversationId
    }];

    for (Message* m in messages) {
        [_managedObjectContext deleteObject:m];
    }
}

- (Conversation*) conversationFromJson:(FLJsonParser*) json isNew:(BOOL)isNew error:(NSError**)error
{
    NSString* conversationId = [json extractString:@"conversation_id"];
    BOOL isDeleted = [json extractBool:@"is_deleted" defaultValue:NO].boolValue;

    if (conversationId == nil) {
        return nil;
    }

    Conversation* c = [self conversationChangedWithId:conversationId];

    if (isDeleted) {
        if (c == nil) {
            return nil;
        }

        [_conversations removeObjectForKey:conversationId];
        [_managedObjectContext deleteObject:c];
        [self deleteMessagesFromConversation:conversationId];
        [c willChangeValueForKey:@"isDeleted"];
        [c didChangeValueForKey:@"isDeleted"];
        return nil;
    }

    if (c != nil) {
        [self updateObject:c fromJson:json error:error];
    } else {
        if (isNew && (_newConversation != nil)) {
            c = _newConversation;
            _newConversation = nil;
            NSError* err = [c deserializeFromJson:json];
            if (err == nil) {
                [c validateForInsert:&err];
            }

            if (err != nil) {
                if (error != nil) {
                    *error = err;
                }
                return nil;
            }

            for (Message* m in c.messages) {
                m.conversation_id = c.conversation_id;
            }

        } else {
            c = (Conversation*)[self insertObjectOfClass:@"Conversation" fromJson:json error:error];
        }

        if (c != nil) {
            _conversations[conversationId] = c;
            [self conversationChanged:c];
            if ((c.bw_message_nr != nil) && (c.fw_message_nr != nil)) {
                // Prepare message cache for populating messages
                [c loadMessageCacheRange:NSMakeRange(c.bw_message_nr.integerValue,
                    c.fw_message_nr.integerValue - c.bw_message_nr.integerValue)];
            }
        }
    }

    return c;
}

- (Conversation*) conversationFromId:(NSString*)convId
{
    assert(_conversations != nil);

    Conversation* result = _conversations[convId];
    if (result != nil) {
        return result;
    }

    if ([convId rangeOfString:@"@"].location != NSNotFound) {
        return [self dialogWithContact:convId];

    }

    if ([convId isEqualToString:NEW_CONVERSATION_ID]) {
        return _newConversation;
    }

    return nil;
}

- (Contact*) contactFromJson:(FLJsonParser*)json error:(NSError**)error
{
    NSString* accountId = [json extractString:@"account_id"];
    BOOL isDeleted = [json extractBool:@"is_deleted" defaultValue:NO].boolValue;
    if (accountId == nil) {
        return nil;
    }

    Contact* c = _contacts[accountId];
    if (isDeleted) {
        if (c == nil) {
            return nil;
        }

        [_contacts removeObjectForKey:accountId];
        [_contactsByEmail removeObjectForKey:[c.email lowercaseString]];
        [_managedObjectContext deleteObject:c];
        return nil;
    }

    if (c != nil) {
        [self updateObject:c fromJson:json error:error];
    } else {
        c = (Contact*)[self insertObjectOfClass:@"Contact" fromJson:json error:error];
        if (c != nil) {
            _contacts[c.account_id] = c;
            _contactsByEmail[[c.email lowercaseString]] = c;
        }
    }

    if (*error != nil) {
        return nil;
    }
    
    [c awakeFromFetch];
    if (_changedContacts == nil) {
        _changedContacts = [[NSMutableSet alloc] init];
    }
    [_changedContacts addObject:c.account_id];
    return c;
}

- (Contact*)contactFromEmail:(NSString *)email withUUID:(NSString *)uuid
{
    Contact* c = [self contactFromId:uuid];
    if (c != nil) {
        return c;
    }
    
    c = (Contact*)[self createObjectOfClass:@"Contact"];

    if (c != nil) {
        c.account_id = uuid;
        c.email = [email lowercaseString];
        c.is_hidden_for_add = [NSNumber numberWithBool:YES];
        c.mk_account_status = [NSNumber numberWithInteger:FLAccountStatusActive];
        _contacts[uuid] = c;
        _contactsByEmail[email] = c;
    }

    return c;
}

- (Contact*) contactFromId:(NSString*)contactId
{
    return [_contacts objectForKey:contactId];
}

- (Contact*) contactFromEmail:(NSString *)email
{
    assert([FLApi api].loginStatus == FLApiLoginStatusLoggedIn);
    return [_contactsByEmail objectForKey:[email lowercaseString]];
}

- (Hook*)hookFromJson:(FLJsonParser *)json error:(NSError **)error
{
    NSString* hookKey = [json extractString:@"hook_key"];
    if (hookKey == nil) {
        return nil;
    }

    Hook* h = _hooks[hookKey];
    if (h != nil) {
        [self updateObject:h fromJson:json error:error];
    } else {
        h = (Hook*)[self insertObjectOfClass:@"Hook" fromJson:json error:error];
        if (h != nil) {
            _hooks[h.hook_key] = h;
        }
    }
    return h;
}

- (Team*)teamFromJson:(FLJsonParser *)json error:(NSError **)error
{
    NSString* teamId = [json extractString:@"team_id"];
    if (teamId == nil) {
        return nil;
    }

    Team* t = _teams[teamId];
    if (t != nil) {
        [self updateObject:t fromJson:json error:error];
    } else {
        t = (Team*)[self insertObjectOfClass:@"Team" fromJson:json error:error];
        if (t != nil) {
            _teams[t.team_id] = t;
        }
    }
    return t;
}

- (Team*)teamFromId:(NSString *)teamId
{
    return _teams[teamId];
}

- (NSString*)hookName:(NSString *)hookKey
{
    Hook* h = _hooks[hookKey];
    if (h == nil) {
        return @"?";
    }

    return h.hook_name.length > 0 ?
        h.hook_name : [self fullNameOfContact:h.account_id];
}

- (Hook*)hookFromId:(NSString *)hookId
{
    return _hooks[hookId];
}

- (Message*) messageFromJson:(FLJsonParser*)json error:(NSError**)error
{
    NSString* conversationId = [json extractString:@"conversation_id"];
    NSNumber* messageNr = [json extractInt:@"message_nr"];
    BOOL isDeleted = [json extractBool:@"is_deleted" defaultValue:NO].boolValue;

    if ((conversationId == nil) || (messageNr == nil)) {
        return nil;
    }

    Conversation* conv = [self conversationChangedWithId:conversationId];

    if (isDeleted) {
        [conv deleteMessageNr:messageNr.integerValue];
        return nil;
    }

    NSNumber* flow_message_nr = [json extractInt:@"flow_message_nr" defaultValue:nil];
//    NSNumber* messageType = [Message extractMessageType:obj];
    NSInteger tags = [Message extractMessageTags:json];
//    NSNumber* searchWeight = [obj extractInt:@"search_weight" usingDefault:nil];

    BOOL isFragment = ([json extractString:@"mk_message_type" defaultValue:nil] == nil) ||
      ([json extractString:@"message" defaultValue:nil] == nil);
//    BOOL isFileOrPin = (messageType.integerValue == FLMessageTypeFile) ||
//        ((tags & (MESSAGE_TAG_PIN | MESSAGE_TAG_UNPIN)) != 0);

    if (json.error != nil) {
        if (error != nil) {
            *error = json.error;
        }
        return nil;
    }

/*
    if (!isFileOrPin && (searchWeight == nil) && (conv.bw_message_nr != nil) && (conv.bw_message_nr.integerValue > messageNr.integerValue)) {
        // Discard text messages outside sync range
        return nil;
    }
*/

    Message* result = [conv messageByNumber:messageNr.integerValue searchOutsideSyncRange:YES];
    if (result == nil) {
        if (isFragment) {
            FLLogWarning(@"Message fragment with no corresponding message: %@", json);
            return nil;
        }

        NSError* err = nil;
        result = (Message*)[self insertObjectOfClass:@"Message" fromJson:json error:&err];
        if (err == nil) {
            [[FLApi api].sessionStats reportReceivedMessage];
            [[FLApi api].cumulativeStats reportReceivedMessage];
        } else {
            if (error != nil) {
                *error = err;
            }
        }
    } else {
        [self updateObject:result fromJson:json error:error];
    }

    if ((error != nil) && (*error != nil)) {
        [[FLErrorLog errorLog] logMessage:[NSString stringWithFormat:@"ConversationFromJson: %@ => %@", json, *error]];
    }
    
    if (result != nil) {
        [result setConversation:conv];
        [result awakeFromFetch];
        [conv addMessage:result];
        if (flow_message_nr != nil) {
            [conv encounteredMessageNr:flow_message_nr.integerValue];
        }

        if (result.isUnpin) {
            NSNumber* ref_message_nr = [json extractInt:@"ref_message_nr" defaultValue:nil];
            if (ref_message_nr != nil) {
                Message* pinMessage = [conv messageByNumber:ref_message_nr.integerValue searchOutsideSyncRange:YES];
                if (pinMessage != nil) {
                    [conv deletePinnedMessage:pinMessage];
                }
            }
        }

        if (tags & MESSAGE_TAG_UNLOCK) {
            [conv updateActivityBy:@"" writing:NO messageNr:messageNr.integerValue];
        }
    }

    return result;
}

- (Message*) messageFromId:(NSString*)conversationId atIndex:(NSInteger)index
{
    NSArray* res = [self fetchObjects:@"Message"
        withPredicate:@"(conversation_id = $id) and (message_nr = $message_nr)"
        arguments: @{
            @"id": conversationId,
            @"message_nr": [NSNumber numberWithInteger: index]
    }];

    if (res.count > 0) {
        return [res objectAtIndex:0];
    } else {
        return nil;
    }
}

- (Message*) messageFromId:(NSString*)conversationId atInboxIndex:(NSInteger)inboxIndex
{
    NSArray* res = [self fetchObjects:@"Message"
        withPredicate:@"(conversation_id = $id) and (inbox_nr = $inbox_nr)"
        arguments: @{
            @"id": conversationId,
            @"inbox_nr": [NSNumber numberWithInteger: inboxIndex]
    }];

    if (res.count > 0) {
        return [res objectAtIndex:0];
    } else {
        return nil;
    }
}

- (Member*) memberFromConversation:(Conversation*)conversation withAccountId:(NSString*)accountId
{
    Member* result = (Member*)[self createObjectOfClass:@"Member"];
    result.conversation = conversation;
    result.account_id = accountId;

    NSError* error = nil;
    [result validateForInsert:&error];

    if (error == nil) {
        [result awakeFromFetch];
    } else {
        return nil;
    }
    return result;
}

- (NSString*) fullNameOfContact:(NSString*)contactId
{
    Contact* c = [self contactFromId:contactId];
    if (c != nil) {
        return c.displayName;
    } else {
        FLLogWarning(@"Unknown contact id: %@", contactId);
        [[FLApiWithLocalStorage apiWithLocalStorage]synchronizeContactWithId:contactId];
        return @"?";
    }
}

- (NSString*) shortNameOfContact:(NSString*)contactId
{
    Contact* c = [self contactFromId:contactId];
    if (c != nil) {
        return c.shortName;
    } else {
        FLLogWarning(@"Unknown contact id: %@", contactId);
        [[FLApiWithLocalStorage apiWithLocalStorage]synchronizeContactWithId:contactId];
        return @"?";
    }
}

- (NSString*) initialsOfContact:(NSString*)contactId
{
    if (contactId == nil) {
        return @"?";
    }
    
    NSString* fn = [self fullNameOfContact:contactId];
    NSMutableString* res = [[NSMutableString alloc]init];
    NSArray* components = [fn componentsSeparatedByString:@" "];
    for (NSString* c in components) {
        [res appendString:[c substringToIndex:1]]; // @todo
    }
    return res;
}

- (void)startTransaction
{
    assert(_changedConversations == nil);
    _changedConversations = [[NSMutableDictionary alloc] init];
}

- (void)synchronizeConversations:(NSArray*)conversations
{
    if ([FLApi api].loginStatus != FLApiLoginStatusLoggedIn) {
        return;
    }

    for (Conversation* c in conversations) {
        if (c.needsSync) {
            [[FLApiWithLocalStorage apiWithLocalStorage]synchronizeConversation:c];
        }
    }
}

- (void)endTransaction
{
    assert(_changedConversations != nil);

    if (_changedContacts != nil) {
        for (Conversation* c in _conversations.allValues) {
            [c notifyContactChange:_changedContacts];
        }
        [[FLUserProfile userProfile]notifyContactsChanged:_changedContacts];
        [[FLConversationLists conversationLists]notifyContactsChanged:_changedContacts];
    }

    _changedContacts = nil;

    [self performSelector:@selector(synchronizeConversations:) withObject:_changedConversations.allValues afterDelay:0.1f];
    for (Conversation* c in _changedConversations.allValues) {
        [c commitChanges];
    }

    [[FLConversationLists conversationLists] updateFilteredListsWithChanges:_changedConversations];
    [self updateSyncProgress];
    
    _changedConversations = nil;
    [self saveContext];
}

-(BOOL)inTransaction
{
    return _changedConversations != nil;
}

- (void)saveContext
{
    assert(_managedObjectContext != nil);
    NSError *error = nil;
    if ([_managedObjectContext hasChanges] && ![_managedObjectContext save:&error]) {

        FLLogError(@"Error saving managed object context %@, %@", error, [error userInfo]);
        abort();
    }
    [[FLNetworkOperations networkOperations] saveState];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[FLErrorLog errorLog] flush];
}

- (void)deleteDatastore
{
    FLLogWarning(@"DeleteDataStore called");
    
    _managedObjectContext = nil;
    _persistentStoreCoordinator = nil;

    [FLApi api].eventHorizon = 0;
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSError* error;
    NSURL *storeURL = [self repositoryURL];
    NSFileManager* fm = [NSFileManager defaultManager];

    [fm removeItemAtURL:storeURL error:&error];
    if (error != nil) {
        FLLogError(@"Error deleting datastore: %@", error);
    }

    error = [self createPersistentStoreCoordinator];
    if (error != nil) {
        FLLogError(@"Error opening datastore: %@", error);
        [[NSNotificationCenter defaultCenter] postNotificationName:FLEEP_NOTIFICATION_FATAL_ERROR object:error];
    }
}

- (Conversation*) createNewConversation
{
    NSArray* conversations = [self fetchObjects:@"Conversation"
        withPredicate:@"conversation_id = $id"
        arguments:@{
            @"id" : NEW_CONVERSATION_ID
    }];

    if (conversations.count > 0) {
        for (Conversation* c in conversations) {
            [_managedObjectContext deleteObject:c];
        }
        [self saveContext];
    } 

    _newConversation = nil;
    Conversation* c = [NSEntityDescription
        insertNewObjectForEntityForName:@"Conversation"
        inManagedObjectContext:_managedObjectContext];

    if (c == nil) {
        FLLogError(@"FleepDataModel::createNewConversation : InsertNewObject failed");
        return nil;
    }

    c.conversation_id = NEW_CONVERSATION_ID;
    c.can_post = [NSNumber numberWithBool:YES];
    c.join_message_nr = [NSNumber numberWithInteger:0];
    c.last_message_nr = [NSNumber numberWithInteger:0];

    Contact* localContact = [self contactFromId:[FLUserProfile userProfile].contactId];
    [c.sortedMembers add:localContact.email name:nil];
    [c awakeFromFetch];
    _newConversation = c;
    return c;
}

- (Conversation*) cloneConversation:(Conversation*)c
{
    Conversation* newConversation = [self createNewConversation];
    for (FLMember* m in c.sortedMembers) {
        if (!m.isLocalContact) {
            [newConversation.sortedMembers add:m.email name:m.displayName];
        }
    };
    return newConversation;
}

- (Conversation*) dialogWithContact:(NSString*)email
{
    assert(email != nil);
    Contact* contact = [self contactFromEmail:email];
    if ((contact != nil) && (contact.dialog_id != nil)) {
        Conversation* c = [self conversationFromId:contact.dialog_id];
        if (c != nil) {
            return c;
        }
    }

    for (Conversation* c in [_conversations allValues]) {
        if (c.members.count > 2) {
            continue;
        }
        if (c.topic.length > 0) {
            continue;
        }

        BOOL containsSelf = [c containsMemberWithId:[FLUserProfile userProfile].contactId];
        BOOL containsPartner = [c containsMemberWithEmail:email];

        if (containsSelf && containsPartner) {
            return c;
        }
    }

    Conversation* c = [self createNewConversation];
    [c.sortedMembers add:email name:nil];
    [c commitChanges];
    return c;
}

- (void)synchronizeAllConversations
{
    if ([FLApi api].loginStatus != FLApiLoginStatusLoggedIn) {
        return;
    }

    for (Conversation* c in [_conversations allValues]) {
        if (c.needsSync) {
            [[FLApiWithLocalStorage apiWithLocalStorage]synchronizeConversation:c];
        }
    }
}

- (void)logout
{
    [self deleteDatastore];
    _dataModel = nil;
}

- (NSString*)techInfo
{
    NSMutableString* result = [[NSMutableString alloc] init];
    [result appendFormat:@"Data model status:\n"];
    [result appendFormat:@"Conversations: %ld, contacts: %ld\n", (long)_conversations.count,
        (long)_contacts.count];
    [result appendFormat:@"Event horizon: %ld\n\n", (long)[FLApi api].eventHorizon];
    NSArray* tables = @[@"Contact", @"Conversation", @"Member", @"Message"];
    for (NSString* t in tables) {
        NSFetchRequest* fr = [[NSFetchRequest alloc] initWithEntityName:t];
        fr.resultType = NSCountResultType;
        NSError* e = nil;
        NSArray* r = [_managedObjectContext executeFetchRequest:fr error:&e];
        if (e != nil) {
            [result appendFormat: @"%@ : %@\n", t, e.localizedDescription];
        } else {
            NSNumber* c = r[0];
            [result appendFormat: @"%@ : %ld rows\n", t, (long)c.integerValue];
        }
    }
    
    return result;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)repositoryURL
{
#ifdef TARGET_IS_IPHONE
    NSURL* documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
    return [documentsDirectory URLByAppendingPathComponent:@"Fleep.sqlite"];
#else
    NSString *path = [[NSProcessInfo processInfo] arguments][0];
    path = [path stringByDeletingPathExtension];
    return [NSURL fileURLWithPath:[path stringByAppendingPathExtension:@"sqlite"]];
#endif
}

@end
