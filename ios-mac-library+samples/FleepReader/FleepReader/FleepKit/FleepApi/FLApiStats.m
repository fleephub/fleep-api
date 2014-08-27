//
//  FLApiStats.m
//  Fleep
//
//  Created by Erik Laansoo on 27.06.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLApiStats.h"

@implementation FLApiStats
{
    NSInteger _bytesReceived;
    NSInteger _bytesSent;
    NSInteger _messagesReceived;
    NSInteger _messagesSent;
}

@synthesize
    bytesSent = _bytesSent,
    bytesReceived = _bytesReceived,
    messagesSent = _messagesSent,
    messagesReceived = _messagesReceived,
    lastResponseTime = _lastResponseTime;

- (void)load
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    _bytesSent = [defaults integerForKey:@"stats_bytes_sent"];
    _bytesReceived = [defaults integerForKey:@"stats_bytes_received"];
    _messagesSent = [defaults integerForKey:@"stats_messages_sent"];
    _messagesReceived = [defaults integerForKey:@"stats_messages_received"];
    NSTimeInterval lrt = [defaults floatForKey:@"stats_last_response_time"];
    if (lrt > 0.0f) {
        _lastResponseTime = [NSDate dateWithTimeIntervalSinceReferenceDate:lrt];
    }
}

- (void)save
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:_bytesSent forKey:@"stats_bytes_sent"];
    [defaults setInteger:_bytesReceived forKey:@"stats_bytes_received"];
    [defaults setInteger:_messagesReceived forKey:@"stats_messages_received"];
    [defaults setInteger:_messagesSent forKey:@"stats_messages_sent"];
    if (_lastResponseTime != nil) {
        [defaults setFloat:_lastResponseTime.timeIntervalSinceReferenceDate forKey:@"stats_last_response_time"];
    }
}

- (NSString*) description
{
    return [NSString stringWithFormat:
        @"Bytes sent: %ld\nBytes received: %ld\nMessages received: %ld\nMessages sent: %ld\nLast response: %@",
        (long)_bytesSent, (long)_bytesReceived, (long)_messagesReceived, (long)_messagesSent,
            _lastResponseTime];
}

- (void)reportTrafficSent:(NSInteger)sent received:(NSInteger)received
{
    _bytesSent += sent;
    _bytesReceived += received;
    if (received > 0) {
        _lastResponseTime = [NSDate date];
    }
}

- (void)reportSentMessage
{
    _messagesSent++;
}

- (void)reportReceivedMessage
{
    _messagesReceived++;
}

@end
