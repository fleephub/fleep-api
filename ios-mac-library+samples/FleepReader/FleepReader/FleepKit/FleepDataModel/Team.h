//
//  Team.h
//  Fleep
//
//  Created by Erik Laansoo on 08.08.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "FLJsonParser.h"
#import "FLUtils.h"

@interface Team : NSManagedObject <JsonSerialization>

@property (nonatomic, retain) NSString * team_id;
@property (nonatomic, retain) NSString * team_name;
@property (nonatomic, retain) NSString * members;

@end
