//
//  Hook.h
//  Fleep
//
//  Created by Erik Laansoo on 15.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "FLJsonParser.h"
#import "FLUtils.h"
#import "FLClassificators.h"


@interface Hook : NSManagedObject <JsonSerialization>

@property (nonatomic, retain) NSString * conversation_id;
@property (nonatomic, retain) NSString * account_id;
@property (nonatomic, retain) NSString * hook_name;
@property (nonatomic, retain) NSString * hook_key;
@property (nonatomic, retain) NSString * hook_url;
@property (nonatomic, retain) NSNumber * is_active;
@property (nonatomic, retain) NSString * avatar_urls;

@property (nonatomic, readonly) NSString* largeAvatarUrl;
@property (nonatomic, readonly) NSString* smallAvatarUrl;

@end
