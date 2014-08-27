//
//  OPMLParser.m
//  FleepReader
//
//  Created by Erik Laansoo on 08.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "OPMLParser.h"
#import "FLUtils.h"
#import "FLXMLComposer.h"

@implementation OPMLFeed
{
    NSString* _url;
    NSString* _title;
}

@synthesize url = _url;
@synthesize title = _title;

-(id)initWithUrl:(NSString*)url andTitle:(NSString*)title
{
    self = [super init];
    _url = url;
    _title = title;
    return self;
}

@end

@implementation OPMLParser
@synthesize feeds = _feeds;

- (id)initWithData:(NSData *)data
{
    self = [super initWithData:data];
    _feeds = [[NSMutableArray alloc] init];
    self.delegate = self;
    return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if ([elementName isEqualToString:@"opml"]) {
        _isOPML = YES;
    }

    if (([elementName isEqualToString:@"outline"]) && _isOPML) {
        NSString* title = attributeDict[@"title"];
        NSString* url = attributeDict[@"xmlUrl"];
        if ((title != nil) && (url != nil)) {
            [_feeds addObject:[[OPMLFeed alloc]initWithUrl:url andTitle:title]];
        }
    }
}

+ (NSString*)feedListToOPML:(NSArray*)feeds
{
    FLXMLComposer* xml = [[FLXMLComposer alloc] init];
    [xml startElement:@"opml" withAttributes:@{ @"version" : @"1.0" }];
    [xml startElement:@"head"];
    [xml startElement:@"title"];
    [xml addText:@"Fleep Reader feed list"];
    [xml endElement:@"title"];
    [xml endElement:@"head"];
    [xml startElement:@"body"];

    for (OPMLFeed* f in feeds) {
        [xml addEmptyElement:@"outline" withAttributes: @{
            @"text" : f.title,
            @"title": f.title,
            @"type" : @"rss",
            @"xmlUrl" : f.url
        }];
    }

    [xml endElement:@"body"];
    [xml endElement:@"opml"];
    return xml.result;
}

@end
