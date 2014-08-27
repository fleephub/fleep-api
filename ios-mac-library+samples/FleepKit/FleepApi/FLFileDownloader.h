//
//  FLFileDownloader.h
//  Fleep
//
//  Created by Erik Laansoo on 02.09.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLNetworkOperations.h"

@class FLFileDownloader;

typedef void (^OnDownloadCompletedWithLocalURL)(NSURL* url);
typedef void (^OnDownloadFailedWithError)(NSError* error);
typedef void (^OnDownloadProgress)(float progress);

@protocol FLFileDownloaderDelegate
- (void)download:(FLFileDownloader*)download completedWithLocalURL:(NSURL*)url;
- (void)download:(FLFileDownloader*)download failedWithError:(NSError*)error;
- (void)download:(FLFileDownloader*)download progress:(float)progress;
@end

@interface FLFileDownloaderBlockDelegate : NSObject <FLFileDownloaderDelegate>
@property (nonatomic, strong) OnDownloadCompletedWithLocalURL OnDownloadCompleted;
@property (nonatomic, strong) OnDownloadFailedWithError OnDownloadFailed;
@property (nonatomic, strong) OnDownloadProgress OnDownloadProgress;
@end

@interface FLFileDownloader : FLNetworkOperation
@property (nonatomic, weak) id<FLFileDownloaderDelegate>delegate;

+ (NSURL*)localBaseURL;
+ (void)deleteCachedFiles;

- (id) initWithRemoteURL:(NSString*)remoteURL localRelativePath:(NSString*)relativePath
    expectedSize:(long)expectedSize;
- (NSMutableURLRequest*)createRequest;
@end
