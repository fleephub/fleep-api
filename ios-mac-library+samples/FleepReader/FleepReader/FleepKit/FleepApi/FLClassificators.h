//
//  FLClassificators.h
//  Fleep
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLJsonParser.h"

typedef NS_ENUM(NSInteger, FLEntityType) {
    FLEntityTypeContact = 1,
    FLEntityTypeConversation = 2,
    FLEntityTypeMessage = 3,
    FLEntityTypeActivity = 4,
    FLEntityTypeHook = 5,
    FLEntityTypeTeam = 6,
    FLEntityTypeRequest = 7
};

typedef NS_ENUM(NSInteger, FLMessageType) {
    FLMessageTypeText = 1,
    FLMessageTypeCreate = 2,
    FLMessageTypeAdd = 3,
    FLMessageTypeLeave = 4,
    FLMessageTypeTopic = 5,
    FLMessageTypePinboard = 8,
    FLMessageTypeEmail = 9,
    FLMessageTypeRemove = 10,
    FLMessageTypeFile = 11,
    FLMessageTypeDisclose = 12,
    FLMessageTypeHook = 13,
    FLMessageTypeSystem = 14,
    FLMessageTypeAlerts = 15,
    FLMessageTypeReplace = 16,
    FLMessageTypeBounce = 17,
    FLMessageTypeDeletedFile = 18
};

typedef NS_ENUM(NSInteger, FLAccountStatus) {
    FLAccountStatusNew = 1,
    FLAccountStatusValid = 2,
    FLAccountStatusActive = 3,
    FLAccountStatusBeta = 4,
    FLAccountStatusBanned = 5,
    FLAccountStatusClosed = 6,
    FLAccountStatusAlias = 7
};

typedef NS_ENUM(NSInteger, FLAccountEmailSetting) {
    FLAccountEmailSettingUnknown = 0,
    FLAccountEmailSettingMessage = 1,
    FLAccountEmailSettingDaily = 2,
    FLAccountEmailSettingOff = 3
};

typedef NS_ENUM(NSInteger, FLAlertLevel) {
    FLAlertLevelDefault = 1,
    FLAlertLevelNever = 2
};

typedef NS_ENUM(NSInteger, FLMessageTag) {
    FLMessageTagPin = 0,
    FLMessageTagUnpin = 1,
    FLMessageTagUnlock = 2
};

#define MESSAGE_TAG_PIN (1 << FLMessageTagPin)
#define MESSAGE_TAG_UNPIN (1 << FLMessageTagUnpin)
#define MESSAGE_TAG_UNLOCK (1 << FLMessageTagUnlock)

@interface FLClassificators : NSObject
+ (NSDictionary*)mk_message_type;
+ (NSDictionary*)mk_email_interval;
+ (NSDictionary*)mk_account_status;
+ (NSDictionary*)mk_alert_level;
+ (NSDictionary*)mk_message_tag;
+ (NSDictionary*)mk_entity_type;

+ (NSInteger)extractTags:(FLJsonParser*)json values:(NSDictionary*)values;
+ (NSString*)mk_email_interval_str:(FLAccountEmailSetting)value;
+ (NSString*)mk_alert_level_str:(FLAlertLevel)value;
@end
