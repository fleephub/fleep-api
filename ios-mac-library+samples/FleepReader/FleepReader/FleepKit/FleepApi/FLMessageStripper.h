//
//  FLMessageStripper.h
//  Fleep
//
//  Created by Erik Laansoo on 14.08.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#define PARAGRAPH_BREAK @"\u2029"
#define PARAGRAPH_BREAK_CHAR '\u2029'

@interface FLMessageStripper : NSObject <NSXMLParserDelegate>
@property (readonly, nonatomic) NSString* plainText;
@property (readonly, nonatomic) NSString* plainTextWithMarkup;

- (id)initWithMessage:(NSString*)message;
@end
