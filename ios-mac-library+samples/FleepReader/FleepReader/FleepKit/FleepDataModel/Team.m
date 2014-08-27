//
//  Team.m
//  Fleep
//
//  Created by Erik Laansoo on 08.08.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "Team.h"


@implementation Team

@dynamic team_id;
@dynamic team_name;
@dynamic members;

- (NSError*)deserializeFromJson:(FLJsonParser *)json
{
    self.team_id = [json extractString:@"team_id"];
    self.team_name = [json extractString:@"team_name" defaultValue:nil];
    NSArray* members = [json extractObject:@"members" class:NSArray.class defaultValue:nil];
    if (members != nil) {
        NSData* serializedMembers = [NSJSONSerialization dataWithJSONObject:members options:0 error:nil];
        self.members = [[NSString alloc] initWithData:serializedMembers encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (NSError*)updateFromJson:(FLJsonParser *)obj
{
    return [self deserializeFromJson:obj];
}

@end
