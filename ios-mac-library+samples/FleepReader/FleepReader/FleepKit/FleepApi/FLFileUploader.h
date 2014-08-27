//
//  FLFileUploader.h
//  Fleep
//
//  Created by Erik Laansoo on 04.06.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLNetworkOperations.h"

typedef NS_ENUM(NSInteger, FLFileUploadStatus) {
    FLFileUploadStatusPreparing = 0,
    FLFileUploadStatusUploading = 1,
    FLFileUploadStatusComplete = 2,
    FLFileUploadStatusFailed = 3,
    FLFileUploadStatusDeleting = 4,
    FLFileUploadStatusDeleted = 5
};

@interface FLFileUploader : FLNetworkOperation
@property (nonatomic, readonly) NSURL* originalUrl;
@property (nonatomic, readonly) NSString* fileId;
@property (nonatomic, readonly) FLFileUploadStatus status;
@property (nonatomic, readonly) NSString* fileName;
@property (nonatomic, readonly) NSUInteger fileSize;
@property (nonatomic, readonly) CGSize imageSize;
@property (nonatomic, readonly) NSString* conversationId;
@property (nonatomic, readonly) NSString* messageJson;

- (id)initWithConverstionId:(NSString*)conversationId URL:(NSURL*)fileURL;
- (id)initWithValues:(NSDictionary*)values;
- (void)deleteFromServer;
@end
