//
//  FLMessageSend.m
//  Fleep
//
//  Created by Erik Laansoo on 09.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLMessageComposition.h"
#import "FLDataModel.h"
#import "FLDataModelInternal.h"
#import "ConversationInternal.h"
#import "FLApi.h"
#import "FLApiWithLocalStorage.h"
#import "Conversation+Actions.h"
#import "FLMarkupEncoder.h"

@interface Message (Internal)
- (void)setSending:(BOOL)sending notify:(BOOL)notify;
@end

@implementation FLMessageComposition
{
    NSMutableArray* _pendingFiles;
    NSString* _pendingMessage;
    __weak Conversation* _conversation;
}

@synthesize pendingFiles = _pendingFiles;

- (id)initWithConversation:(Conversation*)conversation
{
    if (self = [super init]) {
        _conversation = conversation;
        _pendingMessage = [[NSUserDefaults standardUserDefaults] stringForKey:
            [NSString stringWithFormat:@"newmsg_%@", _conversation.conversation_id]];

        _pendingFiles = [[NSMutableArray alloc] init];
        NSArray* uploads = [[FLNetworkOperations networkOperations] operationsWithClass:[FLFileUploader class]
            andIdentifier:_conversation.conversation_id];

        for (FLFileUploader* fu in uploads) {
            [self addFileUpload:fu];
        }

    }
    return self;
}

- (void)addFileUpload:(FLFileUploader*)file
{
    [file addObserver:self forKeyPath:@"status" options:0 context:nil];
    [_pendingFiles addObject:file];
}

- (FLFileUploader*)removeFileUploadAtIndex:(NSInteger)index
{
    FLFileUploader* file = _pendingFiles[index];
    [file removeObserver:self forKeyPath:@"status"];
    [_pendingFiles removeObjectAtIndex:index];
    [file remove];
    return file;
}

- (NSString*)pendingMessage
{
    return _pendingMessage;
}

- (void)setPendingMessage:(NSString *)message
{
    _pendingMessage = message;
    [[NSUserDefaults standardUserDefaults] setValue:_pendingMessage
        forKey:[NSString stringWithFormat:@"newmsg_%@", _conversation.conversation_id]];

}

- (void)sendOnCompletion:(FLCompletionHandler)onSuccess onError:(FLErrorHandler)onError
{
    NSMutableArray* pendingMessages = [[NSMutableArray alloc] init];
    NSMutableArray* fileList = [[NSMutableArray alloc] init];
    NSString* message = _pendingMessage;
    
    if (_pendingMessage.length > 0) {
        [pendingMessages addObject:
            [_conversation createMessageType:FLMessageTypeText body:[FLMarkupEncoder xmlWithMessage:message]]];
    }

    if (_pendingFiles.count > 0) {
        [self willChangeValueForKey:@"pendingFiles"];
        while (_pendingFiles.count > 0) {
            FLFileUploader* fu = [self removeFileUploadAtIndex:0];
            if (fu.status == FLFileUploadStatusComplete) {
                NSMutableDictionary* fileDict = [@{ @"file_id" : fu.fileId } mutableCopy];
                if ((fu.imageSize.width * fu.imageSize.height) > 0.0f) {
                    fileDict[@"width"] = [NSNumber numberWithInteger:(NSInteger)fu.imageSize.width];
                    fileDict[@"height"] = [NSNumber numberWithInteger:(NSInteger)fu.imageSize.height];
                }

                [fileList addObject:fileDict];
                [pendingMessages addObject:
                    [_conversation createMessageType:FLMessageTypeFile body:fu.messageJson]];
            }
        }
        [self didChangeValueForKey:@"pendingFiles"];
    }

    if (pendingMessages.count == 0) {
        return;
    }
    
    [_conversation notifyPropertyChanges];
    
    self.pendingMessage = @"";
    [_conversation postMessage:message andFiles:fileList
        onSuccess:^ (NSInteger messageNr) {
            for (Message* m in pendingMessages) {
                [m deletePending];
            }
            if (onSuccess != nil) {
                onSuccess();
            }
        } onError:^(NSError *error) {
            [_conversation willChangeProperties:@[@"messages"]];
            for (Message* m in pendingMessages) {
                [m setSending:NO notify:NO];
            }
            [_conversation updateInboxMessage];
            [_conversation notifyPropertyChanges];
            if (onError != nil) {
                onError(error);
            }
        }
    ];
}

- (void)removeUpload:(FLFileUploader*)fu
{
    [self willChangeValueForKey:@"pendingFiles"];
    [self removeFileUploadAtIndex:[_pendingFiles indexOfObject:fu]];
    [self didChangeValueForKey:@"pendingFiles"];
}

- (void)dealloc
{
    while (_pendingFiles.count > 0) {
        FLFileUploader* file = _pendingFiles[0];
        [file removeObserver:self forKeyPath:@"status"];
        [_pendingFiles removeObjectAtIndex:0];
    }
}

- (FLFileUploader*)uploadFile:(NSURL *)fileUrl
{
    assert(!_conversation.isNewConversation);
    
    FLFileUploader* fu = [[FLFileUploader alloc]
        initWithConverstionId:_conversation.conversation_id URL:fileUrl];
    [self willChangeValueForKey:@"pendingFiles"];
    [self addFileUpload:fu];
    [self didChangeValueForKey:@"pendingFiles"];
    return fu;
}

- (void)deleteFile:(FLFileUploader*)fu
{
    assert([_pendingFiles containsObject:fu]);

    switch (fu.status) {
        case FLFileUploadStatusComplete: {
            [fu deleteFromServer];
            [self removeUpload:fu];
        }
        break;
        case FLFileUploadStatusUploading:
            [fu cancel];
        case FLFileUploadStatusDeleted:
        case FLFileUploadStatusPreparing:
        case FLFileUploadStatusFailed: {
            [self removeUpload:fu];
        }
        break;
        default: assert(NO);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    FLFileUploader* fu = object;
    if (fu.status == FLFileUploadStatusDeleted) {
        [fu removeObserver:self forKeyPath:@"status"];
    }
    [self willChangeValueForKey:@"uploadInProgress"];
    [self didChangeValueForKey:@"uploadInProgress"];
}

- (BOOL)uploadInProgress
{
    BOOL result = NO;
    for (FLFileUploader* file in _pendingFiles) {
        if (file.status == FLFileUploadStatusUploading) {
            result = YES;
        }
    }
    return result;
}

@end
