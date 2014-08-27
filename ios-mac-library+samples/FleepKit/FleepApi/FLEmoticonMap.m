//
//  FLEmoticonMap.m
//  Fleep
//
//  Created by Erik Laansoo on 12.03.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLEmoticonMap.h"

char extractBits(NSUInteger *val, int bits)
{
    char mask = 0xff >> (8-bits);
    char res = *val & mask;
    *val = *val >> bits;
    return res;
}

@implementation FLEmoticonMap
+ (NSString*)EmojiForEmoticon:(NSString*)emoticonName
{
    static NSDictionary* emoticonMap = nil;
    if (emoticonMap == nil) {
        emoticonMap = @{
            @"ecoctail" : @(0x1F378),
            @"eheart" : @(0x1F496),
            @"edown" : @(0x1F44E),
            @"eclock" : @(0x1F551),
            @"eup" : @(0x1F44D),
            @"ecat" : @(0x1F408),
            @"edone" : @(0x2705),
            @"egift" : @(0x1F381),
            @"esnowman" : @(0x26C4),
            @"eumbrella" : @(0x2614),
            @"esad" : @(0x1F612),
            @"esmile" : @(0x1F60A),
            @"eangry" : @(0x1F620),
            @"elaugh" : @(0x1F604),
            @"esurprise" : @(0x1F632),
            @"etongue" : @(0x1F61C),
            @"eworried" : @(0x1F61F),
            @"ewink" : @(0x1F609)
        };
    }

    NSNumber* ch = emoticonMap[emoticonName];
    if (ch == nil) {
        return nil;
    }

    NSUInteger c = ch.unsignedIntegerValue;
    char utf8[5];
    utf8[4] = 0;
    utf8[3] = extractBits(&c, 6) | 0x80;
    utf8[2] = extractBits(&c, 6) | 0x80;
    utf8[1] = extractBits(&c, 6) | 0x80;
    utf8[0] = extractBits(&c, 3) | 0xf0;
    return [NSString stringWithUTF8String:utf8];
}

@end
