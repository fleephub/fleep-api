//
//  FLNetworkOperations.m
//  Fleep
//
//  Created by Erik Laansoo on 06.09.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLNetworkOperations.h"
#import "FLUtils.h"
#import "FLApi.h"
#import "FLApiInternal.h"

#define MAX_CONCURRENT_REQUESTS 2 

@interface FLNetworkOperations ()
- (void)addOperation:(FLNetworkOperation*)operation;
- (void)removeOperation:(FLNetworkOperation*)operation;
@end

@implementation FLNetworkOperation
{
    NSMutableData* _response;
    NSURLRequest* _pendingRequest;
    NSInteger _httpStatus;
    NSString* _contentType;
    float _progress;
}

@synthesize error = _error;
@synthesize progress = _progress;

- (id)init
{
    if (self = [super init]) {
        [[FLNetworkOperations networkOperations] addOperation:self];
    }
    return self;
}

- (NSString*)identifier
{
    return nil;
}

- (void)submitPendingRequest
{
    [self willChangeValueForKey:@"inProgress"];
    _connection = [[FLURLConnectionFactory factory] connectionForRequest:_pendingRequest delegate:self];
    _pendingRequest = nil;
    [self didChangeValueForKey:@"inProgress"];
}

- (void)submitRequest:(NSMutableURLRequest *)request
{
    NSString* sessionCookie = [FLApi api].credentials.cookie;
    if (sessionCookie != nil) {
        [request addValue:[NSString stringWithFormat:@"token_id=%@", sessionCookie] forHTTPHeaderField:@"Cookie"];
    }

    [request addValue: [FLApi userAgentString] forHTTPHeaderField:@"User-Agent"];
    _url = request.URL;
    _pendingRequest = request;
    if ([FLNetworkOperations networkOperations].numberInProgress < MAX_CONCURRENT_REQUESTS) {
        [self submitPendingRequest];
    }
}

- (BOOL)inProgress
{
    return _connection != nil;
}

- (BOOL)isPending
{
    return _pendingRequest != nil;
}

- (void)setProgress:(float)progress
{
    [self willChangeValueForKey:@"progress"];
    _progress = progress;
    [self didChangeValueForKey:@"progress"];
}

+ (BOOL)continuesInBackground
{
    return NO;
}

+ (BOOL)removeWhenFinished
{
    return YES;
}

+ (NSString*)persistenceId
{
    return nil;
}

- (void)cancel
{
    if (_error != nil) {
        return;
    }

    if (_pendingRequest != nil) {
        _pendingRequest = nil;
    } else {
        if (_connection != nil) {
            [_connection cancel];
        }
    }
    [self failWithError:[FLError errorWithCode:FLEEP_ERROR_CANCELLED]];
}

- (NSDictionary*)serialize
{
    return nil;
}

- (id)initWithValues:(NSDictionary*)values
{
    assert(NO);
}

- (void)uploadProgress:(float)progress
{
}

- (void)downloadProgress:(float)progress
{
    [self setProgress:progress];
}

- (void)failWithError:(NSError*)error
{
    FLLogError(@"%@: %@", self.description, error);
    [self willChangeValueForKey:@"inProgress"];
    _error = error;
    _connection = nil;
    _response = nil;
    [self didChangeValueForKey:@"inProgress"];
     if ([self.class removeWhenFinished]) {
        [self remove];
    }
}

- (void)completedWithData:(NSData*)data
{
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self failWithError:error];
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    return YES;
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [[FLApi api]connection:connection willSendRequestForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)r
{
    assert([r isKindOfClass:[NSHTTPURLResponse class]]);
    NSHTTPURLResponse* response = (NSHTTPURLResponse*)r;
    _httpStatus = [response statusCode];
    _contentType = [response.allHeaderFields objectForKey:@"Content-Type"];
    NSString* cs = [response.allHeaderFields objectForKey:@"Content-Length"];
    if ((cs != nil) && (_expectedResponseSize == 0)) {
        _expectedResponseSize = cs.integerValue;
    }
    
    FLLogInfo(@"%@: HTTP %ld", self.description, (long)_httpStatus);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_response == nil) {
        _response = [NSMutableData dataWithData:data];
    } else {
        [_response appendData:data];
    }

    if (_expectedResponseSize > 0) {
        [self downloadProgress:(float)_response.length / (float)_expectedResponseSize];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_httpStatus != HTTP_STATUS_SUCCESS) {
        NSError* error = nil;
        if ([_contentType isEqualToString:HTTP_CONTENT_TYPE_JSON]) {
            NSError* jsonError = nil;
            NSDictionary* res = [NSJSONSerialization JSONObjectWithData:_response options:0 error:&jsonError];
            if (jsonError != nil) {
                error = [FLError errorWithJson:res code:_httpStatus];
            }
        }

        if (error == nil) {
            NSString* response = [[NSString alloc] initWithData:_response encoding:NSUTF8StringEncoding];
            error = [FLError errorWithCode:_httpStatus andUserInfo:@{@"url" : _url, @"response" : response}];
        }

        [self failWithError:error];
        return;
    }

    FLLogInfo(@"%@: completed, received %ld bytes", self.description, (long)_response.length);
    [self downloadProgress:1.0f];
    [self completedWithData: _response];
    if (_error != nil) {
        return;
    }

    [self willChangeValueForKey:@"inProgress"];
    _response = nil;
    _connection = nil;
    [self didChangeValueForKey:@"inProgress"];
     if ([self.class removeWhenFinished]) {
        [self remove];
    }
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    [self uploadProgress: (float)totalBytesWritten / (float)totalBytesExpectedToWrite];
}

- (void)remove
{
    [[FLNetworkOperations networkOperations] removeOperation:self];
}

@end

NSMutableDictionary* _persistentOperationClasses = nil;
FLNetworkOperations* _networkOperations = nil;

@implementation FLNetworkOperations
{
    NSMutableArray* _operations;
    BOOL _background;
    BOOL _changing;
}

- (id)init
{
    assert(_networkOperations == nil);
    if (self = [super init]) {
        _operations = [[NSMutableArray alloc] init];
        _networkOperations = self;
        [self restoreState];
    }
    return self;
}

- (void)beginChange
{
    if (_changing) {
        return;
    }
    _changing = YES;
    [self performSelector:@selector(endChange) withObject:nil afterDelay:0.1f];
    [self willChangeValueForKey:@"count"];
    [self willChangeValueForKey:@"numberInProgress"];
}

- (void)endChange
{
    if (!_changing) {
        return;
    }
    _changing = NO;
    [self didChangeValueForKey:@"count"];
    [self didChangeValueForKey:@"numberInProgress"];
}

- (NSUInteger)count
{
    return _operations.count;
}

- (NSUInteger)numberInProgress
{
    NSUInteger result = 0;
    for (FLNetworkOperation* no in _operations) {
        if (no.inProgress) {
            result++;
        }
    }
    return result;
}

- (BOOL)background
{
    return _background;
}

- (NSArray*)operationsWithClass:(Class)class
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    for (FLNetworkOperation* no in _operations) {
        if (no.error != nil) {
            continue;
        }
        if ([no isKindOfClass:class]) {
            [result addObject:no];
        }
    }
    return result;
}

- (void)saveState
{
    [self removeFailed];
    if (_persistentOperationClasses == nil) {
        return;
    }

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    for (NSString* persistenceId in _persistentOperationClasses.allKeys) {
        Class class = _persistentOperationClasses[persistenceId];
        NSArray* operationsToSave = [self operationsWithClass:class];
        [defaults setInteger:operationsToSave.count forKey:[NSString stringWithFormat: @"%@Count", persistenceId]];
        for (NSUInteger i = 0; i < operationsToSave.count; i++) {
            FLNetworkOperation* no = operationsToSave[i];
            [defaults setObject:[no serialize]
                forKey:[NSString stringWithFormat:@"%@_%ld", persistenceId, (long)i]];
        }
    }
}

- (void)restoreState
{
    if (_persistentOperationClasses == nil) {
        return;
    }

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    for (NSString* persistenceId in _persistentOperationClasses.allKeys) {
        Class class = _persistentOperationClasses[persistenceId];
        NSInteger count = [defaults integerForKey: [NSString stringWithFormat: @"%@Count", persistenceId]];
        for (NSInteger i = 0; i < count; i++) {
            NSDictionary* values = [defaults dictionaryForKey:
                [NSString stringWithFormat:@"%@_%ld", persistenceId, (long)i]];
            FLNetworkOperation* no = [[class alloc] initWithValues: values];
            assert(no != nil);
        }
    }
}

+ (void)declarePersistentOperationClass:(Class)operationClass
{
    assert([operationClass isSubclassOfClass:[FLNetworkOperation class]]);
    if (_persistentOperationClasses == nil) {
        _persistentOperationClasses = [[NSMutableDictionary alloc] init];
    }
    NSString* persistenceId = [operationClass persistenceId];
    _persistentOperationClasses[persistenceId] = operationClass;
}

- (void)setBackground:(BOOL)background
{
    if (background == _background) {
        return;
    }
    _background = background;
    if (background) {
        [self beginChange];
        NSUInteger i = 0;
        while (i < _operations.count) {
            FLNetworkOperation* no = _operations[i];
            if ([no.class continuesInBackground]) {
                i++;
                continue;
            }

            if (no.inProgress) {
                [no cancel];
            } else {
                i++;
            }
        }
        [self removeFailed];
    }
}

- (void)removeFailed
{
    NSUInteger i = 0;
    while (i < _operations.count) {
        FLNetworkOperation* no = _operations[i];
        if (no.error != nil) {
            [self removeOperation:no];
        } else {
            i++;
        }
    }
}

- (void)addOperation:(FLNetworkOperation *)operation
{
    [self beginChange];
    [operation addObserver:self forKeyPath:@"inProgress" options:0 context:nil];
    [_operations addObject:operation];
}

- (void)removeOperation:(FLNetworkOperation *)operation
{
    [self beginChange];
    [operation removeObserver:self forKeyPath:@"inProgress"];
    [_operations removeObject:operation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"inProgress"]) {
        [self beginChange];
        [self submitPendingRequest];
    }
}

- (void)submitPendingRequest
{
    if (self.numberInProgress >= MAX_CONCURRENT_REQUESTS) {
        return;
    }
    FLNetworkOperation* pending = nil;
    for (FLNetworkOperation* no in _operations) {
        if (no.isPending) {
            pending = no;
            break;
        }
    }

    if (pending != nil) {
        [pending submitPendingRequest];
    }
}

+ (FLNetworkOperations*)networkOperations
{
    assert(_networkOperations != nil);
    return _networkOperations;
}

- (FLNetworkOperation*)objectAtIndexedSubscript:(NSUInteger)index
{
    return _operations[index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
    objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len
{
    return [_operations countByEnumeratingWithState:state objects:stackbuf count:len];
}

- (NSArray*)operationsWithClass:(Class)class andIdentifier:(NSString*)identifier
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    for (FLNetworkOperation* no in _operations) {
        if ([no isKindOfClass:class] && [identifier isEqualToString: no.identifier]) {
            [result addObject:no];
        }
    }
    return result;
}

- (void)deleteOperationsWithClass:(Class)class andIdentifier:(NSString*)identifier
{
    NSArray* operations = [self operationsWithClass:class andIdentifier:identifier];
    for (FLNetworkOperation* no in operations) {
        [no remove];
    }
}

- (void)logout
{
    [self beginChange];
    NSUInteger i = 0;
    while (i < _operations.count) {
        FLNetworkOperation* no = _operations[i];
        if (no.inProgress || no.isPending) {
            [no cancel];
        } else {
            i++;
        }
    }
    [self saveState];
    while (_operations.count > 0) {
        [self removeOperation:_operations[0]];
    }

    _networkOperations = nil;
}

@end
