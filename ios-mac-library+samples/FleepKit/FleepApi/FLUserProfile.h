//
//  FLUserProfile.h
//  Fleep
//
//  Created by Erik Laansoo on 23.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLClassificators.h"

#define CLIENT_FLAG_AVATARS_DISABLED @"no_avatar_in_flow_mobile"
#define CLIENT_FLAG_DESKTOP_SOUNDS_DISABLED @"desktop_sounds_disabled"

@interface FLUserProfile : NSObject
@property (nonatomic, readonly) NSString* contactId;
@property (nonatomic, readonly) NSArray* aliases;
@property (nonatomic) FLAccountEmailSetting accountEmailSetting;
@property (nonatomic, readonly) BOOL avatarsEnabled;

+ (FLUserProfile*)userProfile;
- (BOOL)isSelf:(NSString*)contactId;
- (BOOL)isClientFlagSet:(NSString*)flagName;
- (void)setClientFlag:(NSString*)name value:(BOOL)value;

@end
