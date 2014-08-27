//
//  FLUserCredentials.m
//  Fleep
//
//  Created by Erik Laansoo on 19.06.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLUserCredentials.h"
#import "FLUtils.h"
#import <Security/Security.h>

@implementation FLUserCredentials

@synthesize email = _email;
@synthesize uuid = _uuid;
@synthesize cookie = _cookie;
@synthesize ticket = _ticket;

- (BOOL)valid
{
    return (_email != nil) && (_uuid != nil) && (_cookie != nil) && (_ticket != nil);
}

- (id)init
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* uuid = [defaults stringForKey:@"LocalUserUUID"];
    NSString* email = [defaults stringForKey:@"LocalUserEmail"];

    if (email == nil) {
        return [super init];
    }
    
    if (self = [self initWithUserEmail:email]) {
        self.uuid = uuid;
        FLLogInfo(@"FLUserCredentials::InitWithUser(%@): %@", email, self.valid ? @"Valid" : @"Invalid");
    }

    if (!self.valid) {
        FLLogError(@"FLUserCredentials: init (%@) invalid. ticket = %ld, cookie = %ld", email,
            (long)self.ticket.length, (long)self.cookie.length);
    }

    return self;
}

#ifdef TARGET_IS_IPHONE
- (id)initWithUserEmail:(NSString*)email
{
    if (self = [super init]) {
        _email = email;
        CFTypeRef res;
        NSDictionary* secItem = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrAccount: _email,
            (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue
        };

        OSStatus error = SecItemCopyMatching((__bridge CFDictionaryRef)secItem, &res);
        if (error == errSecSuccess) {
            NSData* serializedData = (__bridge_transfer NSData*)res;
            NSError* error;
            NSDictionary* data = [NSJSONSerialization JSONObjectWithData:serializedData options:0 error:&error];
            if (error != nil) {
                FLLogError(@"FLUserCredentials::InitWithUser: %@", error);
            } else {
                _cookie = data[@"cookie"];
                _ticket = data[@"ticket"];
            }
        } else  {
            FLLogError(@"SecItemCopyMatching returned %ld", (long)error);
        }
    }
    return self;
}

- (void)save
{
    if (!self.valid) {
        return;
    }
    NSDictionary* data = @{@"cookie" : _cookie, @"ticket" : _ticket };
    NSData* serializedData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];

    NSDictionary* secItem = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: _email,
        (__bridge id)kSecAttrAccessible : (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
        (__bridge id)kSecValueData : serializedData
    };

    OSStatus error = SecItemAdd((__bridge CFDictionaryRef)secItem, NULL);
    if (error != errSecSuccess) {
        FLLogError(@"SecItemAdd returned %ld", (long)error);
    } else {
        FLLogInfo(@"FLUserCredentials::Save completed");
    }

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:_uuid forKey:@"LocalUserUUID"];
    [defaults setValue:_email forKey:@"LocalUserEmail"];
    [defaults synchronize];
}

- (void)erase
{
    NSDictionary* secItem = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: _email,
    };

    OSStatus error = SecItemDelete((__bridge CFDictionaryRef)secItem);
    if (error != errSecSuccess) {
        FLLogError(@"SecItemDelete returned %ld", (long)error);
    }
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"LocalUserUUID"];
    [defaults removeObjectForKey:@"LocalUserEmail"];
    _email = nil;
    _cookie = nil;
    _ticket = nil;
    _uuid = nil;
    [defaults synchronize];
}

#else

- (id)initWithUserEmail:(NSString*)email
{
    if (self = [super init]) {
        _email = email;
        _cookie = [[NSUserDefaults standardUserDefaults] stringForKey:@"Cookie"];
        _ticket = [[NSUserDefaults standardUserDefaults] stringForKey:@"Ticket"];
    }
    return self;
}

- (void)save
{
    if (!self.valid) {
        return;
    }

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:_uuid forKey:@"LocalUserUUID"];
    [defaults setValue:_email forKey:@"LocalUserEmail"];
    [defaults setObject:_cookie forKey:@"Cookie"];
    [defaults setObject:_ticket forKey:@"Ticket"];
}

- (void)erase
{
    [[NSUserDefaults standardUserDefaults]removeObjectForKey:@"Cookie"];
    [[NSUserDefaults standardUserDefaults]removeObjectForKey:@"Ticket"];
    _email = nil;
    _cookie = nil;
    _ticket = nil;
    _uuid = nil;
}

#endif
@end
