//
//  ContentParser.m
//  FleepReader
//
//  Created by Erik Laansoo on 07.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "ContentParser.h"

@implementation ContentParser
{
    NSMutableString* _result;
    NSInteger _depth;
}

@synthesize result = _result;

- (BOOL) parse
{
    BOOL result = [super parse];
    NSString* res = _result;
    while (YES) {
        NSString* r = [res stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
        if (r.length == res.length) {
            break;
        }
        res = r;
    }
    _result = [res mutableCopy];
    return result;
}

- (id)initWithData:(NSData *)data
{
    self = [super initWithData:data];
    if (self != nil) {
        _result = [[NSMutableString alloc]init];
        self.delegate = self;
    }

    return self;
}

- (void)parser:(NSXMLParser*)parser foundCharacters:(NSString *)string
{
    NSString* str = [string stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    str = [str stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [_result appendString:str];
}

- (void)parser:(NSXMLParser*)parser foundIgnorableWhitespace:(NSString *)whitespaceString
{
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    _depth++;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    _depth--;

    if ([elementName isEqualToString:@"br"]) {
        [_result appendString:@"\n"];
    }
    if ([elementName isEqualToString:@"p"] || [elementName isEqualToString:@"P"]) {
        [_result appendString:@"\n\n"];
    }
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    [self parser:parser foundCharacters:[[NSString alloc]initWithData:CDATABlock encoding:NSUTF8StringEncoding]];
}

@end
