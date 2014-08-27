//
//  FLUserCredentials.h
//  Fleep
//
//  Created by Erik Laansoo on 19.06.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FLUserCredentials : NSObject
@property (nonatomic) NSString* email;
@property (nonatomic) NSString* uuid;
@property (nonatomic) NSString* cookie;
@property (nonatomic) NSString* ticket;
@property (nonatomic, readonly) BOOL valid;

- (id)initWithUserEmail:(NSString*)email;
- (id)init;
- (void)save;
- (void)erase;

@end
