//
//  FLClassificators.m
//  Fleep
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLClassificators.h"

@implementation FLClassificators

+ (NSDictionary*)mk_entity_type
{
    static NSDictionary* mket = nil;
    if (mket == nil) {
        mket = @{
            @"contact":@(FLEntityTypeContact),
            @"conv":@(FLEntityTypeConversation),
            @"message":@(FLEntityTypeMessage),
            @"activity":@(FLEntityTypeActivity),
            @"hook":@(FLEntityTypeHook),
            @"team":@(FLEntityTypeTeam),
            @"request":@(FLEntityTypeRequest)
        };
    }
    return mket;
}

+ (NSDictionary*) mk_message_type
{
    static NSDictionary* mkmt = nil;
    if (mkmt == nil) {
        mkmt = @{
            @"text":@(FLMessageTypeText),
            @"create":@(FLMessageTypeCreate),
            @"add":@(FLMessageTypeAdd),
            @"leave":@(FLMessageTypeLeave),
            @"topic":@(FLMessageTypeTopic),
            @"email":@(FLMessageTypeEmail),
            @"kick":@(FLMessageTypeRemove),
            @"file":@(FLMessageTypeFile),
            @"disclose":@(FLMessageTypeDisclose),
            @"hook":@(FLMessageTypeHook),
            @"sysmsg":@(FLMessageTypeSystem),
            @"alerts":@(FLMessageTypeAlerts),
            @"replace":@(FLMessageTypeReplace),
            @"bounce":@(FLMessageTypeBounce)
        };
    }
    return mkmt;
}

+ (NSDictionary*)mk_account_status
{
    static NSDictionary* mkas = nil;
    if (mkas == nil) {
        mkas = @{
            @"new": @(FLAccountStatusNew),
            @"valid": @(FLAccountStatusValid),
            @"active": @(FLAccountStatusActive),
            @"banned": @(FLAccountStatusBanned),
            @"closed": @(FLAccountStatusClosed),
            @"beta": @(FLAccountStatusBeta),
            @"alias": @(FLAccountStatusAlias)
        };
    }
    return mkas;
}

+ (NSDictionary*)mk_email_interval
{
    static NSDictionary* mkei = nil;
    if (mkei == nil) {
        mkei = @{
            @"default" : @(FLAccountEmailSettingMessage),
            @"daily" : @(FLAccountEmailSettingDaily),
            @"never" : @(FLAccountEmailSettingOff)
        };
    }
    return mkei;
}

+ (NSDictionary*)mk_alert_level
{
    static NSDictionary* mkal = nil;
    if (mkal == nil) {
        mkal = @{
            @"default" : @(FLAlertLevelDefault),
            @"never" : @(FLAlertLevelNever)
        };
    }
    return mkal;
}

+ (NSDictionary*)mk_message_tag
{
    static NSDictionary* mkmt = nil;
    if (mkmt == nil) {
        mkmt = @{
            @"pin": @(FLMessageTagPin),
            @"unpin": @(FLMessageTagUnpin),
            @"unlock": @(FLMessageTagUnlock)
        };
    }
    return mkmt;
}

+ (NSInteger)extractTags:(FLJsonParser*)json values:(NSDictionary*)values
{
    NSArray* tags = [json extractObject:@"tags" class:NSArray.class defaultValue:nil];
    if (tags == nil) {
        return 0;
    }

    NSInteger result = 0;
    for (NSString* tag in tags) {
        NSNumber* value = values[tag];
        
        if (value != nil) {
            result |= (1 << value.integerValue);
        }
    }

    return result;
}

+ (NSString*)lookupKey:(NSNumber*)value inDictionary:(NSDictionary*)dict default:(NSNumber*)def
{
    __block id result = nil;
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([obj isEqual:value]) {
            result = key;
            *stop = YES;
        }
    }];

    if ((result == nil) && (def != nil)) {
        result = [self lookupKey:def inDictionary:dict default:nil];
        assert(result != nil);
    }
    
    return (NSString*)result;
}

+ (NSString*)mk_email_interval_str:(FLAccountEmailSetting)value
{
    return [self lookupKey:@(value) inDictionary:self.mk_email_interval default:@(FLAccountEmailSettingDaily)];
}

+ (NSString*)mk_alert_level_str:(FLAlertLevel)value
{
    return [self lookupKey:@(value) inDictionary:self.mk_alert_level default:@(FLAlertLevelDefault)];
}

@end
