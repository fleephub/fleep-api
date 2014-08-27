//
//  FLXMLComposer.h
//  Fleep
//
//  Created by Erik Laansoo on 24.01.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (XMLEncoding)
- (NSString*)xmlEncoded;
- (NSString*)xmlEncodedForAttribute:(BOOL)attribute;
@end

@interface FLXMLComposer : NSObject
@property (readonly, nonatomic) NSString* currentElement;

- (id)init;
- (void)startElement:(NSString*)elementName;
- (void)startElement:(NSString*)elementName withAttributes:(NSDictionary*)attributes;
- (void)endElement:(NSString*)elementName;
- (void)addEmptyElement:(NSString*)elementName;
- (void)addEmptyElement:(NSString *)elementName withAttributes:(NSDictionary*)attributes;
- (void)addAttribute:(NSString*)key value:(NSString*)value toElement:(NSString*)elementName;
- (void)addText:(NSString*)text;
- (BOOL)isElementOpen:(NSString*)elementName;
- (NSString*)result;
- (NSData*)data;

@end
