//
//  FLApiWithLocalStorage.m
//  Fleep
//
//  Created by Erik Laansoo on 25.07.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLApiWithLocalStorage.h"
#import "FLApiInternal.h"
#import "FLDataModel.h"
#import "FLApiRequest.h"
#import "FLDataModelInternal.h"
#import "ConversationInternal.h"
#import "FLConversationLists.h"
#import "FLUserProfile.h"

@interface FLMember (SetReadHorizon)
- (void)setReadHorizon:(NSInteger)readHorizon;
@end

@interface FLUserProfile (Internal)
- (void)updateSettings:(FLJsonParser*)json;
- (void)logout;
@end

@implementation FLApiWithLocalStorage
{
    NSMutableSet* _contactsNeedingSync;
}

- (void)startTransaction
{
    if (self.loginStatus == FLApiLoginStatusLoggedIn) {
        [[FLDataModel dataModel] startTransaction];
    }
}

- (void)endTransaction
{
    if (self.loginStatus == FLApiLoginStatusLoggedIn) {
        if ([FLDataModel dataModel].inTransaction) {
            [[FLDataModel dataModel] endTransaction];
        }
    }
}

- (NSError*)handleContact:(FLJsonParser*)contact
{
    NSError* err = nil;
    Contact* c = [[FLDataModel dataModel]contactFromJson:contact error:&err];
    if (c.isLocalContact) {
        [[FLUserProfile userProfile] updateSettings:contact];
    }
    return err;
}

- (NSError*)handleConversation:(FLJsonParser*)conversation isCreateRequest:(BOOL)isCreateRequest
{
    NSError* err = nil;
    [[FLDataModel dataModel]conversationFromJson:conversation isNew:isCreateRequest error:&err];
    return err;
}

- (NSError*)handleConversation:(FLJsonParser *)conversation
{
    return [self handleConversation:conversation isCreateRequest:NO];
}

- (NSError*)handleMessage:(FLJsonParser*)message
{
    NSError* err = nil;
    [[FLDataModel dataModel]messageFromJson:message error:&err];
    return err;
}

- (NSError*)handleHook:(FLJsonParser *)hook
{
    NSError* err = nil;
    [[FLDataModel dataModel]hookFromJson:hook error:&err];
    return err;
}

- (NSError*)handleActivity:(FLJsonParser *)activity
{
    NSString* conversationId = [activity extractString:@"conversation_id"];
    NSString* accountId = [activity extractString:@"account_id"];
    NSNumber* is_writing = [activity extractBool:@"is_writing" defaultValue:NO];
    NSNumber* readMessageNr = [activity extractInt:@"read_message_nr" defaultValue:nil];
    NSNumber* editMessageNr = [activity extractInt:@"edit_message_nr" defaultValue:@(0)];

    if ([[FLUserProfile userProfile] isSelf:accountId]) {
        return nil;
    }

    if (activity.error != nil) {
        return activity.error;
    }

    Conversation* c = [[FLDataModel dataModel] conversationFromId:conversationId];
    if (c == nil) {
        return nil;
    }

    if (readMessageNr != nil) {
        [[FLDataModel dataModel] conversationChanged:c];
        [c willChangeProperties:@[@"memberHorizons"]];
        FLMember* m = [c.sortedMembers memberByAccountId:accountId];
        if (m != nil) {
            [m setReadHorizon: readMessageNr.integerValue];
        }
    }

    [c updateActivityBy:accountId writing:is_writing.boolValue messageNr:editMessageNr.integerValue];
    return nil;
}

- (void)startContactSync
{
    if (_contactsNeedingSync.count == 0) {
        return;
    }

    FLApiRequest *request;

    if (_contactsNeedingSync.count == 1) {
      request = [[FLApiRequest alloc] initWithMethod:@"contact/sync"
        arguments:@{@"contact_id": _contactsNeedingSync.anyObject}];
        request.handler = ^NSError* (FLJsonParser* response) {
            return [self handleContact:response];
        };

    } else {
      request = [[FLApiRequest alloc] initWithMethod:@"contact/sync/list"
        arguments:@{@"contacts": _contactsNeedingSync.allObjects}];
        request.handler = ^NSError* (FLJsonParser* response) {
            NSError* error = nil;
            NSArray* contacts = [response extractObject:@"contacts" class:[NSArray class]];
            if (contacts != nil) {
                for (NSDictionary* contact in contacts) {
                    if (error == nil) {
                        error = [self handleContact:[FLJsonParser jsonParserForObject:contact]];
                    }
                }
            }
            return error;
        };
    }

    request.successHandler = ^void(void) {
        _contactsNeedingSync = nil;
    };

    [self sendRequest:request];
}

- (void)initialSyncCompleted
{
    [super initialSyncCompleted];
    [[FLDataModel dataModel] synchronizeAllConversations];
}

- (void)synchronizeConversation:(Conversation*) conversation
{
    if (self.eventHorizon <= 0) {
        return;
    }

    if (conversation.needsSync) {
        FLApiRequest* syncRequest = [conversation getSyncRequest];
        if (syncRequest != nil) {
            FLCompletionHandler onCompletion = syncRequest.successHandler;
            syncRequest.successHandler = ^(void) {
                if (onCompletion != nil) {
                    onCompletion();
                }

                [self synchronizeConversation:conversation];
            };

            FLErrorHandler onError = syncRequest.errorHandler;
            syncRequest.errorHandler = ^(NSError* error) {
                if (onError != nil) {
                    onError(error);
                }

                [self synchronizeConversation:conversation];
            };

            [self queueRequest:syncRequest name:conversation.conversation_id];
        }
    }
}

- (void)synchronizeContactWithId:(NSString *)contactId
{
    if (_contactsNeedingSync == nil) {
        _contactsNeedingSync = [[NSMutableSet alloc] init];
    }

    if ([_contactsNeedingSync containsObject:contactId]) {
        return;
    }
    
    [_contactsNeedingSync addObject:contactId];
    [self performSelector:@selector(startContactSync) withObject:nil afterDelay:1.0f];
}

+ (FLApiWithLocalStorage*)apiWithLocalStorage
{
    FLApi* api = [FLApi api];
    assert([api isKindOfClass:[FLApiWithLocalStorage class]]);
    return (FLApiWithLocalStorage*)api;
}

- (NSError*)login
{
    FLDataModel* dm = [[FLDataModel alloc] init];
    FLConversationLists* cl = [[FLConversationLists alloc] init];

    if ((dm == nil) || (cl == nil)) {
        return [FLError errorWithCode:FLEEP_ERROR_CORE_DATA_CREATE];
    }

    return [super login];
}

- (void)doLogout
{
    [super doLogout];
    [[FLConversationLists conversationLists] logout];
    [[FLDataModel dataModel] logout];
}

@end
