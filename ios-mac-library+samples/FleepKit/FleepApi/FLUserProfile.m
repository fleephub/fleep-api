//
//  FLUserProfile.m
//  Fleep
//
//  Created by Erik Laansoo on 23.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLUserProfile.h"
#import "FLJsonParser.h"
#import "FLApi.h"
#import "FLApiInternal.h"

FLUserProfile* _userProfile;

@implementation FLUserProfile
{
    NSArray* _aliases;
    NSString* _contactId;
    FLAccountEmailSetting _accountEmailSetting;
    NSMutableSet* _clientFlags;
}

@synthesize contactId = _contactId;

+ (FLUserProfile*)userProfile
{
    assert(_userProfile != nil);
    return _userProfile;
}

- (id)init
{
    if (self = [super init]) {
        _userProfile = self;
        FLApi* api = [FLApi api];
        _contactId = api.credentials.uuid;
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        _accountEmailSetting = [defaults integerForKey:@"AccountEmailSetting"];
        NSArray* clientFlags = [defaults objectForKey:@"ClientFlags"];
        if (clientFlags != nil) {
            _clientFlags = [[NSMutableSet alloc] initWithArray:clientFlags];
        }
        _aliases = [defaults arrayForKey:@"aliases"];
        assert(_contactId.length > 0);
    }
    return self;
}

- (BOOL)isSelf:(NSString*)contactId
{
    return [contactId isEqualToString:_contactId];
}

- (void)notifyContactsChanged:(NSSet*)changedContacts
{
    BOOL changed = NO;
    for (NSString* cid in _aliases) {
        if ([changedContacts containsObject:cid]) {
            changed = YES;
            break;
        }
    }

    if (changed) {
        [self willChangeValueForKey:@"aliases"];
        [self didChangeValueForKey:@"aliases"];
    }
}

- (NSArray*)aliases
{
    return _aliases;
}

- (FLAccountEmailSetting)accountEmailSetting
{
    return _accountEmailSetting;
}

- (void)setAccountEmailSetting:(FLAccountEmailSetting)accountEmailSetting
{
    if (accountEmailSetting == _accountEmailSetting) {
        return;
    }
    
    _accountEmailSetting = accountEmailSetting;
    [[NSUserDefaults standardUserDefaults] setInteger:_accountEmailSetting forKey:@"AccountEmailSetting"];

    if (_accountEmailSetting == FLAccountEmailSettingUnknown) {
        return;
    }

    NSString* interval = [FLClassificators mk_email_interval_str:_accountEmailSetting];

    if (interval == nil) {
        return;
    }
    
    FLApiRequest *request = [[FLApiRequest alloc]
        initWithMethod:@"account/configure"
        arguments: @{ @"email_interval" : interval } ];

    [[FLApi api] sendRequest:request];
}

- (void)updateSettings:(FLJsonParser*)json
{
    NSArray* aliases = [json extractObject:@"alias_account_ids" class:NSArray.class defaultValue:nil];
    if (aliases != nil) {
        [self willChangeValueForKey:@"aliases"];
        _aliases = aliases;
        [self didChangeValueForKey:@"aliases"];
        [[NSUserDefaults standardUserDefaults] setObject:aliases forKey:@"aliases"];
    }

    NSNumber* accountEmailSetting =
        [json extractEnum:@"mk_email_interval" valueMap:FLClassificators.mk_email_interval defaultValue:nil];

    if ((accountEmailSetting != nil) && (accountEmailSetting.integerValue != FLAccountEmailSettingUnknown)) {
        [self willChangeValueForKey:@"accountEmailSetting"];
        _accountEmailSetting = accountEmailSetting.integerValue;
        [self didChangeValueForKey:@"accountEmailSetting"];
        [[NSUserDefaults standardUserDefaults] setInteger:_accountEmailSetting forKey:@"AccountEmailSetting"];
    }

    NSArray* clientFlags = [json extractObject:@"client_flags" class:NSArray.class defaultValue:nil];
    if (clientFlags != nil) {
        [self willChangeValueForKey:@"clientFlags"];
        _clientFlags = [[NSMutableSet alloc] initWithArray:clientFlags];
        [self didChangeValueForKey:@"clientFlags"];
    }
}

- (BOOL)isClientFlagSet:(NSString *)flagName
{
    return (_clientFlags != nil) && [_clientFlags containsObject:flagName];
}

- (void)setClientFlag:(NSString *)name value:(BOOL)value
{
    if (value == [self isClientFlagSet:name]) {
        return;
    }

    [self willChangeValueForKey:@"clientFlags"];
    if (value) {
        if (_clientFlags == nil) {
            _clientFlags = [[NSMutableSet alloc] init];
        }
        [_clientFlags addObject:name];
    } else {
        [_clientFlags removeObject:name];
    }

    [self didChangeValueForKey:@"clientFlags"];
    [[NSUserDefaults standardUserDefaults] setObject:_clientFlags.allObjects forKey:@"ClientFlags"];
    FLApiRequest* setFlagRequest = [[FLApiRequest alloc]
        initWithMethod:@"account/set_flag" arguments:
        @{
            @"client_flag" : name,
            @"bool_value" : [NSNumber numberWithBool:value]
        }];
    [[FLApi api] sendRequest:setFlagRequest];
}

- (void)logout
{
    _userProfile = nil;
}

- (BOOL)avatarsEnabled
{
    return ![self isClientFlagSet:CLIENT_FLAG_AVATARS_DISABLED];
}

@end
