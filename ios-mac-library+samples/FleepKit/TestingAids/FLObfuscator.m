//
//  FLObfuscator.m
//  Fleep
//
//  Created by Erik Laansoo on 17.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLObfuscator.h"

@implementation FLObfuscator

NSMutableArray* _obfuscatedWords;
NSSet* _obfuscatedFields = nil;

+ (void)initialize
{
    NSString* loremIpsum = @"Lorem ipsum dolor si amet, consectetur adipisicing elit,\
sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, \
quis nostrud exercitation ullamco laboris nisi ut www.aliquipexea.com modo consequat. Duis\
 aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.\
 Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim\
 id est laborum.";

    NSMutableCharacterSet* separators = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
    [separators formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    NSArray* words = [loremIpsum componentsSeparatedByCharactersInSet:separators];
    _obfuscatedWords = [[NSMutableArray alloc] init];
    for (NSString* w in words) {
        while (_obfuscatedWords.count <= w.length) {
            [_obfuscatedWords addObject:[[NSMutableArray alloc] init]];
        }
        NSMutableArray* wl = _obfuscatedWords[w.length];
        [wl addObject:[w lowercaseString]];
    }
    for (NSInteger i = 0; i < _obfuscatedWords.count; i++) {
        NSMutableArray* wl = _obfuscatedWords[i];
        if (wl.count == 0) {
            [wl addObject:[@"loremipsumdolorsiamet" substringToIndex:i]];
        }
    }
    
    _obfuscatedFields = [NSSet setWithArray:@[@"message", @"topic", @"display_name", @"email"]];
}

+ (NSString*)obfuscateWord:(NSString*)word
{
    if (word.length < 3) {
        return word;
    }
    NSMutableString* result = [[NSMutableString alloc] init];
    while (result.length < word.length) {
        NSArray* wl = _obfuscatedWords[MIN(word.length - result.length, _obfuscatedWords.count - 1)];
        [result appendString:wl[rand() % wl.count]];
    }
    NSCharacterSet* upper = [NSCharacterSet uppercaseLetterCharacterSet];
    for (NSUInteger i = 0; i < word.length; i++) {
        if ([upper characterIsMember:[word characterAtIndex:i]]) {
            NSRange r = NSMakeRange(i, 1);
            [result replaceCharactersInRange:r withString:[[result substringWithRange:r] uppercaseString]];
        }
    }
    
    return result;
}

+ (NSString*)obfuscateId:(NSString*)guid
{
    static NSMutableDictionary* _ids = nil;
    if (_ids == nil) {
        _ids = [[NSMutableDictionary alloc] init];
    }
    NSString* result = _ids[guid];
    if (result == nil) {
        NSMutableString* res = [[NSMutableString alloc] init];
        for (NSInteger i = 0; i < guid.length; i++) {
            if ([guid characterAtIndex:i] == '-') {
                [res appendString:@"+"];
            } else {
                [res appendFormat:@"%c", [@"0123456789abcdef" characterAtIndex:rand() % 16]];
            }
        }
        result = res;
        _ids[guid] = res;
    }
    return result;
}

+ (NSString*)obfuscateText:(NSString*)text
{
    if ([text hasPrefix:@"{"] && [text hasSuffix:@"}"]) {
        return text;
    }

    NSMutableCharacterSet* letters = [NSCharacterSet letterCharacterSet];
    NSMutableString* result = [[NSMutableString alloc] init];
    NSInteger pos = 0;
    unichar ps = '\0';
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar sep = [text characterAtIndex:i];
        if (![letters characterIsMember:sep]) {
            NSString* word = [text substringWithRange:NSMakeRange(pos, i - pos)];

            if ((sep == '>') && (ps == '<')) {
                [result appendFormat:@"%@%c", word, sep];
            } else {
                [result appendFormat:@"%@%c", [self obfuscateWord:word], sep];
            }
            pos = i + 1;
            if (sep != '/') {
                ps = sep;
            }
        }
    }

    if (pos < text.length) {
        [result appendString:
            [self obfuscateWord:[text substringWithRange:NSMakeRange(pos, text.length - pos)]]
        ];
    }
    
    return result;
}

+ (void)obfuscateDictionary:(NSMutableDictionary *)dictionary
{
    for (NSString* key in dictionary.allKeys) {
        id val = [dictionary objectForKey:key];
        if ([val isKindOfClass:[NSString class]] && [_obfuscatedFields containsObject:key]) {
            [dictionary setObject:[self obfuscateText:val] forKey:key];
        }
        if ([val isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary* v = [val mutableCopy];
            [self obfuscateDictionary:dictionary];
            [dictionary setObject:v forKey:key];
        }
        if ([val isKindOfClass:[NSArray class]]) {
            NSMutableArray* vv = [val mutableCopy];
            for (NSInteger i = 0; i < vv.count; i++) {
                id av = vv[i];
                if ([av isKindOfClass:[NSDictionary class]]) {
                    NSMutableDictionary* v = [av mutableCopy];
                    [self obfuscateDictionary:v];
                    vv[i] = v;
                }
            }
            [dictionary setObject:vv forKey:key];
        }
    }
}

@end
