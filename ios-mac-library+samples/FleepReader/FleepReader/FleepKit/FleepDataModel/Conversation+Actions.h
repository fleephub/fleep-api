//
//  Conversation+Actions.h
//  Fleep
//
//  Created by Erik Laansoo on 09.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

@interface Conversation (Actions)

- (void)removeMembers:(NSArray*)emails onSuccess:(FLCompletionHandler)onSuccess
    onError:(FLErrorHandler)onError;
- (void)leave;

- (void)markReadUntil:(NSInteger)readMessageNr;
- (void)markUnreadUntil:(NSInteger)unreadMessageNr;
- (void)markRead;
- (void)markUnread;

- (void)unpin;
- (void)pinAfter:(Conversation*)otherConversation;

- (void)changeTopic:(NSString*)topic;
- (void)changeAlertLevel:(NSInteger)newAlertLevel;

- (void)archive;
- (void)unarchive;

- (void)postMessage:(NSString*) message andFiles:(NSArray*)fileList
    onSuccess:(FLCompletionHandlerWithNr) onSuccess onError:(FLErrorHandler)onError;
@end
