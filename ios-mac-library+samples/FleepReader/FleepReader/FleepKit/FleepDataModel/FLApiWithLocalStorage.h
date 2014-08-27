//
//  FLApiWithLocalStorage.h
//  Fleep
//
//  Created by Erik Laansoo on 25.07.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLApi.h"
#import "FLDataModel.h"

@interface FLApiWithLocalStorage : FLApi
+ (FLApiWithLocalStorage*)apiWithLocalStorage;

- (void)synchronizeConversation:(Conversation*) conversation;
- (void)synchronizeContactWithId:(NSString*)contactId;

@end
