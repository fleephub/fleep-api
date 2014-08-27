//
//  Conversation+Serialization.m
//  Fleep
//
//  Created by Erik Laansoo on 23.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLDataModel.h"
#import "FLDataModelInternal.h"
#import "ConversationInternal.h"

@implementation Conversation (Serialization)

- (NSError*) updateMembersFromJson:(FLJsonParser*) json
{
    NSArray* teams = [json extractObject:@"teams" class:NSArray.class defaultValue:nil];
    if (teams != nil) {
        NSData* serializedTeams = [NSJSONSerialization dataWithJSONObject:teams options:0 error:nil];
        self.teams = [[NSString alloc] initWithData:serializedTeams encoding:NSUTF8StringEncoding];
    }

    NSArray* pl = [json extractObject:@"members" class:[NSArray class] defaultValue:nil];
    if (pl == nil) {
        return nil;
    }

    NSMutableSet* nm = [[NSMutableSet alloc]init];
    
    for (id contactId in pl) {
        if (![contactId isKindOfClass:[NSString class]]) {
            return [FLError errorWithCode:FLEEP_ERROR_INCORRECT_TYPE];
        }

        FLMember* oldMember = [self.sortedMembers memberByAccountId:contactId];

        Member* m = [[FLDataModel dataModel]memberFromConversation:self withAccountId:contactId];
        if (m == nil) {
            return [FLError errorWithCode:FLEEP_ERROR_CORE_DATA_CREATE];
        }

        if (oldMember != nil) {
            m.read_horizon = @(oldMember.readHorizon);
        }
        [nm addObject:m];
    }
    self.members = nm;

    return nil;
}

- (NSError*) deserializeFromJson:(FLJsonParser*) json
{
    self.conversation_id = [json extractString:@"conversation_id"];
    self.read_message_nr = [json extractInt:@"read_message_nr"];
    self.inbox_message_nr = [json extractInt:@"inbox_message_nr" defaultValue:nil];
    self.last_message_nr = [json extractInt:@"last_message_nr"];
    self.can_post = [json extractBool:@"can_post"];
    self.bw_message_nr = [json extractInt:@"bw_message_nr" defaultValue:nil];
    self.fw_message_nr = [json extractInt:@"fw_message_nr" defaultValue:nil];
    self.file_horizon = [json extractInt:@"file_horizon" defaultValue:[NSNumber numberWithInteger:0]];
    self.pin_horizon = [json extractInt:@"pin_horizon" defaultValue:[NSNumber numberWithInteger:0]];
    self.topic = [json extractString:@"topic" defaultValue:@""];
    self.join_message_nr = [json extractInt:@"join_message_nr"];
    self.hide_message_nr = [json extractInt:@"hide_message_nr" defaultValue:[NSNumber numberWithInteger: 0]];
    self.unread_count = [json extractInt:@"unread_count"];
    self.last_inbox_nr = [json extractInt:@"last_inbox_nr" defaultValue:@(0)];
    self.cmail = [json extractString:@"cmail" defaultValue:nil];

    self.last_message_time = [json extractDate:@"last_message_time"];
    self.alert_level = [json extractEnum:@"mk_alert_level" valueMap:FLClassificators.mk_alert_level
        defaultValue:@(FLAlertLevelDefault)];

    if (json.error == nil) {
        return [self updateMembersFromJson:json];
    };
    return json.error;
}

- (NSError*) updateFromJson:(FLJsonParser*) json
{
    NSNumber* newReadMessageNr = [json extractInt:@"read_message_nr" defaultValue:self.read_message_nr];
    if (![newReadMessageNr isEqual:self.read_message_nr] && ![self isFieldDirty:FLConversationFieldHorizonBack]) {
        if (![self isFieldDirty:FLConversationFieldHorizonForward] || (newReadMessageNr.integerValue > self.read_message_nr.integerValue)) {
            self.read_message_nr = newReadMessageNr;
            [self willChangeProperty:@"read_message_nr"];
        }
    }

    NSNumber* new_last_message_nr = [json extractInt:@"last_message_nr" defaultValue:self.last_message_nr];
    if (![new_last_message_nr isEqual:self.last_message_nr]) {
        self.last_message_nr = new_last_message_nr;
        [self willChangeProperty:@"last_message_nr"];
    }
    NSNumber* new_inbox_message_nr = [json extractInt:@"inbox_message_nr" defaultValue:self.inbox_message_nr];
    if (![new_inbox_message_nr isEqual:self.inbox_message_nr]) {
        self.inbox_message_nr = new_inbox_message_nr;
        [self willChangeProperty:@"inbox_message_nr"];
    }
    NSNumber* new_bw_message_nr = [json extractInt:@"bw_message_nr" defaultValue:self.bw_message_nr];
    if ((new_bw_message_nr != nil) && ![new_bw_message_nr isEqual:self.bw_message_nr]) {
        self.bw_message_nr = new_bw_message_nr;
        [self willChangeProperty:@"bw_message_nr"];
    }
    NSNumber* new_fw_message_nr = [json extractInt:@"fw_message_nr" defaultValue:self.fw_message_nr];
    if ((new_fw_message_nr != nil) && ![new_fw_message_nr isEqual:self.fw_message_nr]) {
        if (new_fw_message_nr.integerValue < self.fw_message_nr.integerValue) {
 //           assert(NO);
        } else {
            self.fw_message_nr = new_fw_message_nr;
        }
        [self willChangeProperty:@"fw_message_nr"];
    }

    NSNumber* new_join_message_nr = [json extractInt:@"join_message_nr" defaultValue:self.join_message_nr];
    if (![new_join_message_nr isEqual:self.join_message_nr]) {
        self.join_message_nr = new_join_message_nr;
    }

    NSNumber* new_hide_message_nr = [json extractInt:@"hide_message_nr" defaultValue:self.hide_message_nr];
    if (![new_hide_message_nr isEqual:self.hide_message_nr]) {
        self.hide_message_nr = new_hide_message_nr;
        [self willChangeProperty:@"hide_message_nr"];
    }
    NSNumber* new_file_horizon = [json extractInt:@"file_horizon" defaultValue:self.file_horizon];
    if (![new_file_horizon isEqualToNumber:self.file_horizon]) {
        self.file_horizon = new_file_horizon;
        [self willChangeProperties:@[@"file_horizon", @"allFilesLoaded"]];
    }
    NSNumber* new_pin_horizon = [json extractInt:@"pin_horizon" defaultValue:self.pin_horizon];
    if (![new_pin_horizon isEqualToNumber:self.pin_horizon]) {
        self.pin_horizon = new_pin_horizon;
        [self willChangeProperty:@"pin_horizon"];
    }

    NSString* new_topic = [json extractString:@"topic" defaultValue:self.topic];
    if (![new_topic isEqual:self.topic]) {
        self.topic = new_topic;
        [self willChangeProperty:@"topic"];
    }
    NSDate* new_last_message_time = [json extractDate:@"last_message_time" defaultValue:self.last_message_time];
    if (![new_last_message_time isEqualToDate:self.last_message_time]) {
        self.last_message_time = new_last_message_time;
        [self willChangeProperty:@"last_message_time"];
    }

    NSNumber* new_can_post = [json extractBool:@"can_post" defaultValue:self.can_post.boolValue];
    if (new_can_post.boolValue != self.can_post.boolValue) {
        self.can_post = new_can_post;
        [self willChangeProperty:@"can_post"];
    }

    NSNumber* new_alert_level = [json extractEnum:@"mk_alert_level" valueMap:FLClassificators.mk_alert_level
        defaultValue:self.alert_level];

    if (new_alert_level.integerValue != self.alert_level.integerValue) {
        self.alert_level = new_alert_level;
        [self willChangeProperty:@"alert_level"];
    }

    [self setUnreadCount:[json extractInt:@"unread_count" defaultValue:self.unread_count].integerValue];

    NSNumber* new_last_inbox_nr = [json extractInt:@"last_inbox_nr" defaultValue:self.last_inbox_nr];
    if (![new_last_inbox_nr isEqualToNumber:self.last_inbox_nr]) {
        self.last_inbox_nr = new_last_inbox_nr;
        [self willChangeProperty:@"last_inbox_nr"];
    }

    NSString* new_cmail = [json extractString:@"cmail" defaultValue:self.cmail];
    if (![new_cmail isEqualToString:self.cmail]) {
        self.cmail = new_cmail;
    }

    if (json.error == nil) {
        return [self updateMembersFromJson:json];
    };

    return json.error;
}

@end
