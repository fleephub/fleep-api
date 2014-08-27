//
//  ContentParser.h
//  FleepReader
//
//  Created by Erik Laansoo on 07.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ContentParser : NSXMLParser <NSXMLParserDelegate>

@property (readonly) NSString* result;
- (id)initWithData:(NSData *)data;

@end
