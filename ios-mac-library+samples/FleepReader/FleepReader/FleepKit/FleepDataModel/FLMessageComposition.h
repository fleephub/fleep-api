//
//  FLMessageSend.h
//  Fleep
//
//  Created by Erik Laansoo on 09.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLUtils.h"
#import "FLFileUploader.h"

@class Conversation;

#define PENDING_MESSAGE_BASE 1000000000

@interface FLMessageComposition : NSObject
@property (nonatomic) NSString* pendingMessage;
@property (readonly, nonatomic) NSArray* pendingFiles;
@property (readonly) BOOL uploadInProgress;

- (id)initWithConversation:(Conversation*)conversation;
- (FLFileUploader*)uploadFile:(NSURL*)fileUrl;
- (void)deleteFile:(FLFileUploader*)file;
- (void)sendOnCompletion:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError;

@end
