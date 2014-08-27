//
//  Hook.m
//  Fleep
//
//  Created by Erik Laansoo on 15.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "Hook.h"


@implementation Hook
{
    NSString* _smallAvatarUrl;
    NSString* _largeAvatarUrl;
}

@dynamic conversation_id;
@dynamic account_id;
@dynamic hook_name;
@dynamic hook_key;
@dynamic hook_url;
@dynamic is_active;
@dynamic avatar_urls;

@synthesize smallAvatarUrl = _smallAvatarUrl;
@synthesize largeAvatarUrl = _largeAvatarUrl;

- (NSError*)deserializeFromJson:(FLJsonParser *)json
{
    self.conversation_id = [json extractString:@"conversation_id"];
    self.account_id = [json extractString:@"account_id"];
    self.hook_name = [json extractString:@"hook_name" defaultValue:nil];
    self.hook_key = [json extractString:@"hook_key"];
    self.hook_url = [json extractString:@"hook_url" defaultValue:nil];
    self.is_active = [json extractBool:@"is_active"];
    self.avatar_urls = [json extractString:@"avatar_urls" defaultValue:nil];

    return json.error;
}

- (NSError*)updateFromJson:(FLJsonParser *)json
{
    self.hook_name = [json extractString:@"hook_name" defaultValue:self.hook_name];
    self.hook_url = [json extractString:@"hook_url" defaultValue:self.hook_url];
    self.is_active = [json extractBool:@"is_active" defaultValue:self.is_active.boolValue];
    self.avatar_urls = [json extractString:@"avatar_urls" defaultValue:self.avatar_urls];

    [self extractAvatarUrls];
    return json.error;
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    [self extractAvatarUrls];
}

- (void)extractAvatarUrls
{
    _smallAvatarUrl = nil;
    _largeAvatarUrl = nil;

    if (self.avatar_urls == nil) {
        return;
    }

    NSError* err;
        
    id au = [NSJSONSerialization JSONObjectWithData: [self.avatar_urls dataUsingEncoding:NSUTF8StringEncoding]
        options: 0 error: &err];
    if ((err == nil) && (au != nil) && [au isKindOfClass:NSDictionary.class]) {
        FLJsonParser* json = [FLJsonParser jsonParserForObject:au];
        if ([UIScreen mainScreen].scale > 1.99f) {
            _largeAvatarUrl = [json extractString:@"size_200" defaultValue:[json extractString:@"size_100" defaultValue:nil]];
            _smallAvatarUrl = [json extractString:@"size_100" defaultValue:[json extractString:@"size_50" defaultValue:nil]];
        } else {
            _largeAvatarUrl = [json extractString:@"size_100" defaultValue: nil];
            _smallAvatarUrl = [json extractString:@"size_50" defaultValue: nil];
        }
    }
}

@end
