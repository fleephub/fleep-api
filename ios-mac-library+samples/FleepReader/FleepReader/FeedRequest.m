//
//  FeedRequest.m
//  FleepReader
//
//  Created by Erik Laansoo on 07.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FeedRequest.h"
#import "Feed.h"

@implementation FeedRequest
{
    __weak id<FeedRequestDelegate> _delegate;
    NSURL* _url;
    NSMutableData* _data;
    NSInteger _httpStatus;
}

- (void)failWithError:(NSError*)error
{
    [_delegate feedRequestFailedWithError:error];
}

- (id)initWithURL:(NSString*)url delegate:(id<FeedRequestDelegate>)delegate
{
    if (self = [super init]) {
        _url = [[NSURL alloc] initWithString:url];
        _delegate = delegate;

    NSURLRequest* request = [NSURLRequest requestWithURL:_url];
    NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
    _data = [[NSMutableData alloc]init];
    if (connection == nil) {
        [self failWithError: [[FeedError alloc] initWithMessage:@"Connection failed"]];
        return nil;
    }
    }
    return self;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self failWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)r
{
    assert([r isKindOfClass:[NSHTTPURLResponse class]]);
    NSHTTPURLResponse* response = (NSHTTPURLResponse*)r;
    _httpStatus = [response statusCode];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_httpStatus != 200) {
        [self failWithError:[[FeedError alloc]
            initWithMessage: [NSString stringWithFormat:@"HTTP %ld", (long)_httpStatus]]];
    } else {
        NSLog(@"%ld bytes received from %@", (long)_data.length, _url);
        RSSParser* rp = [[RSSParser alloc] initWithData:_data];
        if (![rp parse]) {
            [self failWithError:rp.parserError];
        } else {
            if (rp.type == FeedTypeUnrecognized) {
                [self failWithError:[[FeedError alloc] initWithMessage:@"Received data is well-formed xml but not recognized as RSS or Atom"]];
            } else {
                [_delegate feedRequestCompletedWithResult:rp];
            }
        }
    }
}

@end
