//
//  FLTeeURLConnection.m
//  Fleep
//
//  Created by Erik Laansoo on 12.07.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLTeeURLConnection.h"
#import "FLObfuscator.h"

@interface FLTeeURLConnection : FLURLConnection <NSURLConnectionDataDelegate>
@end

@implementation FLTeeURLConnection
{
    NSURLConnection* _urlConnection;
    id <NSURLConnectionDataDelegate> _delegate;
    NSURL* _fileUrl;
    NSMutableData* _data;
    NSDictionary* _headers;
    NSInteger _resultCode;
}

- (id)initWithRequest:(NSURLRequest*)request delegate:(id)delegate fileUrl:(NSURL*)fileUrl
{
    if (self = [super init]) {
        _urlConnection = [[NSURLConnection alloc]initWithRequest:request delegate:self startImmediately:YES];
        _delegate = delegate;
        _fileUrl = fileUrl;
        _data = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([_delegate respondsToSelector:@selector(connection:didCancelAuthenticationChallenge:)]) {
        [_delegate connection:connection didCancelAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if ([_delegate respondsToSelector:@selector(connection:didFailWithError:)]) {
        [_delegate connection:connection didFailWithError:error];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([_delegate respondsToSelector:@selector(connection:didReceiveAuthenticationChallenge:)]) {
        [_delegate connection:connection didReceiveAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_delegate connection:connection didReceiveData:data];
    [_data appendData:data];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_delegate connection:connection didReceiveResponse:response];
    assert([response isKindOfClass:[NSHTTPURLResponse class]]);
    NSHTTPURLResponse* r = (NSHTTPURLResponse*)response;
    _resultCode = r.statusCode;
    _headers = [r allHeaderFields];
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if ([_delegate respondsToSelector:@selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:)]) {
        [_delegate connection:connection
            didSendBodyData:bytesWritten
            totalBytesWritten:totalBytesWritten
            totalBytesExpectedToWrite:totalBytesExpectedToWrite
        ];
    }
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([_delegate respondsToSelector:@selector(connection:willSendRequestForAuthenticationChallenge:)]) {
        [_delegate connection:connection willSendRequestForAuthenticationChallenge:challenge];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [_delegate connectionDidFinishLoading:connection];
    if (_fileUrl != nil) {
        NSError* error = nil;
        NSMutableDictionary* res = [[NSJSONSerialization JSONObjectWithData:_data options:0 error:&error] mutableCopy];
        NSDictionary* httpFields = @{@"status" : [NSNumber numberWithInteger:_resultCode],
        @"headers" : _headers };
        res[@"httpResult"] = httpFields;
        [FLObfuscator obfuscateDictionary:res];
        NSData* serialized = [NSJSONSerialization dataWithJSONObject:res options:NSJSONWritingPrettyPrinted error:nil];
        [serialized writeToURL:_fileUrl atomically:NO];
    }
}

@end

@implementation FLTeeURLConnectionFactory
{
    NSURL* _baseFileUrl;
}

- (id)init
{
    if (self = [super init]) {
        NSFileManager* fm = [NSFileManager defaultManager];
        NSURL* baseURL = [[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        _baseFileUrl = [baseURL URLByAppendingPathComponent:@"SavedRequests"];
        [fm createDirectoryAtPath:_baseFileUrl.path withIntermediateDirectories:NO attributes:nil error:nil];
        NSArray* files = [fm contentsOfDirectoryAtPath:_baseFileUrl.path error:nil];
        for (NSString* file in files) {
            [fm removeItemAtPath:[_baseFileUrl URLByAppendingPathComponent:file].path error:nil];
        }
        FLLogInfo(@"Requests saved to: %@", _baseFileUrl.path);
    }
    return self;
}

- (FLURLConnection*)connectionForRequest:(NSURLRequest*)request delegate:(id)delegate
{
    static NSInteger _fileIndex = 1;
    NSURL* fileUrl = nil;
    if ([request.URL.relativePath isEqualToString:@"/api/account/poll"]) {
        fileUrl = [_baseFileUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"req_%ld", (long)_fileIndex++]];
    }
    return [[FLTeeURLConnection alloc] initWithRequest:request delegate:delegate fileUrl:fileUrl];
}

@end
