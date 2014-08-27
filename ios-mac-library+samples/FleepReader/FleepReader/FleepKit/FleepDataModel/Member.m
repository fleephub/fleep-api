//
//  Participant.m
//  Fleep
//
//  Created by Erik Laansoo on 27.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLApi.h"
#import "FLDataModel.h"
#import "FLUserProfile.h"

@implementation Member

@dynamic account_id;
@dynamic conversation;
@dynamic read_horizon;

@end

@implementation FLMember
{
    NSString* _accountId;
    NSString* _email;
    NSString* _displayName;
    NSInteger _readHorizon;
    BOOL _isAdded;
    Member* _member;
}

@synthesize accountId = _accountId, email = _email, displayName = _displayName;
@synthesize isAdded = _isAdded;
@synthesize readHorizon = _readHorizon;

- (id)initWithMember:(Member*)member
{
    if (self = [super init]) {
        _accountId = member.account_id;
        _member = member;
        Contact* c = [[FLDataModel dataModel]contactFromId:_accountId];
        if (c != nil) {
            _email = c.email;
            _displayName = c.displayNameWithYou;
        } else {
            _displayName = @"?";
        }
        _readHorizon = _member.read_horizon.integerValue;
    }
    return self;
}

- (id)initWithEmail:(NSString*)email andName:(NSString *)name
{
    if (self = [super init]) {
        _email = email;
        Contact* c = [[FLDataModel dataModel]contactFromEmail:_email];
        if (c != nil) {
            _accountId = c.account_id;
            _displayName = c.displayNameWithYou;
        } else {
            if ((name != nil) && (name.length > 0)) {
                _displayName = name;
            } else {
                _displayName = email;
            }
        }
    }
    return self;
}

- (NSComparisonResult)compareWith:(FLMember*)anotherMember
{
    if (self.isAdded != anotherMember.isAdded) {
        return self.isAdded ? NSOrderedDescending : NSOrderedAscending;
    }

    return [self.displayName compare:anotherMember.displayName options:NSCaseInsensitiveSearch];
}

- (BOOL)isLocalContact
{
    return [[FLUserProfile userProfile] isSelf:self.accountId];
}

- (void)setReadHorizon:(NSInteger)readHorizon
{
    [self willChangeValueForKey:@"readHorizon"];
    _readHorizon = readHorizon;
    if (_member != nil) {
        _member.read_horizon = @(_readHorizon);
    }
    [self didChangeValueForKey:@"readHorizon"];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"FLMember: <%@>, ReadHorizon = %ld",
        _email, (long)_readHorizon];
}

@end