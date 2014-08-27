//
//  RSSParser.m
//  FleepReader
//
//  Created by Erik Laansoo on 07.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "RSSParser.h"

typedef NS_ENUM(NSInteger, RSSParserState) {
    RSSParserStateDocument = 0,
    RSSParserStateItem = 1,
    RSSParserStateChannel = 2,
    RSSParserStateTitle = 3,
    RSSParserStateLink = 4,
    RSSParserStateGUID = 5,
    RSSParserStateText = 6,
    RSSParserStateChannelTitle = 7,
    RSSParserStateUnrecognizedTag = 8
};

@interface RSSItem ()
@property (nonatomic, readwrite) NSString* title;
@property (nonatomic, readwrite) NSString* guid;
@property (nonatomic, readwrite) NSString* text;
@property (nonatomic, readwrite) NSString* url;
@end

@implementation RSSItem
{
    NSString* _title;
    NSString* _url;
    NSString* _guid;
    NSString* _text;
}

@synthesize title = _title;
@synthesize url = _url;
@synthesize guid = _guid;
@synthesize text = _text;

- (id)init
{
    if (self = [super init]) {
        _title = @"";
        _url = @"";
        _guid = @"";
        _text = @"";
    }
    return self;
}

@end

@implementation RSSParser
{
    NSMutableArray* _items;
    RSSItem* _currentItem;
    RSSParserState _state;
    NSString* _title;
    FeedType _type;
    NSDictionary* _transitions;
    NSMutableArray* _tagStack;
}

@synthesize items = _items;
@synthesize title = _title;
@synthesize type = _type;

NSDictionary* _rssTransitions = nil;
NSDictionary* _atomTransitions = nil;

+ (void)initialize
{
    _rssTransitions= @{
        @(RSSParserStateDocument) : @{
            @"channel" : @(RSSParserStateChannel)
        },
        @(RSSParserStateChannel) : @{
            @"title" : @(RSSParserStateChannelTitle),
            @"item" : @(RSSParserStateItem)
        },
        @(RSSParserStateItem) : @{
            @"title" : @(RSSParserStateTitle),
            @"link" : @(RSSParserStateLink),
            @"guid" : @(RSSParserStateGUID),
            @"description" : @(RSSParserStateText)
        }
    };

    _atomTransitions = @{
        @(RSSParserStateDocument) : @{
            @"title" : @(RSSParserStateChannelTitle),
            @"entry" : @(RSSParserStateItem)
        },
        @(RSSParserStateItem) : @{
            @"title" : @(RSSParserStateTitle),
            @"link" : @(RSSParserStateLink),
            @"published" : @(RSSParserStateGUID),
            @"summary" : @(RSSParserStateText)
        }
    };
}

- (id)initWithData:(NSData *)data
{
    self = [super initWithData:data];
    _items = [[NSMutableArray alloc] init];
    _tagStack = [[NSMutableArray alloc] init];
    _title = @"";
    
    self.delegate = self;
    
    return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if (_transitions == nil) {
        if ([elementName isEqualToString:@"rss"]) {
            _transitions = _rssTransitions;
            _type = FeedTypeRSS;
        }

        if ([elementName isEqualToString:@"feed"]) {
            _transitions = _atomTransitions;
            _type = FeedTypeAtom;
        }

        return;
    }

    NSNumber* newState = nil;
    NSDictionary* transitionsInCurrentState = _transitions[@(_state)];
    if (transitionsInCurrentState != nil) {
        newState = transitionsInCurrentState[elementName];
    }

    if (newState == nil) {
        newState = @(RSSParserStateUnrecognizedTag);
    }

    _state = newState.integerValue;
    [_tagStack addObject:newState];
    
    if (_state == RSSParserStateItem) {
        _currentItem = [[RSSItem alloc]init];
    }

    if ((_state == RSSParserStateLink) && (_type == FeedTypeAtom)) {
        NSString* type = attributeDict[@"type"];
        NSString* rel = attributeDict[@"rel"];
        if (![rel isEqualToString:@"license"]) {
            if ((_currentItem.url.length == 0) || [type isEqualToString:@"text/html"]) {
                _currentItem.url = attributeDict[@"href"];
            }
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if (_state == RSSParserStateItem) {
        if (_currentItem.guid.length == 0) {
            _currentItem.guid = _currentItem.url;
        }

        [_items addObject:_currentItem];
        _currentItem = nil;
    }
    
    if (_tagStack.count > 0) {
        [_tagStack removeObjectAtIndex:_tagStack.count - 1];
        _state = ((NSNumber*)_tagStack.lastObject).integerValue;
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    switch (_state) {
        case RSSParserStateTitle:_currentItem.title = [_currentItem.title stringByAppendingString:string];
        break;
        case RSSParserStateLink:_currentItem.url = [_currentItem.url stringByAppendingString:string];
        break;
        case RSSParserStateGUID:_currentItem.guid = [_currentItem.guid stringByAppendingString:string];
        break;
        case RSSParserStateText:_currentItem.text = [_currentItem.text stringByAppendingString:string];
        break;
        case RSSParserStateChannelTitle: _title = [_title stringByAppendingString:string];
        break;
        default: break;
    }
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    [self parser:parser foundCharacters:[[NSString alloc] initWithData:CDATABlock
        encoding:NSUTF8StringEncoding]];
}

@end
