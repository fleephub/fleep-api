//
//  FLApiPrivate.h
//  Fleep
//
//  Created by Erik Laansoo on 11.02.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//
#import "FLUserCredentials.h"
#import "FLApi.h"

@interface FLApi (Private)
@property (readonly) NSURL* baseURL;
@property (readonly) NSURL* baseApiURL;
@property (readonly) FLUserCredentials* credentials;
@property (readwrite) NSInteger eventHorizon;
+ (NSString*)userAgentString;
+ (BOOL)isNetworkFailure:(NSError*) error;

#ifndef RELEASE
- (void)setCustomBaseURL:(NSString*)url;
#endif

- (void)initialSyncCompleted;

- (void)connection:(NSURLConnection *)connection
    willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)sendRequest:(FLApiRequest*)request;
- (FLApiRequest*)pendingRequestWithTag:(NSInteger)tag;
- (void)queueRequest:(FLApiRequest*)request name:(NSString*)name;

- (void)startTransaction;
- (void)endTransaction;
- (void)handleResyncRequest;
- (NSError*)handleContact:(FLJsonParser*)contact;
- (NSError*)handleConversation:(FLJsonParser*)conversation;
- (NSError*)handleConversation:(FLJsonParser *)conversation isCreateRequest:(BOOL)isCreateRequest;
- (NSError*)handleMessage:(FLJsonParser*)message;
- (NSError*)handleActivity:(FLJsonParser*)activity;
- (NSError*)handleHook:(FLJsonParser*)hook;
- (NSError*)handleTeam:(FLJsonParser*)team;
- (NSError*)handleRequest:(FLJsonParser*)request;
- (NSError*)handleMessageNotification:(FLJsonParser*)message;
- (void)handleUpgradeRequestWithURL:(NSString*)url;
- (NSError*)login;
- (void)doLogout;

#ifdef TARGET_IS_IPHONE
- (BOOL)hasBackgroundTasks;
- (void)endBackgroundTaskIfDone;
#endif
@end