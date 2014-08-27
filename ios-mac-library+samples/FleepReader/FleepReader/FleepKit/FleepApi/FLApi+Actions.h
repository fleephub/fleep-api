//
//  FLApi+Actions.h
//  Fleep
//
//  Created by Erik Laansoo on 11.02.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

typedef void (^FLSearchResultHandler)(NSString* conversationId, NSInteger messageNr);

@interface FLApi (Actions)

// Account
- (void)registerUserId:(NSString*)userId fullName:(NSString*)fullname password:(NSString*)password
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError;
- (void)submitApnToken:(NSString*)token;
- (void)setMyDisplayName:(NSString*)displayName;
- (void)setMyAvatar:(NSData*)imageData onSuccess:(FLCompletionHandler)onSuccess onProgress:(FLProgressHandler)onProgress
    onError:(FLErrorHandler)onError;
- (void)deleteMyAvatarOnSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError;
- (void)changePasswordOld:(NSString*)oldPassword newPassword:(NSString*)newPassword
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError;
- (void)resetPassword:(NSString*)email
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler) onError;

// Conversation
- (void)postMessage:(NSString*)message intoConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandlerWithNr)onSuccess onError:(FLErrorHandler)onError;
- (void)postMessage:(NSString*)message andFiles:(NSArray*)fileList intoConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandlerWithNr)onSuccess onError:(FLErrorHandler)onError;
- (void)removeMembers:(NSArray*)memberEmails fromConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError;
- (void)addMembers:(NSArray*)memberEmails toConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError;
- (void)postFiles:(NSArray*)fileIdList toConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandlerWithNr)onSuccess onError:(FLErrorHandler)onError;
- (void)editMessageNr:(NSInteger)messageNr inConversation:(NSString*)conversationId
    message:(NSString*)message onSuccess:(FLCompletionHandler)onSuccess
    onError:(FLErrorHandler)onError;
- (void)pinMessageNr:(NSInteger)messageNr inConversationWithId:(NSString*)conversationId
    onSuccess:(FLCompletionHandler)onSuccess;
- (void)unpinMessageNr:(NSInteger)messageNr inConversationWithId:(NSString*)conversationId;
- (void)leaveConversationWithId:(NSString*)conversationId;
- (void)deleteMessageNr:(NSInteger)messageNr inConversation:(NSString*)conversationId
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler) onError;
- (void)createConversationWithTopic:(NSString*)topic members:(NSArray*)emails
    onSuccess:(FLCompletionHandlerWithGuid)onSuccess onError:(FLErrorHandler)onError;
- (void)deleteConversation:(NSString*)conversationId
    onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError;

// Search
- (void)searchMessages:(NSString*)searchString inConversation:(NSString*)conversationId
    onResult:(FLSearchResultHandler)onResult onSuccess:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError;
@end
