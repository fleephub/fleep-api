//
//  FLMessageParser.m
//  Fleep
//
//  Created by Erik Laansoo on 19.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLMessageParser.h"
#import "FLMessageStripper.h"
#import "FLUtils.h"
#import "FLEmoticonMap.h"
#ifdef TARGET_IS_IPHONE
#import "FLBranding.h"
#endif

#define PARAGRAPH_BREAK @"\u2029"
#define PARAGRAPH_BREAK_CHAR '\u2029'

const NSString* FLEmoticonAttributeName = @"FLEmoticonName";
const NSString* FLParagraphBackgroundAttributeName = @"FLParagraphBackgroundAttributeName";
const NSString* FLHorizontalLineAttributeName = @"FLHorizontalLine";

#ifdef TARGET_IS_IPHONE
@implementation FLMessageParser
{
    NSMutableArray* _links;
    NSMutableString* _plainText;
    NSMutableAttributedString* _attributedText;
    NSMutableArray* _attributes;
    NSMutableArray* _tags;
    NSMutableString* _quotedText;
    FLMessageParserFlags _flags;
    NSInteger _inQuote;
    BOOL _inHr;
    NSDataDetector* _dataDetector;
}

//@synthesize plainText = _plainText;
@synthesize attributedText = _attributedText;
@synthesize quotedText = _quotedText;
@synthesize links = _links;

- (NSDictionary*)attributes
{
    return _attributes != nil ? _attributes.lastObject : [self defaultAttributes];
}

- (NSDictionary*)defaultAttributes
{
    static NSDictionary* _defaultAttributes;
    if (_defaultAttributes == nil) {
        NSMutableParagraphStyle* paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        paragraphStyle.paragraphSpacing = 5.0f;
        paragraphStyle.lineHeightMultiple = 1.0;
        paragraphStyle.lineSpacing = -1.0f;
        _defaultAttributes = @{
            NSFontAttributeName : [FLBranding mainFont],
            NSParagraphStyleAttributeName : paragraphStyle
        };
    }
    return _defaultAttributes;
}

- (void)pushAttributes:(NSDictionary*)attributes forTag:(NSString*)tag
{
    if (_attributes == nil) {
        _attributes = [[NSMutableArray alloc] init];
        _tags = [[NSMutableArray alloc] init];
        [_attributes addObject:[self defaultAttributes]];
        [_tags addObject:@""];
    }
    
    NSMutableDictionary* newAttributes = [[self attributes] mutableCopy];
    for (NSString* key in attributes.allKeys) {
        id v = attributes[key];
        if (v == [NSNull null]) {
            [newAttributes removeObjectForKey:key];
        } else {
            newAttributes[key] = v;
        }
    }
    [_attributes addObject:newAttributes];
    [_tags addObject:tag];
}

- (void)popAttributes
{
    assert(_attributes.count > 0);
    [_attributes removeObjectAtIndex:_attributes.count - 1];
    [_tags removeObjectAtIndex:_tags.count - 1];
}

- (id)initWithMessage:(NSString *)message
{
    return [self initWithMessage:message flags:0];
}

+ (void)stripWhitespaceAttributed:(NSMutableAttributedString*)string
{
    NSMutableCharacterSet* whitespaceCharacterSet = nil;
    if (whitespaceCharacterSet == nil) {
        whitespaceCharacterSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [whitespaceCharacterSet addCharactersInString: PARAGRAPH_BREAK];
    }

    NSRange range = NSMakeRange(0, string.length);

    while ((range.length > 0) && [whitespaceCharacterSet characterIsMember:[string.string characterAtIndex:range.location + range.length - 1]]) {
        range.length--;
    }

    if (range.length < string.length) {
        if (range.location > 0) {
            [string deleteCharactersInRange:NSMakeRange(0, range.location)];
        }

        if (range.length < string.length) {
            [string deleteCharactersInRange:NSMakeRange(range.length, string.length - range.length)];
        }
    }
}

- (id)initWithMessage:(NSString*)message flags:(FLMessageParserFlags)flags
{
    if (self = [super init]) {
        if (![message hasPrefix:@"<msg>"]) {
            _plainText = [message mutableCopy];
            _attributedText = [[NSMutableAttributedString alloc] initWithString:_plainText attributes:[self defaultAttributes]];
            return self;
        }

        _flags = flags;
        _plainText = [[NSMutableString alloc] init];
        _attributedText = [[NSMutableAttributedString alloc] initWithString:@"" attributes:[self defaultAttributes]];

        if ((_flags & FLMessageParserFlagRecognizePhones) && ([[UIApplication sharedApplication]
           canOpenURL:[NSURL URLWithString:@"tel://"]])) {
            NSError* err = nil;
            _dataDetector = [[NSDataDetector alloc] initWithTypes:NSTextCheckingTypePhoneNumber error:&err];
        }

        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:[message dataUsingEncoding:NSUTF8StringEncoding]];
        parser.delegate = self;
        [parser parse];
        if (parser.parserError != nil) {
            FLLogWarning(@"FLMessageParser::InitWithMessage(%@): %@", message, parser.parserError);
        }
//        [FLMessageStripper stripWhitespace:_plainText];
        if (_attributedText != nil) {
            [FLMessageParser stripWhitespaceAttributed:_attributedText];
        }
    }
    return self;
}

- (UIFont*)fontByAddingSymbolicTraits:(UIFontDescriptorSymbolicTraits)traits
{
    UIFont* oldFont = [self attributes][NSFontAttributeName];
    if (![oldFont respondsToSelector:@selector(fontDescriptor)]) { // iOS6 fallback
        if (traits == UIFontDescriptorTraitBold) {
            return [UIFont boldSystemFontOfSize:oldFont.pointSize];
        }
        if (traits == UIFontDescriptorTraitItalic) {
            return [UIFont italicSystemFontOfSize:oldFont.pointSize];
        }
        return oldFont;
    }

    UIFontDescriptor* fd = oldFont.fontDescriptor;

    return [UIFont fontWithDescriptor:
        [fd fontDescriptorWithSymbolicTraits: fd.symbolicTraits | traits] size:0.0f];
}

- (void)handleFormatting:(NSString*)elementName attributes:(NSDictionary*)attributeDict
{
    if ([elementName isEqualToString:@"a"]) {
        if (_links == nil) {
            _links = [[NSMutableArray alloc] init];
        }

        NSString* link = attributeDict[@"href"];
        [_links addObject:attributeDict[@"href"]];

        [self pushAttributes: @{
            NSForegroundColorAttributeName : [FLBranding fleepColor],
            NSLinkAttributeName : link ? link : @""
        } forTag:elementName];
    }
    if ([elementName isEqualToString:@"b"]) {
        [self pushAttributes: @{
            NSFontAttributeName : [self fontByAddingSymbolicTraits: UIFontDescriptorTraitBold]
        } forTag:elementName];
    }
    if ([elementName isEqualToString:@"i"]) {
        [self pushAttributes: @{
            NSFontAttributeName : [self fontByAddingSymbolicTraits: UIFontDescriptorTraitItalic]
        } forTag:elementName];
    }

     if ([elementName isEqualToString:@"emo"]) {
        NSString* emoticon = attributeDict[@"kind"];
        if (emoticon != nil) {
            [self pushAttributes:@{ FLEmoticonAttributeName : emoticon } forTag:elementName];
        }
    }

    if ([elementName isEqualToString:@"pre"]) {
        [self pushAttributes: @{
            FLParagraphBackgroundAttributeName : [UIColor colorWithWhite:0.9f alpha:1.0f],
            NSFontAttributeName : [UIFont fontWithName: @"Courier New" size:14.0f]
        } forTag:elementName];
    }

    if ([elementName isEqualToString:@"q"]) {
        [self pushAttributes: @{
            NSForegroundColorAttributeName : [UIColor darkGrayColor],
            NSFontAttributeName : [UIFont italicSystemFontOfSize: 14.0f]
        } forTag:elementName];
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if (_flags & FLMessageParserFlagAllowFormatting) {
        [self handleFormatting:elementName attributes:attributeDict];
    }

    if ([elementName isEqualToString:@"q"]) {
        if (_inQuote == 0) {
            _quotedText = [[NSMutableString alloc]init];
        }
        _inQuote++;
    }

    if ([elementName isEqualToString:@"mark"] && (_flags & FLMessageParserFlagHighlightMatches)) {
        NSDictionary* attribs = (_flags & FLMessageParserFlagHighlightFadesOut) ?
            @{
                NSBackgroundColorAttributeName: [UIColor yellowColor],
                FLFadingHighlightAttributeName: [NSDate date]
            } :
            @{
                NSBackgroundColorAttributeName: [UIColor yellowColor],
            };
        [self pushAttributes:attribs forTag:elementName];
    }

    if ([elementName isEqualToString:@"hr"]) {
        [_attributedText appendAttributedString:[[NSAttributedString alloc]
            initWithString:@"\n" attributes:@{ FLHorizontalLineAttributeName : @(1) }]];
        _inHr = YES;
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:_tags.lastObject]) {
        [self popAttributes];
    }

    if ([elementName isEqualToString:@"hr"]) {
        _inHr = NO;
    }

    if ([elementName isEqualToString:@"br"]) {
        [self appendString:@"\n"];
    }
    if ([elementName isEqualToString:@"p"]) {
        [self appendString: PARAGRAPH_BREAK];
    }

    if ([elementName isEqualToString:@"q"]) {
        _inQuote--;
    }
}

- (void)appendToResult:(NSString*)string range:(NSRange)range attributes:(NSDictionary*)attribs
{
    if (attribs != nil) {
        [self pushAttributes:attribs forTag:@""];
    }
    [_attributedText appendAttributedString:[[NSAttributedString alloc]
        initWithString:[string substringWithRange:range] attributes:[self attributes]]];
    if (attribs != nil) {
        [self popAttributes];
    }
}

- (void)appendString:(NSString*)string
{
    if (!_inQuote || !(_flags & FLMessageParserFlagHideQuotes)) {
        [_plainText appendString:string];
        if (!_inHr) {
            if ((_dataDetector != nil) && !([@"pre" isEqualToString:_tags.lastObject])) {
                NSRange range = NSMakeRange(0, string.length);
                NSTextCheckingResult* match;
                while ((match = [_dataDetector firstMatchInString:string options:0 range:range]) != nil) {
                    [self appendToResult:string range:NSMakeRange(range.location, match.range.location - range.location)
                       attributes:nil];
                    if (match.resultType == NSTextCheckingTypePhoneNumber) {
                        [self appendToResult:string range:match.range attributes:@{
                            NSForegroundColorAttributeName : [FLBranding fleepColor],
                            NSLinkAttributeName : [NSString stringWithFormat:@"tel://%@",
                                [FleepUtils cleanPhoneNumber: match.phoneNumber]]
                        }];
                    };
                    range.location = match.range.location + match.range.length;
                    range.length = string.length - range.location;
                }

                [_attributedText appendAttributedString:[[NSAttributedString alloc]
                   initWithString:[string substringWithRange:range] attributes:[self attributes]]];
            } else {
                [_attributedText appendAttributedString:[[NSAttributedString alloc]initWithString:string attributes:[self attributes]]];
            }
        }
    }
    
    if (_inQuote) {
        [_quotedText appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
/*
    string = [string stringByReplacingOccurrencesOfString:PARAGRAPH_BREAK withString:@"<PBR>"];
    string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@"<LB>"];
*/
    [self appendString: string];
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    [self parser:parser foundCharacters:[[NSString alloc] initWithData:CDATABlock
     encoding:NSUTF8StringEncoding]];
}

- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString
{
    [self parser:parser foundCharacters:whitespaceString];
}

@end

#endif
