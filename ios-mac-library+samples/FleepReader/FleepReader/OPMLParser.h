//
//  OPMLParser.h
//  FleepReader
//
//  Created by Erik Laansoo on 08.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OPMLFeed : NSObject
@property (readonly) NSString* url;
@property (readonly) NSString* title;

-(id)initWithUrl:(NSString*)url andTitle:(NSString*)title;

@end

@interface OPMLParser : NSXMLParser <NSXMLParserDelegate>
{
    NSMutableArray* _feeds;
}
@property (readonly) NSArray* feeds;
@property (readonly) BOOL isOPML;

+ (NSString*)feedListToOPML:(NSArray*)feeds;
@end
