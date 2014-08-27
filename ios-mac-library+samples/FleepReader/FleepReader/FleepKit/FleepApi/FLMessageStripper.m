//
//  FLMessageStripper.m
//  Fleep
//
//  Created by Erik Laansoo on 14.08.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLMessageStripper.h"
#import "FLUtils.h"

@implementation FLMessageStripper
{
    NSMutableString* _plainText;
    NSMutableString* _plainTextWithMarkup;
    NSInteger _elementLevel;
    NSMutableDictionary* _pendingSuffixes;
}

@synthesize plainText = _plainText;
@synthesize plainTextWithMarkup = _plainTextWithMarkup;

- (id)initWithMessage:(NSString *)message
{
    if (self = [super init]) {
        if (![message hasPrefix:@"<msg>"]) {
            _plainText = [message mutableCopy];
            _plainTextWithMarkup = _plainText;
            return self;
        }

        _plainText = [[NSMutableString alloc] init];
        _plainTextWithMarkup = [[NSMutableString alloc] init];
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:[message dataUsingEncoding:NSUTF8StringEncoding]];
        parser.delegate = self;
        [parser parse];
        if (parser.parserError != nil) {
            FLLogWarning(@"FLMessageStripper::InitWithMessage(%@): %@", message, parser.parserError);
        }
        [FLMessageStripper stripWhitespace:_plainText];
        [FLMessageStripper stripWhitespace:_plainTextWithMarkup];
    }
    return self;
}

+ (void)stripWhitespace:(NSMutableString*)string
{
    NSMutableCharacterSet* whitespaceCharacterSet = nil;
    if (whitespaceCharacterSet == nil) {
        whitespaceCharacterSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [whitespaceCharacterSet addCharactersInString: PARAGRAPH_BREAK];
    }

    NSRange range = NSMakeRange(0, string.length);

    while ((range.length > 0) && [whitespaceCharacterSet characterIsMember:[string characterAtIndex:range.location + range.length - 1]]) {
        range.length--;
    }

    if (range.length < string.length) {
        if (range.location > 0) {
            [string deleteCharactersInRange:NSMakeRange(0, range.location)];
        }

        if (range.length < string.length) {
            [string deleteCharactersInRange:NSMakeRange(range.length, string.length - range.length)];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    _elementLevel++;

    NSString* prefix = attributeDict[@"flp"];
    NSString* suffix = attributeDict[@"fls"];

    if (prefix != nil) {
        [_plainTextWithMarkup appendString:prefix];
    }

    if (suffix != nil) {
        if (_pendingSuffixes == nil) {
            _pendingSuffixes = [[NSMutableDictionary alloc] init];
        }
        _pendingSuffixes[@(_elementLevel)] = suffix;
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qName
{
    if (_pendingSuffixes != nil) {
        NSString* suffix = _pendingSuffixes[@(_elementLevel)];
        if (suffix != nil) {
            [_pendingSuffixes removeObjectForKey:@(_elementLevel)];
            if (_pendingSuffixes.count == 0) {
                _pendingSuffixes = nil;
            }

            [_plainTextWithMarkup appendString:suffix];
        }
    }

    if ([elementName isEqualToString:@"br"]) {
        [self parser:parser foundCharacters:@"\n"];
    }
    if ([elementName isEqualToString:@"p"]) {
        [self parser:parser foundCharacters:@"\n\n"];
    }

    _elementLevel--;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [_plainText appendString:string];
    [_plainTextWithMarkup appendString:string];
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    [self parser:parser foundCharacters:[[NSString alloc] initWithData:CDATABlock
     encoding:NSUTF8StringEncoding]];
}

- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString
{
    [self parser:parser foundCharacters:whitespaceString];
}

@end