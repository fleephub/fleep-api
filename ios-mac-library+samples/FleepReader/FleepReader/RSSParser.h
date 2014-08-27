//
//  RSSParser.h
//  FleepReader
//
//  Created by Erik Laansoo on 07.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSSItem : NSObject
@property (nonatomic, readonly) NSString* title;
@property (nonatomic, readonly) NSString* guid;
@property (nonatomic, readonly) NSString* text;
@property (nonatomic, readonly) NSString* url;
@end

typedef NS_ENUM(NSInteger, FeedType)
{
    FeedTypeUnrecognized = 0,
    FeedTypeRSS = 1,
    FeedTypeAtom = 2

};

@interface RSSParser : NSXMLParser <NSXMLParserDelegate>

@property (nonatomic, readonly) NSArray* items;
@property (nonatomic, readonly) NSString* title;
@property (nonatomic, readonly) FeedType type;

@end
