//
//  FLFileUploader.m
//  Fleep
//
//  Created by Erik Laansoo on 04.06.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLFileUploader.h"
#import "FLApi.h"
#import "FLApiInternal.h"
#import "FLUtils.h"
#import "FLJsonParser.h"
#import "FLNetworkOperations.h"
#ifdef TARGET_IS_IPHONE
#import <AssetsLibrary/AssetsLibrary.h>
#endif

@interface FLFileUploader ()
@property (readwrite) NSString* fileId;
@property (readwrite) FLFileUploadStatus status;
@end

@implementation FLFileUploader
{
    NSURL* _fileUrl;
    FLFileUploadStatus _status;
    NSString* _deleteUrl;
    NSString* _fileId;
    NSString* _conversationId;
    CGSize _imageSize;
}

@synthesize fileName = _fileName;
@synthesize fileSize = _fileSize;
@synthesize fileId = _fileId;
@synthesize imageSize = _imageSize;
@synthesize conversationId = _conversationId;
@synthesize originalUrl = _fileUrl;

+ (BOOL)continuesInBackground
{
    return YES;
}

+ (BOOL)removeWhenFinished
{
    return NO;
}

+ (NSString*)persistenceId
{
    return @"Upload";
}

- (void)setStatus:(FLFileUploadStatus)status
{
    if (status == _status) {
        return;
    }
    FLLogInfo(@"FLFileUpload <%@> status = %ld", _fileName, (long)status);
    [self willChangeValueForKey:@"status"];
    _status = status;
    [self didChangeValueForKey:@"status"];
}

+ (void)load
{
    [FLNetworkOperations declarePersistentOperationClass:self];
}

- (FLFileUploadStatus)status
{
    return _status;
}

- (NSString*)identifier
{
    return _conversationId;
}

- (NSString*)description
{
    return [NSString stringWithFormat: @"FLFileUploader <%@>", _fileName];
}
- (void)failWithError:(NSError*)error
{
    [super failWithError:error];
    if (self.status == FLFileUploadStatusDeleting) {
        self.status = FLFileUploadStatusDeleted;
        return;
    }
    
    self.status = FLFileUploadStatusFailed;
}

- (void)startUploadWithData:(NSData*)data
{
    if (data == nil) {
        [self failWithError:[FLError errorWithCode:FLEEP_ERROR_NO_FILE_DATA]];
        return;
    }
    
    NSString* sessionTicket = [FLApi api].credentials.ticket;

    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"file/upload/%@?ticket=%@",
        _conversationId, sessionTicket] relativeToURL:[FLApi api].baseApiURL];
    FLLogInfo(@"FLFileUploader <%@> : url = %@", _fileName, _url.absoluteString);
    NSMutableURLRequest* request  = [[NSMutableURLRequest alloc] initWithURL:url
        cachePolicy:NSURLRequestReloadIgnoringCacheData
        timeoutInterval:120.0f];
    request.HTTPMethod = @"PUT";
    request.HTTPBody = data;
    [request addValue:[NSString stringWithFormat:@"attachment; filename=\"%@\"", _fileName]
        forHTTPHeaderField:@"Content-Disposition"];
    [self submitRequest:request];
    self.status = FLFileUploadStatusUploading;
}

- (id)initWithConverstionId:(NSString*)conversationId URL:(NSURL*)fileURL
{
    if (self = [super init]) {
        _conversationId = conversationId;
        _fileUrl = fileURL;

#ifdef TARGET_IS_IPHONE
        if ([_fileUrl.scheme isEqualToString:@"assets-library"]) {
            ALAssetsLibrary* al = [[ALAssetsLibrary alloc] init];
            [al assetForURL:_fileUrl
             resultBlock:^(ALAsset *asset) {
                ALAssetRepresentation* ar = asset.defaultRepresentation;
                _fileName = ar.filename;
                _fileSize = (NSUInteger)ar.size;
                _imageSize = ar.dimensions;
                void* data = malloc(_fileSize);
                NSError* err;
                [ar getBytes:data fromOffset:0 length:_fileSize error:&err];
                if (err != nil) {
                    free(data);
                    [self failWithError:err];
                    return;
                }
                NSData* fileData = [[NSData alloc] initWithBytesNoCopy:data length:_fileSize freeWhenDone:YES];
                
                [self startUploadWithData:fileData];
             } failureBlock:^(NSError *error) {
                [self failWithError:error];
             }];
        } else
#endif
        {
            NSFileManager* fm = [NSFileManager defaultManager];
            _fileName = fileURL.path.pathComponents[fileURL.path.pathComponents.count - 1];
            NSError* err = nil;
            NSDictionary* fileAttribs = [fm attributesOfItemAtPath:fileURL.path error:&err];
            if (err != nil) {
                [self failWithError:err];
                return nil;
            }
            
            _fileSize = (NSUInteger)fileAttribs.fileSize;
            
            [self startUploadWithData:[fm contentsAtPath:fileURL.path]];
        }
    }
    return self;
}

- (id)initWithValues:(NSDictionary*)values
{
    NSNumber* status = [values objectForKey:@"status"];
    NSString* conversationId = [values objectForKey:@"conversationId"];
    NSString* u = [values objectForKey:@"url"];
    NSURL* url = [NSURL URLWithString:u];
    
    if (status.integerValue == FLFileUploadStatusUploading) {
        return [self initWithConverstionId:conversationId URL:url];
    }

    if (self = [super init]) {
        _fileUrl = url;
        _conversationId = conversationId;
        _deleteUrl = [values objectForKey:@"deleteUrl"];
        self.fileId = [values objectForKey:@"fileId"];
        _fileName = [values objectForKey:@"fileName"];
        _fileSize = ((NSNumber*)[values objectForKey:@"fileSize"]).integerValue;
        NSNumber* w = values[@"width"];
        NSNumber* h = values[@"height"];
        if ((w != nil) && (h != nil) && (w.integerValue > 0) && (h.integerValue > 0)) {
            _imageSize = CGSizeMake(w.doubleValue, h.doubleValue);
        }

        self.status = FLFileUploadStatusComplete;
        self.progress = 1.0f;
    }
    return self;
}

- (NSDictionary*)serialize
{
    return @{
        @"url": _fileUrl.absoluteString,
        @"status": [NSNumber numberWithInteger:self.status],
        @"conversationId": _conversationId,
        @"deleteUrl": _deleteUrl ? _deleteUrl : @"",
        @"fileId": _fileId ? _fileId : @"",
        @"fileName" : _fileName,
        @"width" : [NSNumber numberWithInteger:(NSInteger)_imageSize.width],
        @"height" : [NSNumber numberWithInteger: (NSInteger)_imageSize.height],
        @"fileSize" : [NSNumber numberWithInteger:_fileSize]
    };
}

- (void)completedWithData:(NSData *)data
{
    if (self.status == FLFileUploadStatusDeleting) {
        self.status = FLFileUploadStatusDeleted;
        return;
    }

    NSString* responseStr = [[NSString alloc]
        initWithData:data encoding:NSUTF8StringEncoding];
    
    FLLogInfo(@"%@ => %@", self.description, responseStr);
    FLJsonParser* json = [FLJsonParser jsonParserForString:responseStr];

    self.fileId = [json extractString:@"files[0]/file_id"];
    _deleteUrl = [json extractString:@"files[0]/delete_url" defaultValue:nil];
    if (json.error != nil) {
        [self failWithError:json.error];
        return;
    }

    [self setProgress: 1.0f];
    self.status = FLFileUploadStatusComplete;
}

- (void)uploadProgress:(float)progress
{
    [self setProgress:progress];
}

- (void)downloadProgress:(float)progress
{
}

- (void)deleteFromServer
{
    self.status = FLFileUploadStatusDeleting;
        
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_deleteUrl]
            cachePolicy:NSURLRequestReloadIgnoringCacheData
            timeoutInterval:120.0f];
    [self submitRequest:request];
}

- (NSString*)messageJson
{
    NSMutableDictionary* values = [@{
        @"file_name" : _fileName,
        @"file_id" : _fileId,
        @"file_size" : [NSNumber numberWithInteger:_fileSize],
        @"file_original_url" : _fileUrl.absoluteString
    } mutableCopy];

    if ((_imageSize.width * _imageSize.height) > 0.0f) {
        values[@"width"] = [NSNumber numberWithInteger:(NSInteger)_imageSize.width];
        values[@"height"] = [NSNumber numberWithInteger:(NSInteger)_imageSize.height];
    }

    NSData* json = [NSJSONSerialization dataWithJSONObject:values options:0 error:nil];
    return [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

@end