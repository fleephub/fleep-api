//
//  ReaderApi.m
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "ReaderApi.h"
#import "FLApiInternal.h"
#import "DataModel.h"
#import "FLMessageStripper.h"
#import "FLApi+Actions.h"

NSString*
    kUsageText = @"Available commands:\n\n\
subscribe feed url\n\
unsubscribe [feed_id]\n\
export_opml\n\
<opml_file>";

@implementation ReaderApi

- (NSError*)handleContact:(FLJsonParser *)obj
{
    NSString* contactId = [obj extractString:@"account_id"];
    NSString* email = [obj extractString:@"email"];
    if (obj.error != nil) {
        return obj.error;
    }
    User* u = [[DataModel dataModel] userById:contactId];
    u.email = email;
    return nil;
}

- (NSError*)handleConversation:(FLJsonParser *)obj
{
    NSString* conversationId = [obj extractString:@"conversation_id"];
    NSArray* members = [obj extractObject:@"members" class:NSArray.class];
    NSString* topic = [obj extractString:@"topic"];
    NSNumber* read_message_nr = [obj extractInt:@"read_message_nr"];

    // Only handle complete conversation headers
    if (obj.error != nil) {
        return nil;
    };
    
    if (members.count != 2) {
        return nil;
    }

    NSString* contactId = nil;
    BOOL amMember = NO;
    
    for (NSString* m in members) {
        if (![m isEqualToString:self.credentials.uuid]) {
            contactId = m;
        } else {
            amMember = YES;
        }
    }

    if (!amMember) {
        return nil;
    }

    User* user = [[DataModel dataModel] userById:contactId];
    UserSubscription* s = [user subscriptionByConversationId:conversationId];
    if (s.feed_id == nil) {
        s.feed_id = [NSString stringWithFormat:@"=%@", topic];
        s.read_message_nr = read_message_nr;
    }

    return nil;
}

- (BOOL)isAdministrativeUser:(NSString*)userId
{
    static NSSet* administrators = nil;
    if (administrators == nil) {
        administrators = [[NSSet alloc] initWithArray: @[
        /* REDACTED */
        ]];
    }
    return [administrators containsObject:userId];
}

- (NSString*)handleCommand:(NSString*)command conversationId:(NSString*)conversationId
    user:(User*)user subscription:(UserSubscription*)subscription
{
    if ([command hasPrefix:@"unsubscribe"]) {
        if (command.length > 12) {
            NSString* feedURL = [command substringFromIndex:12];
            UserSubscription* us = [user subscriptionByURL:feedURL];
            if (us != nil) {
                return [user unsubscribeFromConversation:us.conversation_id];
            } else {
                return [NSString stringWithFormat:@"You are not subscribed to \"%@\"", feedURL];
            }
        } else {
            return [user unsubscribeFromConversation:subscription.conversation_id];
        }
    }

    if ([command hasPrefix:@"subscribe "]) {
        NSString* feedURL = [command substringFromIndex:10];
        return [user subscribeToUrl:feedURL postResultToConversation:conversationId];
    }

    if ([command isEqualToString:@"export_opml"]) {
        return [user feedsAsOPML];
    }

    if ([command hasPrefix:@"<?xml "]) {
        return [user loadFeedsFromOPMLFile:command];
    }

    if ([command isEqualToString:@"ping"]) {
        return @"I'm here";
    }

    if (![self isAdministrativeUser:user.contact_id]) {
        return nil;
    }

    if ([command hasPrefix:@"poll"]) {
        if (command.length > 5) {
            NSString* feedURL = [command substringFromIndex:5];
            Feed* f = [[DataModel dataModel] feedByURL:feedURL];
            [f pollWithCompletion:^{
                [self postMessage:
                    [NSString stringWithFormat: @"Feed \"%@\" polled", f.title] intoConversationWithId:conversationId
                    onSuccess:nil onError:nil];
            } onError:^(NSError* error) {
                [self postMessage: [NSString stringWithFormat:@"Poll failed for <%@> : %@", f.url, error.localizedDescription]
                 intoConversationWithId:conversationId onSuccess:nil onError:nil];
            }];
            return [NSString stringWithFormat:@"Polling \"%@\"", f.title];
        } else {
            [[DataModel dataModel] forcePoll];
            return @"All feeds reset for immediate polling";
        }
    }

    if ([command hasPrefix:@"forget_feed "]) {
        NSString* feedURL = [command substringFromIndex:12];
        return [[DataModel dataModel] forgetFeed:feedURL];
    }

    if ([command isEqualToString:@"stats"]) {
        return [[DataModel dataModel] subscripionStats];
    }

    return nil;
}

- (NSError*)handleMessage:(FLJsonParser *)obj
{
    if (self.eventHorizon <= 0) {
        return nil;
    }
    
    NSString* conversationId = [obj extractString:@"conversation_id"];
    NSNumber* messageNr = [obj extractInt:@"message_nr"];
    NSString* message = [obj extractString:@"message"];
    NSString* accountId = [obj extractString:@"account_id"];
    FLMessageType type = [obj extractEnum:@"mk_message_type" valueMap:[FLClassificators mk_message_type]].integerValue;

    if (obj.error != nil) {
        return obj.error;
    }

    if (type != FLMessageTypeText) {
        return nil;
    }
    
    if ([accountId isEqualToString:self.credentials.uuid]) {
        return nil;
    }

    User* user = [[DataModel dataModel] userById:accountId];
    UserSubscription* sub = [user subscriptionByConversationId:conversationId];

    if (sub.feed_id == nil) {
        return nil;
    }
    
    if (messageNr.integerValue <= sub.read_message_nr.integerValue) {
        return nil;
    }

    FLMessageStripper* ms = [[FLMessageStripper alloc] initWithMessage:message];
    message = ms.plainText;

    message = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString* response = [self handleCommand:message conversationId:conversationId user:user subscription:sub];

    if (response == nil) {
        response = kUsageText;
    }

    [self postMessage:response intoConversationWithId:conversationId onSuccess:nil onError:nil];

    sub.read_message_nr = messageNr;
    FLApiRequest* markReadRequest = [[FLApiRequest alloc] initWithMethod:@"message/mark_read/%@"
        methodArg:conversationId arguments:@{@"message_nr" : messageNr }];
    [self queueRequest:markReadRequest name:[NSString stringWithFormat:@"mr_%@", conversationId]];

    return nil;
}

- (void)endTransaction
{
    [super endTransaction];
    [[DataModel dataModel] saveContext];
}

@end
