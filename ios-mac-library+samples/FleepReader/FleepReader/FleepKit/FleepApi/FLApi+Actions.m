//
//  FLApi+Actions.m
//  Fleep
//
//  Created by Erik Laansoo on 07.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLApi.h"
#import "FLApi+Actions.h"
#import "FLApiInternal.h"
#import "FLApiRequest.h"
#import "FLFileUploader.h"
#import "FLNetworkOperations.h"

@interface FLAvatarUploader : FLNetworkOperation
@property (nonatomic, strong) FLCompletionHandler onCompletion;
@property (nonatomic, strong) FLErrorHandler onError;
@property (nonatomic, strong) FLProgressHandler onProgress;
@end

@implementation FLAvatarUploader
{
    FLCompletionHandler _onCompletion;
    FLErrorHandler _onError;
    FLProgressHandler _onProgress;
}

@synthesize onCompletion = _onCompletion;
@synthesize onError = _onError;
@synthesize onProgress = _onProgress;

+ (BOOL)continuesInBackground
{
    return YES;
}

- (id)initWithData:(NSData*)data
{
    if (self = [super init]) {
        NSString* sessionTicket = [FLApi api].credentials.ticket;

        NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"avatar/upload?ticket=%@",
            sessionTicket] relativeToURL:[FLApi api].baseApiURL];
        NSMutableURLRequest* request  = [[NSMutableURLRequest alloc] initWithURL:url
            cachePolicy:NSURLRequestReloadIgnoringCacheData
            timeoutInterval:120.0f];
        request.HTTPMethod = @"PUT";
        request.HTTPBody = data;
        [request addValue: @"attachment; filename=\"avatar.jpg\""
            forHTTPHeaderField:@"Content-Disposition"];
        [self submitRequest:request];
    }
    return self;
}

- (void)uploadProgress:(float)progress
{
    if (_onProgress != nil) {
        _onProgress(progress);
    }
}

- (void)failWithError:(NSError *)error
{
    [super failWithError:error];
    if (_onError != nil) {
        _onError(error);
    }
}

- (void)completedWithData:(NSData *)data
{
    if (_onCompletion != nil) {
        _onCompletion();
    }
}

@end

@implementation FLApi (Internal)

- (void)submitApnToken:(NSString*)apnToken
{
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod:@"account/configure_apn"
        arguments: @{ @"apn_token" : apnToken } ];

    [self sendRequest:request];
}

- (void)createConversationWithTopic:(NSString*)topic members:(NSArray*)emails
    onSuccess:(FLCompletionHandlerWithGuid)onSuccess onError:(FLErrorHandler)onError
{
    NSMutableDictionary* args = [[NSMutableDictionary alloc] init];
    args[@"emails"] = [emails componentsJoinedByString:@","];
    if (topic != nil) {
        args[@"topic"] = topic;
    }

    FLApiRequest *request = [[FLApiRequest alloc] initWithMethod:@"conversation/create"
        arguments: args];

    request.tag = APIREQUEST_TAG_CONVERSATION_CREATE;
    request.handler = ^NSError* (FLJsonParser* response) {
        NSString* conversationId = [response extractString:@"header/conversation_id"];

        if (conversationId != nil) {
            onSuccess(conversationId);
        }

        return nil;
    };
    
    request.errorHandler = onError;
    [self sendRequest:request];
}

- (void)postMessage:(NSString*)message intoConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandlerWithNr)onSuccess onError:(FLErrorHandler)onError

{
    [self postMessage:message andFiles:nil intoConversationWithId:conversationId onSuccess:onSuccess onError:onError];
}

- (void)postMessage:(NSString*)message andFiles:(NSArray*)fileList intoConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandlerWithNr)onSuccess onError:(FLErrorHandler)onError
{
    NSMutableDictionary* args = [[NSMutableDictionary alloc] init];

    if (message.length > 0) {
        args[@"message"] = message;
    }

    if (fileList != nil) {
        args[@"files"] = fileList;
    }

    FLApiRequest *request = [[FLApiRequest alloc] initWithMethod:@"message/send/%@" methodArg: conversationId
        arguments: args];

    __block NSInteger messageNr = -1;

    request.handler = ^NSError* (FLJsonParser* response) {
        if (messageNr < 0) {
            messageNr = [response extractInt:@"result_message_nr" defaultValue:@(0)].integerValue;
            [self.sessionStats reportSentMessage];
            [self.cumulativeStats reportSentMessage];
            if (onSuccess != nil) {
                onSuccess(messageNr);
            }
        }
        return nil;
    };

    request.earlyCompletionHandler = ^void (NSInteger resultMessageNr) {
        if (messageNr < 0) {
            messageNr = resultMessageNr;
            [self.sessionStats reportSentMessage];
            [self.cumulativeStats reportSentMessage];
            if (onSuccess != nil) {
                onSuccess(messageNr);
            }
        }
    };

    request.errorHandler = onError;
    [self sendRequest:request];
}

- (void)postFiles:(NSArray*)fileList toConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandlerWithNr)onSuccess onError:(FLErrorHandler)onError
{
    [self postMessage:nil andFiles:fileList intoConversationWithId:conversationId
        onSuccess:onSuccess onError:onError];
}

- (void)removeMembers:(NSArray*)memberEmails fromConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError
{
    FLApiRequest *request = [[FLApiRequest alloc] initWithMethod: @"conversation/remove_members/%@" methodArg: conversationId
        arguments:@{@"emails": [memberEmails componentsJoinedByString:@","]}];

    request.successHandler = onSuccess;
    request.errorHandler = onError;
    [self sendRequest:request];
}

- (void)addMembers:(NSArray*)memberEmails toConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError
{
    FLApiRequest *request = [[FLApiRequest alloc] initWithMethod:@"conversation/add_members/%@" methodArg: conversationId
        arguments:@{@"emails": [memberEmails componentsJoinedByString:@","]}];

    request.successHandler = onSuccess;
    request.errorHandler = onError;
    [self sendRequest:request];
}

- (void)editMessageNr:(NSInteger)messageNr inConversation:(NSString*)conversationId
    message:(NSString*)message onSuccess:(FLCompletionHandler)onSuccess
    onError:(FLErrorHandler)onError
{
    FLApiRequest *request = [[FLApiRequest alloc] initWithMethod:@"message/edit/%@" methodArg: conversationId
        arguments:@{
            @"message_nr": [NSNumber numberWithInteger:messageNr],
            @"message" : message
        }];

    request.successHandler = onSuccess;
    request.errorHandler = onError;
    [self sendRequest:request];
}

- (void)deleteMessageNr:(NSInteger)messageNr inConversation:(NSString*)conversationId
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler) onError;

{
    FLApiRequest *request = [[FLApiRequest alloc] initWithMethod:@"message/delete/%@" methodArg: conversationId
        arguments:@{
            @"message_nr": [NSNumber numberWithInteger:messageNr],
        }];

    request.successHandler = onSuccess;
    request.errorHandler = onError;
    
    [self sendRequest:request];
}

- (void)pinMessageNr:(NSInteger)messageNr inConversationWithId:(NSString *)conversationId onSuccess:(FLCompletionHandler)onSuccess
{
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod:@"message/pin/%@" methodArg: conversationId
        arguments:@{@"message_nr" : [NSNumber numberWithInteger:messageNr]}];

    request.successHandler = onSuccess;
    
    [self sendRequest:request];
}

- (void)unpinMessageNr:(NSInteger)messageNr inConversationWithId:(NSString *)conversationId
{
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod: @"message/unpin/%@" methodArg: conversationId
        arguments:@{@"pin_message_nr" : [NSNumber numberWithInteger:messageNr]}];

    [self sendRequest:request];
}

- (void)leaveConversationWithId:(NSString*)conversationId
{
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod: @"conversation/leave/%@" methodArg: conversationId
        arguments:nil];

    [self sendRequest:request];
}

- (void)setMyDisplayName:(NSString *)displayName
{
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod:@"account/configure"
        arguments: @{ @"display_name" : displayName
    } ];

    [self sendRequest:request];
}

- (void)deleteMyAvatarOnSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError
{
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod:@"avatar/delete" arguments:nil];

    request.successHandler = onSuccess;
    request.errorHandler = onError;
    [self sendRequest:request];
}

- (void)setMyAvatar:(NSData*)imageData onSuccess:(FLCompletionHandler)onSuccess onProgress:(FLProgressHandler)onProgress
    onError:(FLErrorHandler)onError
{
    for (FLNetworkOperation* no in [FLNetworkOperations networkOperations]) {
        if ([no isKindOfClass:FLAvatarUploader.class]) {
            [no cancel];
        }
    }
    
    FLAvatarUploader* au = [[FLAvatarUploader alloc] initWithData:imageData];
    au.onCompletion = onSuccess;
    au.onProgress = onProgress;
    au.onError = onError;
}

- (void)changePasswordOld:(NSString*)oldPassword newPassword:(NSString*)newPassword
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError
{
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod:@"account/configure"
        arguments: @{
            @"old_password" : oldPassword,
            @"password" : newPassword
    } ];

    request.successHandler = onSuccess;
    request.errorHandler = onError;
    
    [self sendRequest:request];
}

- (void)resetPassword:(NSString*)email
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler) onError
{
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod:@"account/reset_password"
        arguments: @{
            @"email" : email
    } ];

    request.successHandler = onSuccess;
    request.errorHandler = onError;
    
    [self sendRequest:request];
}

- (void)deleteConversation:(NSString*)conversationId
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError
{
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod:@"conversation/delete/%@" methodArg:conversationId
        arguments: nil ];

    request.successHandler = onSuccess;
    request.errorHandler = onError;
    
    [self sendRequest:request];
}

- (void)searchMessages:(NSString*)searchString inConversation:(NSString*)conversationId
    onResult:(FLSearchResultHandler)onResult onSuccess:(FLCompletionHandler)onSuccess
    onError:(FLErrorHandler)onError;
{
    // Cancel pending search request if any
    FLApiRequest* searchRequest = [[FLApi api] pendingRequestWithTag:APIREQUEST_TAG_SEARCH];
    if (searchRequest != nil) {
        [searchRequest cancel];
    }

    NSDictionary* args = conversationId != nil ?
        @{ @"conversation_id" : conversationId, @"keywords" : searchString} :
        @{ @"keywords" : searchString};

    FLApiRequest* request = [[FLApiRequest alloc]
        initWithMethod:@"search" arguments:args];

    request.tag = APIREQUEST_TAG_SEARCH;
    request.handler = ^NSError*(FLJsonParser* json) {
        NSArray* headers = [json extractObject:@"headers" class:NSArray.class];
        for (NSDictionary* d in headers) {
            [[FLApi api] handleConversation:[FLJsonParser jsonParserForObject:d]];
        }

        NSArray* messages = [json extractObject:@"matches" class:NSArray.class];
        for (NSDictionary* d in messages) {
            FLJsonParser* m = [FLJsonParser jsonParserForObject:d];
            FLEntityType entity = [m extractEnum:@"mk_rec_type" valueMap:[FLClassificators mk_entity_type]
                defaultValue:@(0)].integerValue;
            if (entity == FLEntityTypeMessage) {
                [self handleMessage:m];
                NSString* conversationId = [m extractString:@"conversation_id"];
                NSNumber* messageNr = [m extractInt:@"message_nr"];
                NSError* hmr = [[FLApi api] handleMessage:m];
                if ((onResult != nil) && (hmr == nil) && (m.error == nil)) {
                    onResult(conversationId, messageNr.integerValue);
                }
            }
        }

        return nil;
    };

    request.errorHandler = onError;
    request.successHandler = onSuccess;
    [self sendRequest:request];
}

- (void)registerUserId:(NSString*)userId fullName:(NSString*)fullname password:(NSString*)password
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError
{
    FLApiRequest* request = [[FLApiRequest alloc] initWithMethod:@"account/register"
        arguments: @{
            @"email" : userId,
            @"display_name" : fullname,
            @"password" : password
    }];

    request.successHandler = onSuccess;
    request.errorHandler = onError;
    [self sendRequest:request];
}

@end
