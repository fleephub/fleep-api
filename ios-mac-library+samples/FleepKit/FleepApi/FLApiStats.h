//
//  FLApiStats.h
//  Fleep
//
//  Created by Erik Laansoo on 27.06.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FLApiStats : NSObject
@property (nonatomic, readonly) NSInteger bytesSent;
@property (nonatomic, readonly) NSInteger bytesReceived;
@property (nonatomic, readonly) NSInteger messagesSent;
@property (nonatomic, readonly) NSInteger messagesReceived;
@property (nonatomic, readonly) NSDate* lastResponseTime;

- (void)load;
- (void)save;
- (void)reportTrafficSent:(NSInteger)sent received:(NSInteger)received;
- (void)reportSentMessage;
- (void)reportReceivedMessage;
@end
