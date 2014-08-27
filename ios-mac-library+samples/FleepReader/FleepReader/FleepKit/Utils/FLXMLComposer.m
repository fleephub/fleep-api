//
//  FLXMLComposer.m
//  Fleep
//
//  Created by Erik Laansoo on 24.01.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLXMLComposer.h"
#import "FLUtils.h"

@implementation NSString (XMLEncoding)

- (NSString*)xmlEncodedForAttribute:(BOOL)attribute
{
#ifdef TARGET_IS_IPHONE
    NSMutableString* result = nil;
    NSInteger last = 0;
    for (NSInteger i = 0; i < self.length; i++) {
        NSString* entity = nil;
        unichar c = [self characterAtIndex:i];
        switch (c) {
            case '<': entity = @"&lt;"; break;
            case '>': entity = @"&gt;"; break;
            case '"': entity = @"&quot;"; break;
            case '&': entity = @"&amp;"; break;
            default: break;
        }

        if ((c < 32) && attribute) {
            entity = [NSString stringWithFormat:@"&#%ld;", (long)c];
        }

        if (entity != nil) {
            if (result == nil) {
                result = [[NSMutableString alloc] init];
            }
            [result appendString:[self substringWithRange:NSMakeRange(last, i - last)]];
            last = i + 1;
        [   result appendString:entity];
        }
    }

    if (result == nil) {
        return self;
    }

    [result appendString:[self substringFromIndex:last]];
    return result;
    
#else
    return (__bridge NSString*)CFXMLCreateStringByEscapingEntities(NULL,
        (__bridge CFStringRef)self, NULL);
#endif
}

- (NSString*)xmlEncoded
{
    return [self xmlEncodedForAttribute:NO];
}

@end

@implementation FLXMLComposer
{
    NSMutableString* _result;
    NSMutableArray* _elements;
    NSMutableArray* _elementPositions;
}

- (NSString*)currentElement
{
    return _elements.lastObject;
}

- (id)init
{
    if (self = [super init]) {
        _result = [[NSMutableString alloc] init];
        _elements = [[NSMutableArray alloc] init];
        _elementPositions = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSString*)encodeAttribute:(NSString*)name value:(NSString*)value
{
    return [NSString stringWithFormat:@" %@=\"%@\"", name, [value xmlEncodedForAttribute:YES]];
}

- (void)emitAttributes:(NSDictionary*)attributes
{
    if (attributes == nil) {
        return;
    }

    [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [_result appendString:[self encodeAttribute:key value:obj]];
    }];
}

- (void)addAttribute:(NSString *)key value:(NSString *)value toElement:(NSString *)elementName
{
    NSString* encodedAttr = [self encodeAttribute:key value:value];
    NSInteger index = NSNotFound;
    for (NSInteger i = _elements.count - 1; i >= 0; i--) {
        if ([elementName isEqualToString:_elements[i]]) {
            index = i;
            break;
        }
    }

    assert(index != NSNotFound);
    NSNumber* pos = _elementPositions[index];

    [_result insertString:encodedAttr atIndex:pos.integerValue];
    for (NSInteger i = index; i < _elementPositions.count; i++) {
        _elementPositions[i] = [NSNumber numberWithInteger:((NSNumber*)_elementPositions[i]).integerValue + encodedAttr.length];
    }
}

- (void)startElement:(NSString*)elementName
{
    [self startElement:elementName withAttributes:nil];
}

- (void)startElement:(NSString*)elementName withAttributes:(NSDictionary*)attributes
{
    [_result appendFormat:@"<%@", elementName];
    [self emitAttributes:attributes];
    [_elementPositions addObject:[NSNumber numberWithInteger:_result.length]];
    [_elements addObject:elementName];
    [_result appendString:@">"];
}

- (void)endElement:(NSString*)elementName
{
    assert([elementName isEqualToString:_elements.lastObject]);
    [_elements removeObjectAtIndex:_elements.count - 1];
    [_elementPositions removeObjectAtIndex:_elementPositions.count - 1];
    [_result appendFormat:@"</%@>", elementName];
}

- (void)addEmptyElement:(NSString*)elementName
{
    [self addEmptyElement:elementName withAttributes:nil];
}

- (void)addEmptyElement:(NSString *)elementName withAttributes:(NSDictionary*)attributes
{
    [_result appendFormat:@"<%@", elementName];
    [self emitAttributes:attributes];
    [_result appendString:@"/>"];
}

- (void)addText:(NSString*)text
{
    [_result appendString:[text xmlEncoded]];
}

- (BOOL) isElementOpen:(NSString *)elementName
{
    return [_elements indexOfObject:elementName] != NSNotFound;
}

- (NSString*)result
{
    assert(_elements.count == 0);
    return _result;
}

- (NSData*)data
{
    assert(_elements.count == 0);
    return [_result dataUsingEncoding:NSUTF8StringEncoding];
}

@end
