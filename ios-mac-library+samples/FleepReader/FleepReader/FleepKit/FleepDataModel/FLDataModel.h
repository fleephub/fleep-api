//
//  FLDataModel.h
//  Fleep
//
//  Created by Erik Laansoo on 19.02.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Contact.h"
#import "Message.h"
#import "Conversation.h"
#import "Conversation+Actions.h"
#import "Conversation+Serialization.h"
#import "Member.h"
#import "Hook.h"
#import "Team.h"
#import "FLUtils.h"
#import "FLConversationLists.h"
#import "FLUserProfile.h"
#import "FLJsonParser.h"

@interface FLDataModel : NSObject

@property (nonatomic, readonly) NSDictionary* contacts;
@property (nonatomic, readonly) NSDictionary* conversations;
@property (nonatomic, readonly) float syncProgress;

@property (nonatomic) BOOL syncFullHistory;

+ (FLDataModel*) dataModel;

- (Conversation*) conversationFromId:(NSString*)convId;
- (Conversation*) createNewConversation;
- (Conversation*) cloneConversation:(Conversation*)c;
- (Contact*) contactFromId:(NSString*)contactId;
- (Contact*) contactFromEmail:(NSString*)email;
- (Hook*) hookFromId:(NSString*)hookId;
- (Team*) teamFromId:(NSString*)teamId;

- (NSString*) fullNameOfContact:(NSString*)contactId;
- (NSString*) shortNameOfContact:(NSString*)contactId;
- (NSString*) initialsOfContact:(NSString*)contactId;

- (void)saveContext;

@end
