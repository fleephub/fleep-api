//
//  Article.m
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "Article.h"
#import "ContentParser.h"

@implementation Article

@dynamic feed_id;
@dynamic article_nr;
@dynamic title;
@dynamic url;
@dynamic body;
@dynamic guid;

- (NSString*)formattedArticle
{
    return [NSString stringWithFormat:
        @"%@\n\n%@\n\n%@", self.title, self.body, self.url];

}

- (void)setFromRSSItem:(RSSItem *)item
{
    self.title = item.title;
    self.url = item.url;
    NSString* itemText = [NSString stringWithFormat:@"<x>%@</x>", item.text];

    ContentParser* cp = [[ContentParser alloc] initWithData:[itemText dataUsingEncoding:NSUTF8StringEncoding]];
    [cp parse];
    NSString* body = cp.result;
    if (body.length > 500) {
        body = [NSString stringWithFormat:@"%@ [...]", [body substringToIndex:500]];
    }
    
    self.body = body;
    self.guid = item.guid;
}

@end
