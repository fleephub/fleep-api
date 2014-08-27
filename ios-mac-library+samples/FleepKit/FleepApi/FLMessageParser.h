//
//  FLMessageParser.h
//  Fleep
//
//  Created by Erik Laansoo on 19.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLUtils.h"

extern NSString* FLEmoticonAttributeName;
extern NSString* FLParagraphBackgroundAttributeName;
extern NSString* FLHorizontalLineAttributeName;

typedef NS_OPTIONS(NSInteger, FLMessageParserFlags) {
    FLMessageParserFlagAllowFormatting = 1,
    FLMessageParserFlagHighlightMatches = 2,
    FLMessageParserFlagHideQuotes = 4,
    FLMessageParserFlagHighlightFadesOut = 8,
    FLMessageParserFlagRecognizePhones = 16
};

@interface FLMessageParser : NSObject <NSXMLParserDelegate>

//@property (nonatomic, readonly) NSString* plainText;
@property (nonatomic, readonly) NSAttributedString* attributedText;
@property (nonatomic, readonly) NSString* quotedText;
@property (nonatomic, readonly) NSArray* links;

- (id)initWithMessage:(NSString*)message flags:(FLMessageParserFlags)flags;
- (id)initWithMessage:(NSString *)message;
@end
