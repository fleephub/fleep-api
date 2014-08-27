//
//  FLFileDownloader.m
//  Fleep
//
//  Created by Erik Laansoo on 02.09.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLFileDownloader.h"
#import "FLUtils.h"
#import "FLApi.h"
#import "FLApiInternal.h"

@implementation FLFileDownloader
{
    __weak id<FLFileDownloaderDelegate> _delegate;
    NSURL* _localURL;
}

@synthesize delegate = _delegate;

+ (NSURL*)localBaseURL
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* baseURL = [[fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
    return baseURL;
}

+ (void)deleteCachedFiles
{
    NSFileManager* fm = [NSFileManager defaultManager];
    [fm removeItemAtURL:[self localBaseURL] error:nil];
}

- (id)initWithRemoteURL:(NSString *)remoteURL localRelativePath:(NSString *)relativePath expectedSize:(long)expectedSize
{
    if (self = [super init]) {
        if ([remoteURL hasPrefix:@"https:"]) {
            _url = [NSURL URLWithString:remoteURL];
        } else {
            _url = [NSURL URLWithString:remoteURL relativeToURL:[FLApi api].baseURL];
        }

        _expectedResponseSize = expectedSize;

        _localURL = [self.class localBaseURL];
        for (NSString* pc in relativePath.pathComponents) {
            _localURL = [_localURL URLByAppendingPathComponent:pc];
        }

        FLLogInfo(@"%@ => %@", self.description, _localURL.path);
        [self performSelector:@selector(startDownload:) withObject:nil afterDelay:0.1f];

    }
    return self;
}

- (NSMutableURLRequest*)createRequest
{
    return [NSMutableURLRequest requestWithURL:_url
        cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60.0f];
}

- (void)startDownload:(NSObject*)object
{
    // Check if file already present
    NSFileManager* fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:_localURL.path]) {
        if (_delegate != nil) {
            [_delegate download:self completedWithLocalURL:_localURL];
            return;
        }
    }

    NSError* err;
    NSString* localDir = [NSString pathWithComponents:[_localURL.pathComponents
        subarrayWithRange:NSMakeRange(0, _localURL.pathComponents.count - 1)]];
    if (![fm fileExistsAtPath:localDir]) {
        if (![fm createDirectoryAtPath:localDir withIntermediateDirectories:YES attributes:nil error:&err]) {
            [self failWithError:err];
            return;
        }
    }

    NSMutableURLRequest* request = [self createRequest];

    [self submitRequest:request];
    if (_delegate != nil) {
        [_delegate download:self progress:0.0f];
    }
}

- (NSString*)description
{
    return [NSString stringWithFormat: @"FLFileDownloader: %@", _url];
}

- (void)failWithError:(NSError*)error
{
    [super failWithError:error];
    if (_delegate != nil) {
        [_delegate download:self failedWithError:error];
    }
}

- (void)downloadProgress:(float)progress
{
    [super downloadProgress:progress];
    if (_delegate != nil) {
        [_delegate download:self progress:progress];
    }
}

- (void)completedWithData:(NSData *)data
{
    NSFileManager* fm = [NSFileManager defaultManager];

    if (![fm createFileAtPath:_localURL.path contents:data attributes:nil]) {
        FLLogError(@"Failed to create file: %@", _localURL);
        [self failWithError:[FLError errorWithCode:FLEEP_ERROR_FILE_CREATE_FAILED]];

        return;
    }

    if (_delegate != nil) {
        [_delegate download:self completedWithLocalURL:_localURL];
    }
}


@end

@implementation FLFileDownloaderBlockDelegate
{
    OnDownloadCompletedWithLocalURL _OnDownloadCompleted;
    OnDownloadFailedWithError _OnDownloadFailed;
    OnDownloadProgress _OnDownloadProgress;
}

@synthesize OnDownloadCompleted = _OnDownloadCompleted;
@synthesize OnDownloadProgress = _OnDownloadProgress;
@synthesize OnDownloadFailed = _OnDownloadFailed;

- (void)download:(FLFileDownloader *)download completedWithLocalURL:(NSURL *)url
{
    if (_OnDownloadCompleted != nil) {
        _OnDownloadCompleted(url);
    }
}

- (void)download:(FLFileDownloader *)download failedWithError:(NSError *)error
{
    if (_OnDownloadFailed != nil) {
        _OnDownloadFailed(error);
    }
}

- (void)download:(FLFileDownloader *)download progress:(float)progress
{
    if (_OnDownloadProgress != nil) {
        _OnDownloadProgress(progress);
    }
}

@end

