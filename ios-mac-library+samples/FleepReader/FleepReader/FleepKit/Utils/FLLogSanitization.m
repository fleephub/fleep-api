//
//  FLLogSanitization.m
//  Fleep
//
//  Created by Erik Laansoo on 14.08.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLLogSanitization.h"
#import "FLUtils.h"

@implementation FLLogSanitization

+ (void)sanitizeValue:(NSString*)key inDictionary:(NSMutableDictionary*)dict
{
    NSObject* value = dict[key];
    if (value == nil) {
        return;
    }
    
    if ([value isKindOfClass:NSString.class]) {
        NSString* str = (NSString*)value;
        NSString* sanitized = [NSString stringWithFormat:@"*%ld*", (long)str.length];
        if (str.length < 20) {
            sanitized = [FleepUtils stringOfChar:'*' ofLength:str.length];
        }
        [dict setObject: sanitized forKey:key];
    } else {
        [dict setObject:value.class.description forKey:key];
    }
}


+ (NSDictionary*)sanitizeDictionary:(NSDictionary *)dictionary
{
    static NSArray* sanitizeValues = nil;
    if (sanitizeValues == nil) {
        sanitizeValues = @[@"password", @"ticket", @"message"];
    }

    BOOL sanitize = NO;
    for (NSString* key in sanitizeValues) {
        if (dictionary[key] != nil) {
            sanitize = YES;
            break;
        }
    }

    if (!sanitize) {
        return dictionary;
    }

    NSMutableDictionary* res = [[NSMutableDictionary alloc] initWithDictionary:dictionary];
    for (NSString* key in sanitizeValues) {
        [self sanitizeValue:key inDictionary:res];
    }
    return res;
}

@end
