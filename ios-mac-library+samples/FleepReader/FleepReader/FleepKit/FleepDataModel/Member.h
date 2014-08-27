//
//  Participant.h
//  Fleep
//
//  Created by Erik Laansoo on 27.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Conversation;

@interface Member : NSManagedObject

@property (nonatomic, retain) NSString * account_id;
@property (nonatomic, retain) Conversation *conversation;
@property (nonatomic, retain) NSNumber *read_horizon;
@end

@interface FLMember : NSObject
@property (nonatomic, readonly) NSString* accountId;
@property (nonatomic, readonly) NSString* email;
@property (nonatomic, readonly) NSString* displayName;
@property (nonatomic, readonly) BOOL isLocalContact;
@property (nonatomic, readonly) NSInteger readHorizon;
@property (nonatomic) BOOL isAdded;

- (id)initWithMember:(Member*)member;
- (id)initWithEmail:(NSString*)email andName:(NSString*)name;
- (NSComparisonResult)compareWith:(FLMember*)anotherMember;
@end