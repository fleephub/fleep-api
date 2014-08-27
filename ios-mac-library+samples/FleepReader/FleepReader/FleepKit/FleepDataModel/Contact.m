//
//  Contact.m
//
//
//  Created by Erik Laansoo on 05.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLDataModel.h"
#import "FLLocalization.h"
#import "FLApi.h"
#import "FLUserProfile.h"

@implementation Contact
{
    NSString* _smallAvatarURL;
    NSString* _largeAvatarURL;
    NSAttributedString* _highlightedName;
}

@dynamic account_id;
@dynamic display_name;
@dynamic email;
@dynamic mk_account_status;
@dynamic is_hidden_for_add;
@dynamic avatar_urls;
@dynamic activity_time;
@dynamic dialog_id;
@dynamic is_dialog_listed;

@synthesize smallAvatarURL = _smallAvatarURL;
@synthesize largeAvatarURL = _largeAvatarURL;
@synthesize highlightedName = _highlightedName;

- (BOOL)isFleepContact
{
    return (self.mk_account_status != nil) &&
      (self.mk_account_status.integerValue == FLAccountStatusActive);
}

- (void)applySearchText:(NSString *)searchText
{
    if (searchText == nil) {
        _highlightedName = [[NSAttributedString alloc] initWithString:self.displayName attributes:nil];
        return;
    }

    NSRange range = [self.displayName rangeOfPrefixString:searchText];
    if (range.location != NSNotFound) {
        _highlightedName = [self.displayName attributedStringHighlightingRange:range];
    } else {
        _highlightedName = nil;
    }
}

- (NSString*) displayName
{
    if ((self.display_name != nil) && (self.display_name.length > 0)) {
        return self.display_name;
    } else {
        return self.email;
    }
}

- (NSString*)shortName
{
    static NSCharacterSet* separators = nil;
    if (separators == nil) {
        NSMutableCharacterSet* cs = [[NSCharacterSet whitespaceCharacterSet] mutableCopy];
        [cs formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        separators = cs;
    }

    NSArray* components = [self.displayName componentsSeparatedByCharactersInSet:separators];
    return components[0];
}

- (NSString*) displayNameWithYou
{
    NSString* res = self.displayName;

    if (self.isLocalContact) {
        return [NSString stringWithFormat:FLLocalize(@"localuser_dispname", @"%@ (you)"), res];
    } else {
        return res;
    }
}

- (NSError*) deserializeFromJson:(FLJsonParser*) json
{
    self.account_id = [json extractString:@"account_id"];
    self.email = [json extractString:@"email"];
    self.display_name = [json extractString:@"display_name" defaultValue:nil];
    self.mk_account_status = [json extractEnum:@"mk_account_status"
        valueMap: FLClassificators.mk_account_status];
    self.is_hidden_for_add = [json extractBool:@"is_hidden_for_add" defaultValue:YES];
    self.activity_time = [json extractDate:@"activity_time" defaultValue:nil];
    self.dialog_id = [json extractString:@"dialog_id" defaultValue:nil];
    self.is_dialog_listed = [json extractBool:@"is_dialog_listed" defaultValue:NO];

    NSString* avatar_urls = [json extractString: @"avatar_urls" defaultValue: nil];
    BOOL urlsChanged = (avatar_urls != nil) != (self.avatar_urls != nil);
    if (avatar_urls != nil) {
        urlsChanged |= ![avatar_urls isEqualToString:self.avatar_urls];
    }

    if (urlsChanged) {
        [self extractAvatarURLs:avatar_urls];
        self.avatar_urls = avatar_urls;
    }

    return json.error;
}

- (NSError*) updateFromJson:(FLJsonParser*) json
{
    self.display_name = [json extractString:@"display_name" defaultValue:self.display_name];
    self.mk_account_status = [json extractEnum:@"mk_account_status"
        valueMap: FLClassificators.mk_account_status defaultValue:self.mk_account_status];
    self.is_hidden_for_add = [json extractBool:@"is_hidden_for_add" defaultValue:self.is_hidden_for_add.boolValue];
    self.activity_time = [json extractDate:@"activity_time" defaultValue:self.activity_time];
    self.dialog_id = [json extractString:@"dialog_id" defaultValue:self.dialog_id];
    self.is_dialog_listed = [json extractBool:@"is_dialog_listed" defaultValue:self.is_dialog_listed.boolValue];

    NSString* avatar_urls = [json extractString: @"avatar_urls" defaultValue: nil];
    BOOL urlsChanged = (avatar_urls != nil) != (self.avatar_urls != nil);
    if (avatar_urls != nil) {
        urlsChanged |= ![avatar_urls isEqualToString:self.avatar_urls];
    }

    if (urlsChanged) {
        [self extractAvatarURLs:avatar_urls];
        self.avatar_urls = avatar_urls;
    }

    [self applySearchText:nil];
    return json.error;
}

- (BOOL)isLocalContact
{
    return [[FLUserProfile userProfile] isSelf:self.account_id];
}

- (void)extractAvatarURLs:(NSString*)data
{
    _smallAvatarURL = nil;
    _largeAvatarURL = nil;

    if (data == nil) {
        return;
    }

    NSError* err;
        
    id au = [NSJSONSerialization JSONObjectWithData: [data dataUsingEncoding:NSUTF8StringEncoding]
        options: 0 error: &err];
    if ((err == nil) && (au != nil) && [au isKindOfClass:NSDictionary.class]) {
        FLJsonParser* json = [FLJsonParser jsonParserForObject:au];
        if ([UIScreen mainScreen].scale > 1.99f) {
            _largeAvatarURL = [json extractString:@"size_700" defaultValue:[json extractString:@"size_100" defaultValue:nil]];
            _smallAvatarURL = [json extractString:@"size_100" defaultValue:[json extractString:@"size_50" defaultValue:nil]];
        } else {
            _largeAvatarURL = [json extractString:@"size_100" defaultValue: nil];
            _smallAvatarURL = [json extractString:@"size_50" defaultValue: nil];
        }
    }
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    [self extractAvatarURLs:self.avatar_urls];
    [self applySearchText:nil];
}

@end
