//
//  FLFileDownloader.m
//  Fleep
//
//  Created by Erik Laansoo on 23.05.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLMessageFileDownloader.h"
#import "FLApi.h"
#import "FLUserCredentials.h"
#import "FLApiInternal.h"
#import "FLUtils.h"

@implementation FLMessageFileDownloader
{
    NSString* _messageId;
}

@synthesize messageId = _messageId;

+ (NSURL*)localBaseURL
{
    NSURL* baseURL = [super localBaseURL];
    return [baseURL URLByAppendingPathComponent:@"files"];
}

- (id)initWithMessage:(Message*)message
{
    NSString* localName =[NSString stringWithFormat:@"%@/%ld-%@",
        message.conversation_id,
        (long)message.message_nr.integerValue, message.representation.fileName];

    if (self = [super initWithRemoteURL:message.representation.fileUrl
        localRelativePath:localName expectedSize:message.representation.fileSize]) {
        _messageId = message.guid;
    }
    return self;
}

@end

