//
//  FLMarkupEncoder.m
//  Fleep
//
//  Created by Erik Laansoo on 24.01.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLMarkupEncoder.h"
#import "FLUtils.h"
#import "FLJsonParser.h"
#import "FLApi.h"
#import "FLApiInternal.h"
#import "FLFileDownloader.h"
#import "FLXMLComposer.h"


#define LT_FULL  1
#define LT_SKIP  2
#define LT_RAW   4

#define MT_STD   (1 << 8)
#define MT_EMAIL (2 << 8)
#define MT_HTML  (4 << 8)

@interface FLSyntaxFileDownloader : FLFileDownloader
@end

@implementation FLSyntaxFileDownloader

- (NSMutableURLRequest*)createRequest
{
    NSMutableURLRequest* request = [super createRequest];
    request.HTTPMethod = @"POST";
    [request setValue:HTTP_CONTENT_TYPE_JSON forHTTPHeaderField:@"Content-Type"];
    NSString* body = [NSString stringWithFormat:@"{ \"utf16\" : false, \"ticket\" : \"%@\" }",
        [FLApi api].credentials.ticket];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    return request;
}

@end

@interface FLLineType : NSObject
@property (nonatomic, readonly) NSRegularExpression* regex;
@property (nonatomic, readonly) NSInteger flags;
@end

@implementation FLLineType
{
    NSRegularExpression* _regex;
    NSInteger _flags;
}

@synthesize regex = _regex;
@synthesize flags = _flags;

- (BOOL)isValid
{
    return _regex != nil;
}

- (id)initWithValues:(id)values
{
    if (self = [super init]) {
        NSError* error = nil;
        if (![values isKindOfClass:NSArray.class]) {
            FLLogWarning(@"FLLineType::InitWithValues: values not an array");
            return self;
        }

        if (((NSArray*)values).count < 2) {
            FLLogWarning(@"FLLineType::InitWithValues: values not an array of at least 2 items");
            return self;
        }

        _regex = [NSRegularExpression regularExpressionWithPattern:values[0] options:NSRegularExpressionAnchorsMatchLines error:&error];
        if (error != nil) {
            FLLogWarning(@"FLLineType::InitWithValues: invalid regex: %@", error);
            _regex = nil;
            return self;
        }

        _flags = ((NSNumber*)values[1]).integerValue;
    }
    return self;
}

@end

typedef NS_ENUM(NSInteger, FLParserTagType) {
    FLParserTagTypeElementStart = 1,
    FLParserTagTypeElementEnd = 2,
    FLParserTagTypeEmptyElement = 3
};

@interface FLParserTag : NSObject
@property (readonly, nonatomic) FLParserTagType type;
@property (readonly, nonatomic) NSString* name;
@property (readonly, nonatomic) BOOL preserveContent;
@end

@implementation FLParserTag
{
    FLParserTagType _type;
    BOOL _preserveContent;
    NSString* name;
}
@synthesize type = _type;
@synthesize preserveContent = _preserveContent;
@synthesize name = _name;

- (id)initWithValue:(NSString*)value
{
    if (self = [super init]) {
        unichar prefix = [value characterAtIndex:0];
        unichar suffix = [value characterAtIndex:value.length - 1];
        if (suffix == '%') {
            _preserveContent = YES;
            value = [value substringToIndex:value.length - 1];
        }

        if (suffix == '/') {
            _type = FLParserTagTypeEmptyElement;
            value = [value substringToIndex:value.length - 1];
        } else {
            if (prefix == '/') {
                _type = FLParserTagTypeElementEnd;
                value = [value substringFromIndex:1];
            } else {
                _type = FLParserTagTypeElementStart;
            }
        }
        _name = value;
    }
    return self;
}

- (NSString*)description
{
    NSMutableString* result = [_name mutableCopy];

    switch (_type) {
        case FLParserTagTypeElementEnd: [result insertString:@"/" atIndex:0]; break;
        case FLParserTagTypeEmptyElement: [result appendString:@"/"]; break;
        default: break;
    }

    if (_preserveContent) {
        [result appendString:@"%%"];
    }

    return [NSString stringWithFormat: @"<%@>", result];
}

@end

@interface FLParserState : NSObject
@property (readonly, nonatomic) NSString* nextState;
@property (readonly, nonatomic) NSString* lineType;
@property (readonly, nonatomic) NSArray* tags;

- (id)initWithValues:(NSArray*)values;

@end

@implementation FLParserState
{
    NSString* _nextState;
    NSArray* _tags;
    NSString* _lineType;
}

@synthesize lineType = _lineType;
@synthesize nextState = _nextState;
@synthesize tags = _tags;

- (id)initWithValues:(NSArray *)values
{
    if (self = [super init]) {
        _lineType = values[0];
        NSString* nextState = values[1];
        NSArray* nextStateData = [nextState componentsSeparatedByString:@":"];
        _nextState = nextStateData[0];
        if (nextStateData.count > 1) {
            NSArray* tagList = [(NSString*)nextStateData[1] componentsSeparatedByString:@","];
            NSMutableArray* newTags = [[NSMutableArray alloc] init];
            for (NSString* tagValue in tagList) {
                [newTags addObject:[[FLParserTag alloc] initWithValue:tagValue]];
            }
            _tags = newTags;
        }
    }
    return self;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ => %@ %@", _lineType, _nextState, _tags];
}

@end

@interface FLMarkupSyntax : NSObject
@property (nonatomic, readonly) NSDictionary* emoticonNames;
@property (nonatomic, readonly) NSString* endToken;
@property (nonatomic, readonly) NSArray * hrefSchemas;
@property (nonatomic, readonly) NSDictionary* lineStates;
@property (nonatomic, readonly) NSDictionary* lineTypes;
@property (nonatomic, readonly) NSDictionary* multiWordEnd;
@property (nonatomic, readonly) NSDictionary* multiWordTags;
@property (nonatomic, readonly) NSRegularExpression* multiWordStart;
@property (nonatomic, readonly) NSString* startState;
@property (nonatomic, readonly) NSRegularExpression* singleWordMarkup;
@property (nonatomic, readonly) NSArray* singleWordTags;
@property (nonatomic, readonly) BOOL isValid;
@property (nonatomic, readonly) NSCharacterSet* openingParentheses;
@property (nonatomic, readonly) NSCharacterSet* closingParentheses;
@property (nonatomic, readonly) NSDictionary* parenthesesMap;
@property (nonatomic, readonly) NSCharacterSet* punctuation;

+ (FLMarkupSyntax*)syntax;

@end

@implementation FLMarkupSyntax
{
    NSDictionary* _emoticonNames;
    NSString* _endToken;
    NSArray* _hrefSchemas;
    NSDictionary* _lineStates;
    NSDictionary* _lineTypes;
    NSDictionary* _multiWordEnd;
    NSDictionary* _multiWordTags;
    NSRegularExpression* _multiWordStart;
    NSString* _startState;
    NSRegularExpression* _singleWordMarkup;
    NSArray* _singleWordTags;
    NSCharacterSet* _openingParentheses;
    NSCharacterSet* _closingParentheses;
    NSDictionary* _parenthesesMap;
    NSCharacterSet* _punctuation;
    BOOL _isValid;
}

@synthesize emoticonNames = _emoticonNames;
@synthesize endToken = _endToken;
@synthesize hrefSchemas = _hrefSchemas;
@synthesize lineStates = _lineStates;
@synthesize lineTypes = _lineTypes;
@synthesize multiWordStart = _multiWordStart;
@synthesize multiWordEnd = _multiWordEnd;
@synthesize multiWordTags = _multiWordTags;
@synthesize startState = _startState;
@synthesize singleWordMarkup = _singleWordMarkup;
@synthesize singleWordTags = _singleWordTags;
@synthesize isValid = _isValid;
@synthesize openingParentheses = _openingParentheses;
@synthesize closingParentheses = _closingParentheses;
@synthesize parenthesesMap = _parenthesesMap;
@synthesize punctuation = _punctuation;

- (BOOL)loadFromData: (NSData*)data
{
    _isValid = YES;
    NSError* err = nil;
    NSDictionary* source = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (err != nil) {
        FLLogWarning(@"FLMarkupSyntax::LoadFromJson: %@", err);
        _isValid = NO;
        return NO;
    }

    if (source[@"syntax"] != nil) {
        source = source[@"syntax"];
    }

    FLJsonParser* jp = [FLJsonParser jsonParserForObject:source];
    _emoticonNames = [jp extractObject:@"emoticon_names" class:[NSDictionary class]];
    _endToken = [jp extractString:@"end_token"];
    _hrefSchemas = [jp extractObject:@"href_schemas" class:[NSArray class]];
    _multiWordStart = [jp extractRegex:@"multi_word_start"];
    _multiWordTags = [jp extractObject:@"multi_word_tags" class:[NSDictionary class]];
    _singleWordMarkup = [jp extractRegex:@"single_word_markup"];
    _singleWordTags = [jp extractObject:@"single_word_tags" class:[NSArray class]];

    NSDictionary* rawLineTypes = [jp extractObject:@"line_types" class:[NSDictionary class]];
    _lineTypes = [rawLineTypes dictionaryByMappingObjectsUsingBlock:^id(id obj) {
        FLLineType* lt = [[FLLineType alloc] initWithValues:obj];
        _isValid &= lt.isValid;
        return lt;
    }];

    NSDictionary* rawLineStates = [jp extractObject:@"line_states" class:[NSDictionary class]];
    _lineStates = [rawLineStates dictionaryByMappingObjectsUsingBlock:^id(id obj) {
        NSArray* transitions = obj;
        return [transitions arrayByMappingObjectsUsingBlock:^id(id obj) {
            return [[FLParserState alloc] initWithValues:obj];
        }];
    }];

    NSDictionary* rawMultiWordEnd = [jp extractObject:@"multi_word_end" class:[NSDictionary class]];
    _multiWordEnd = [rawMultiWordEnd dictionaryByMappingObjectsUsingBlock:^id(id obj) {
        return [[NSRegularExpression alloc] initWithPattern:obj options:0 error:nil];
    }];

    NSString* op = [jp extractString:@"open_parens"];
    NSString* cp = [jp extractString:@"close_parens"];

    if ((op != nil) && (cp != nil)) {
        NSMutableDictionary* pm = [[NSMutableDictionary alloc] init];
        for (NSInteger i = 0; i < op.length; i++) {
            pm[[op substringWithRange:NSMakeRange(i, 1)]] = [cp substringWithRange:NSMakeRange(i, 1)];
        }

        _openingParentheses = [NSCharacterSet characterSetWithCharactersInString: op];
        _closingParentheses = [NSCharacterSet characterSetWithCharactersInString: cp];
    }

    _punctuation = [NSCharacterSet characterSetWithCharactersInString:
        [jp extractString:@"link_strip_punct" defaultValue:@".!?;,-"]];

    _startState = [jp extractString:@"start_state"];

    _isValid = YES;
    if (_lineStates[_startState] == nil) {
        FLLogWarning(@"FLMarkupSyntax::LoadFromJson: start state not valid");
        _isValid = NO;
    }

    if (jp.error != nil) {
        FLLogWarning(@"FLMarkupSyntax::LoadFromJson: %@", jp.error);
        _isValid = NO;
    }

    return _isValid;
}

+ (NSURL*)syntaxFileUrl
{
    NSFileManager* fm = [NSFileManager defaultManager];
    return [NSURL URLWithString:@"syntax.json"
        relativeToURL:[[fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject]];
}

+ (void)deleteServerSyntax
{
    NSFileManager* fm = [NSFileManager defaultManager];
    [fm removeItemAtURL:[self syntaxFileUrl] error:nil];
    [[self syntax] loadDefaultSyntax];
}

- (void)loadDefaultSyntax
{
    NSBundle* mb = [NSBundle mainBundle];
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* rp = [mb pathForResource:@"syntax" ofType:@"json"];
    if ((rp != nil) && [fm fileExistsAtPath:rp]) {
        [self loadFromData:[fm contentsAtPath:rp]];
    }
}

+ (FLMarkupSyntax*)syntax
{
    static FLMarkupSyntax* ms = nil;
    if (ms == nil) {
        BOOL atteptDownload = NO;

        NSFileManager* fm = [NSFileManager defaultManager];

        ms = [[FLMarkupSyntax alloc] init];

        if ([fm fileExistsAtPath:[self syntaxFileUrl].path]) {
            NSDictionary* attributes = [fm attributesOfItemAtPath:[self syntaxFileUrl].path error:nil];
            NSDate* md = attributes[NSFileModificationDate];
            atteptDownload = [md timeIntervalSinceNow] < -SECONDS_IN_DAY;
            [ms loadFromData:[fm contentsAtPath:[self syntaxFileUrl].path]];
        }

        if (![ms isValid]) {
            atteptDownload = YES;
            [ms loadDefaultSyntax];
        }

        if (!ms.isValid) {
            FLLogWarning(@"FLMarkupEncoder: no syntax definition file, markup encoding disabled");
        }

        if (atteptDownload) {
            FLFileDownloader* fd = [[FLSyntaxFileDownloader alloc]
                initWithRemoteURL: @"api/markup/get_syntax" localRelativePath:@"syntax.json" expectedSize:0];
            static FLFileDownloaderBlockDelegate* fdd = nil;
            fdd = [[FLFileDownloaderBlockDelegate alloc] init];
            fdd.OnDownloadCompleted = ^(NSURL* localUrl) {
                ms = nil;
            };
            fd.delegate = fdd;
        }
    }

    return ms;
}

@end

@implementation FLMarkupEncoder
{
    FLXMLComposer* _xml;
    FLMarkupSyntax* _syntax;
}

+ (void)resetToDefaultSyntax
{
    [FLMarkupSyntax deleteServerSyntax];
}

+ (NSString*)xmlWithMessage:(NSString*)message
{
    FLMarkupEncoder* me = [[FLMarkupEncoder alloc] initWithMessage:message];
    return me.result;
}

+ (NSData*)dataWithMessage:(NSString*)message
{
    FLMarkupEncoder* me = [[FLMarkupEncoder alloc] initWithMessage:message];
    return me.data;
}

- (id)initWithMessage:(NSString*)message
{
    if (self = [super init]) {
        _xml = [[FLXMLComposer alloc] init];
        _syntax = [FLMarkupSyntax syntax];

        if (_syntax.isValid) {
            [self parseMessage:message];
        } else {
            [_xml startElement:@"msg"];
            [_xml addText:message];
            [_xml endElement:@"msg"];
        }
    }
    return self;
}

- (NSString*)stripLink:(NSString*)link
{
    NSMutableString* parentheses = [[NSMutableString alloc] init];

    NSInteger length = 0;
    for (NSInteger i = 0; i < link.length; i++) {
        unichar c = [link characterAtIndex:i];
        if ([_syntax.openingParentheses characterIsMember:c]) {
            [parentheses appendFormat:@"%@", _syntax.parenthesesMap[[NSString stringWithFormat:@"%c", c]]];
            continue;
        }

        if ([_syntax.closingParentheses characterIsMember:c] && (parentheses.length > 0) &&
            ([parentheses characterAtIndex:parentheses.length - 1] == c)) {
            [parentheses deleteCharactersInRange:NSMakeRange(parentheses.length - 1, 1)];
        }

        if (parentheses.length == 0) {
            length = i + 1;
        }
    }

    while ((length > 0) && [_syntax.punctuation characterIsMember:[link characterAtIndex:length - 1]]) {
        length--;
    }

    return [link substringToIndex:length];
}

- (NSInteger)addEmoticon:(NSString*)text
{
    NSString* name = _syntax.emoticonNames[text];
    if (name != nil) {
        [_xml startElement:@"emo" withAttributes:@{ @"kind" : name }];
        [_xml addText:text];
        [_xml endElement:@"emo"];
    } else {
        [_xml addText:text];
    }
    return text.length;
}

- (NSInteger)addLink:(NSString*)url withSchema:(NSString*)schema
{
    url = [self stripLink:url];
    NSString* finalUrl = url;
    if (schema != nil) {
        finalUrl = [NSString stringWithFormat:@"%@://%@", schema, url];
    }

    [_xml startElement:@"a" withAttributes:@{@"href" : finalUrl }];
    [_xml addText:url];
    [_xml endElement:@"a"];
    return url.length;
}

- (void)processSingleTokens:(NSString*)part
{
    NSInteger pos = 0;
    while (pos < part.length) {
        NSArray* matches = [_syntax.singleWordMarkup matchesInString:part options:0
            range: NSMakeRange(pos, part.length - pos)];
        if (matches.count == 0) {
            [_xml addText:[part substringFromIndex:pos]];
            break;
        }

        for (NSTextCheckingResult* match in matches) {
            NSString* tokenType = nil;
            NSString* token = nil;
            for (NSInteger i = 0; i < MIN(match.numberOfRanges - 1, _syntax.singleWordTags.count); i++) {
                NSRange matchRange = [match rangeAtIndex: i + 1];
                if (matchRange.location != NSNotFound) {
                    tokenType = _syntax.singleWordTags[i];
                    token = [part substringWithRange:matchRange];
                    [_xml addText:[part substringWithRange:NSMakeRange(pos, matchRange.location - pos)]];
                    pos = matchRange.location;
                    break;
                }
            }

            if ([tokenType isEqualToString:@"emo"]) {
                pos += [self addEmoticon:token];
            } else if ([tokenType hasPrefix:@"link"]) {
                NSString* schema = nil;
                NSArray* tt = [tokenType componentsSeparatedByString:@":"];
                if (tt.count > 1) {
                    schema = tt[1];
                }

                pos += [self addLink:token withSchema:schema];
            } else {
                [_xml addText:token];
                pos += token.length;
            }
        }

    }
}

- (NSString*)processBlockTags:(NSArray*)tags line:(NSString*)line match:(NSString*)match
{
    for (FLParserTag* tag in tags) {
        switch (tag.type) {
            case FLParserTagTypeElementEnd: {
                if (tag.preserveContent && (match != nil)) {
                    [_xml addAttribute:@"fls" value:match toElement:_xml.currentElement];
                    line = [line substringFromIndex:MIN(match.length, line.length)];
                }
                [_xml endElement:tag.name];
            }
            break;
            case FLParserTagTypeElementStart: {
                if (tag.preserveContent && (match != nil)) {
                    [_xml startElement:tag.name withAttributes:@{ @"flp" : match }];
                    line = [line substringFromIndex:MIN(match.length, line.length)];
                } else {
                    [_xml startElement:tag.name];
                }

            }
            break;
            case FLParserTagTypeEmptyElement: {
                [_xml addEmptyElement:tag.name];
            }
            break;
        }
    }

    return line;
}

- (void)processLongTags:(NSString*)line
{
    NSInteger mainPos = 0;
    for (NSInteger pos = 0; pos < line.length;) {
        NSArray* mr = [_syntax.multiWordStart matchesInString:line options:0 range:NSMakeRange(pos, line.length - pos)];
        if (mr.count == 0) {
            [self processSingleTokens:[line substringFromIndex:mainPos]];
            return;
        }

        NSTextCheckingResult* match = mr[0];

        NSRange matchRange = [match rangeAtIndex:1];
        NSString* matchStr = [line substringWithRange:matchRange];
        NSString* tag = _syntax.multiWordTags[matchStr];
        NSRange endTokenRange = NSMakeRange(NSNotFound, 0);
        if ((tag != nil) && ![_xml isElementOpen:tag]) {
            NSRegularExpression* er = _syntax.multiWordEnd[matchStr];
            NSArray* endTokenMatches = [er matchesInString:line options:0
                range:NSMakeRange(matchRange.location + matchRange.length, line.length - matchRange.location - matchRange.length)];
            if (endTokenMatches.count > 0) {
                NSTextCheckingResult* etm = endTokenMatches[0];
                if (etm.numberOfRanges > 1) {
                    endTokenRange = [etm rangeAtIndex:1];
                }
            }
        }

        if (endTokenRange.location != NSNotFound) {
            NSString* endMatch = [line substringWithRange:endTokenRange];
            [self processSingleTokens:[line substringWithRange:NSMakeRange(mainPos, matchRange.location - mainPos)]];
            [_xml startElement:tag withAttributes:@{ @"flp" : matchStr, @"fls" : endMatch }];
            [self processLongTags:[line substringWithRange:NSMakeRange(matchRange.location + matchRange.length,
                endTokenRange.location - matchRange.location - matchRange.length)]];
            [_xml endElement:tag];
            mainPos = pos = endTokenRange.location + endTokenRange.length;
        } else {
            pos = matchRange.location + matchRange.length;
        }
    }
}

- (void)parseMessage:(NSString*)message
{
    NSString* state = _syntax.startState;
    NSInteger nextPos = 0;
    for (NSInteger pos = 0; pos < message.length; pos = nextPos) {
        NSArray* scanState = _syntax.lineStates[state];
        NSString* match = nil;
        FLParserState* nextState = nil;
        FLLineType* lt = nil;
        for (FLParserState* ss in scanState) {
            lt = _syntax.lineTypes[ss.lineType];
            NSArray* matches = nil;
            if ((matches = [lt.regex matchesInString:message options:NSMatchingAnchored
                range:NSMakeRange(pos, message.length - pos)]).count > 0) {
                nextState = ss;
                NSRange matchRange = NSMakeRange(NSNotFound, 0);
                for (NSTextCheckingResult* match in matches) {
                    for (NSInteger i = 1; i < match.numberOfRanges; i++) {
                        if ([match rangeAtIndex:i].location != NSNotFound) {
                            matchRange = [match rangeAtIndex:i];
                            break;
                        }
                    }
                    if (matchRange.location != NSNotFound) {
                        break;
                    }
                }

                match = (matchRange.location != NSNotFound) ? [message substringWithRange:matchRange] : @"";
                break;
            }
        }

        NSInteger linebreakPos = [message rangeOfString:@"\n" options:0
            range:NSMakeRange(pos, message.length - pos)].location;
        NSString* line;
        if (linebreakPos == NSNotFound) {
            line = [message substringFromIndex:pos];
            nextPos = message.length;
        } else {
            line = [message substringWithRange:NSMakeRange(pos, linebreakPos - pos)];
            nextPos = linebreakPos + 1;
        }

        state = nextState.nextState;
        line = [self processBlockTags:nextState.tags line:line match:match];

        if (lt.flags & LT_FULL) {
            [self processLongTags:line];
        } else if (lt.flags & LT_SKIP) {
          // ignore
        } else if (lt.flags & LT_RAW) {
            [_xml addText:line];
            [_xml addText:@"\n"];
        } else {
            FLLogWarning(@"Unknown line type");
        }
    }

    NSArray* scanState = _syntax.lineStates[state];
    FLParserState* lastState = scanState.lastObject;
    [self processBlockTags:lastState.tags line:@"" match:nil];
}

- (NSString*)result
{
    return _xml.result;
}

- (NSData*)data
{
    return _xml.data;
}

@end
