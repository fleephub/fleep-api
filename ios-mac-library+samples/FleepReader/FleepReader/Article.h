//
//  Article.h
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "RSSParser.h"

@interface Article : NSManagedObject
@property (readonly) NSString* formattedArticle;

@property (nonatomic, retain) NSString * feed_id;
@property (nonatomic, retain) NSNumber * article_nr;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * body;
@property (nonatomic, retain) NSString * guid;
- (void)setFromRSSItem:(RSSItem*)item;

@end
