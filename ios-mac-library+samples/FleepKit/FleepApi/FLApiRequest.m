//
//  FLApiRequest.m
//  Fleep
//
//  Created by Erik Laansoo on 27.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#define xDELAY_API_RESPONSES
#ifdef DEBUG
#define PRETTY_PRINT_API_RESPONSES
#endif

#import "FLApiRequest.h"
#import "FLApi.h"
#import "FLApiInternal.h"
#import "FLLogSanitization.h"

@implementation FLApiRequest
{
    NSString* _method;
    NSURL* _url;
    FLApiRequestPriority _priority;
    NSDictionary* _arguments;
    NSString* _requestForLog;
    NSInteger _requestSize;
    NSMutableURLRequest* _request;
    FLURLConnection* _connection;
    NSInteger _tag;
    NSString* _requestId;
    BOOL _canRetry;
}

@synthesize requestId = _requestId;
@synthesize tag = _tag;
@synthesize responseBody=_responseBody, contentType=_contentType, httpStatus=_httpStatus, requestSize=_requestSize;
@synthesize handler;
@synthesize errorHandler;
@synthesize successHandler;
@synthesize priority = _priority;
@synthesize method = _method;
@synthesize canRetry = _canRetry;
@synthesize earlyCompletionHandler;

- (id)initWithMethod:(NSString*)method arguments:(NSDictionary*)args
{
    _method = method;
    _url = [NSURL URLWithString:method relativeToURL:[FLApi api].baseApiURL];
    _arguments = args;
    _priority = FLApiRequestPriorityNormal;
    
    return self;
}

- (id)initWithMethod:(NSString *)method methodArg:(NSString *)methodArg arguments:(NSDictionary *)args
{
    return [self initWithMethod:[NSString stringWithFormat:method, methodArg] arguments:args];
}

- (BOOL)isMethod:(NSString *)uriPrefix
{
    return [_method hasPrefix:uriPrefix];
}

- (void)submit
{
    assert(_request == nil);
    
    NSError* error = nil;
    NSString* ticket = ([FLApi api].credentials != nil) ? [FLApi api].credentials.ticket : nil;
    NSDictionary* argsWithTicket = _arguments;
    if ((ticket != nil) || (self.earlyCompletionHandler != nil)) {
        NSMutableDictionary* awt = _arguments != nil ? [_arguments mutableCopy] :
            [[NSMutableDictionary alloc] init];
        if (ticket != nil) {
            awt[@"ticket"] = ticket;
        }
        if (self.earlyCompletionHandler != nil) {
            NSString* requestId = [[FleepUtils generateUUID] lowercaseString];
            self.requestId = requestId;
            awt[@"client_req_id"] = requestId;
        }
        argsWithTicket = awt;
    }

    NSData* json = [NSJSONSerialization dataWithJSONObject:argsWithTicket options:0 error:&error];

    if (error != nil) {
        [self failWithError:error];
        return;
    }

    _requestSize = json.length;
    _request = [NSMutableURLRequest
        requestWithURL:_url
        cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
        timeoutInterval:120.0f];
    
    if (json != nil) {
        [_request setHTTPBody:json];
        [_request setValue:HTTP_CONTENT_TYPE_JSON forHTTPHeaderField:@"Content-Type"];
    }
    [_request setHTTPMethod:@"POST"];

    if (([FLApi api].credentials != nil) && ([FLApi api].credentials.cookie != nil)) {
        [_request addValue:[NSString stringWithFormat:@"token_id=%@", [FLApi api].credentials.cookie] forHTTPHeaderField:@"Cookie"];
    }

    [_request addValue:@"gzip" forHTTPHeaderField:@"accept-encoding"];
    [_request addValue: [FLApi userAgentString] forHTTPHeaderField:@"User-Agent"];

    assert([NSURLConnection canHandleRequest:_request]);

    _connection = [[FLURLConnectionFactory factory]connectionForRequest:_request delegate:self];

    if (_connection == nil) {
        [self failWithError:[FLError errorWithCode:FLEEP_ERROR_TECH_FAILURE]];
    }
}

- (void)failWithError:(NSError *)error
{
    _request = nil;
    _connection = nil;
    BOOL isNetworkError = [FLApi isNetworkFailure:error];
    BOOL isServerError = [error.domain isEqualToString:FLEEP_ERROR_DOMAIN]
        && (error.code >= 500) && (error.code <= 599);

    _canRetry = isNetworkError || isServerError;

    [[FLApi api] request:self didFailWithError:error];
}

- (void)cancel
{
    [_connection cancel];
    [self failWithError:[FLError errorWithCode:FLEEP_ERROR_CANCELLED]];
#ifdef DELAY_API_RESPONSES
    [NSObject cancelPreviousPerformRequestsWithTarget:[FLApi api] selector:@selector(requestCompleted:)
        object:self];
#endif
}

+ (NSString*)requestAsLogString:(NSObject *)request
{
    if (request == nil) {
        return @"nil";
    }

    NSObject* sanitizedRequest = request;

    if ([request isKindOfClass:[NSDictionary class]]) {
        sanitizedRequest = [FLLogSanitization sanitizeDictionary:(NSDictionary*)request];
    }
    NSError* error = nil;

    return [[NSString alloc] initWithData:[NSJSONSerialization
        dataWithJSONObject:sanitizedRequest options:0 error:&error] encoding:NSUTF8StringEncoding];
}

- (NSString*)description
{
    NSString* response = nil;
    if (_requestForLog == nil) {
        _requestForLog = [FLApiRequest requestAsLogString:_arguments];
    }

    if (self.responseBody != nil) {
#ifdef PRETTY_PRINT_API_RESPONSES
        NSError* error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:self.responseBody options:0 error:&error];
        if (error == nil) {
            response = [[NSString alloc] initWithData:[NSJSONSerialization
                dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&error]
                encoding:NSUTF8StringEncoding];
        } else {
            response = [[NSString alloc] initWithData:self.responseBody encoding:NSUTF8StringEncoding];
        }
#else
        response = [[NSString alloc] initWithData:self.responseBody encoding:NSUTF8StringEncoding];
#endif
    }
    return [NSString stringWithFormat:@"<%@> %@ => %@",
        [_url absoluteString], _requestForLog, response];
}

// NSURLConnectionDelegate protocol
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self failWithError:error];
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    return YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)r
{
    assert([r isKindOfClass:[NSHTTPURLResponse class]]);
    NSHTTPURLResponse* response = (NSHTTPURLResponse*)r;

    _httpStatus = response.statusCode;
    _contentType = [response.allHeaderFields objectForKey:@"Content-Type"];
    
    if (_httpStatus == HTTP_STATUS_SUCCESS) {
        NSString* sessionCookie = [[response allHeaderFields] valueForKey:@"Set-Cookie"];
        if (sessionCookie != nil && [sessionCookie hasPrefix:@"token_id="] &&
        [sessionCookie characterAtIndex:(36 + 9)] == ';') {
            sessionCookie = [sessionCookie substringWithRange:NSMakeRange(9, 36)];
            if ([FLApi api].credentials != nil) {
                [FLApi api].credentials.cookie = sessionCookie;
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_responseBody == nil) {
        _responseBody = [NSMutableData dataWithData:data];
    } else {
        [_responseBody appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    FLApi* api = [FLApi api];

#ifdef DELAY_API_RESPONSES
    if (self.tag != APIREQUEST_TAG_LONGPOLL) {
        [api performSelector:@selector(requestCompleted:) withObject:self afterDelay:5.0f];
    } else {
        [api requestCompleted:self];
    }
#else
    [api requestCompleted:self];
#endif
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [[FLApi api]connection:connection willSendRequestForAuthenticationChallenge:challenge];
}

@end

