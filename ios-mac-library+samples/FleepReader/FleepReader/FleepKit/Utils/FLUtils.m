//
//  FleepUtils.m
//  Fleep
//
//  Created by Erik Laansoo on 19.02.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLUtils.h"
#include <wchar.h>

NSString* FLFadingHighlightAttributeName = @"FLFadingHighlight";

@implementation FLError

FLErrorLocalizer _errorLocalizer = nil;

+ (id)errorWithCode:(NSInteger)code
{
    return [[self alloc] initWithCode:code];
}

+ (id)errorWithCode:(NSInteger)code andUserInfo:(NSDictionary *)userInfo
{
    return [[self alloc] initWithCode:code andUserInfo:userInfo];
}

+ (id)errorWithBackendErrorId:(NSString*)errorId code:(NSInteger)code;
{
    return [[self alloc] initWithBackendErrorId:errorId code:code];
}

+ (id)errorWithJson:(NSDictionary*)errorObj code:(NSInteger)code;
{
    return [[self alloc] initWithJson:errorObj code:code];
}

- (id)initWithCode:(NSInteger) code
{
    self = [self initWithDomain:FLEEP_ERROR_DOMAIN code:code userInfo:nil];
    return self;
}

- (id)initWithCode:(NSInteger) code andUserInfo:(NSDictionary *)userInfo
{
    self = [self initWithDomain:FLEEP_ERROR_DOMAIN code:code userInfo:userInfo];
    return self;
}

- (id)initWithBackendErrorId:(NSString*)errorId code:(NSInteger)code;
{
    self = [self initWithDomain:FLEEP_ERROR_DOMAIN code:code
      userInfo: @{@"error_id" : errorId }];

    return self;
}

- (NSString*)backendErrorId
{
    return self.userInfo[@"error_id"];
}

- (id)initWithJson:(NSDictionary*)errorObj code:(NSInteger)code;
{
    self = [self initWithDomain:FLEEP_ERROR_DOMAIN code:code userInfo:errorObj];
    return self;
}

+ (void)setErrorLocalizer:(FLErrorLocalizer)localizer
{
    _errorLocalizer = localizer;
}

- (NSString*)localizedDescription
{
    NSString* result = nil;

    if (_errorLocalizer != nil) {
        result = _errorLocalizer(self);
    }

    if (result == nil) {
        result = self.userInfo[@"error_message"];
    }

    if (result == nil) {
        result = self.userInfo[@"error_id"];
    }

    if (result == nil) {
        result = [super localizedDescription];
    }

    return result;
}

+ (BOOL)isBackendError:(NSInteger)errorCode
{
    return (errorCode / 10) == (FLEEP_ERROR_BACKEND_ERROR / 10);
}

@end

@implementation FleepUtils

+ (NSString*) stringOfChar:(const unichar)ch ofLength:(NSInteger)length;
{
    unichar* s = malloc((length + 1) * sizeof(unichar));
    for (int i = 0; i < length; i++) {
        s[i] = ch;
    }
    NSString* result = [NSString stringWithCharacters:s length:length];
    free(s);
    return result;
}

+ (BOOL)isCancel:(NSError *)error
{
    return ([error.domain isEqualToString:FLEEP_ERROR_DOMAIN] && (error.code == FLEEP_ERROR_CANCELLED));
}

+ (NSString*)cleanPhoneNumber:(NSString *)phoneNumber
{
    NSCharacterSet* allowedChars = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString* res = [[NSMutableString alloc] init];
    for (NSInteger i = 0; i < phoneNumber.length; i++) {
        if ([allowedChars characterIsMember:[phoneNumber characterAtIndex:i]]) {
            [res appendFormat:@"%C", [phoneNumber characterAtIndex:i]];
        }
    }

    return res;
}

+ (NSString*)generateUUID
{
    CFUUIDRef myUUID = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef res = CFUUIDCreateString(kCFAllocatorDefault, myUUID);
    NSString* result = (__bridge NSString*)res;
    CFRelease(res);
    CFRelease(myUUID);
    return result;
}

+ (NSDate*)extractDateFrom:(NSDate *)date
{
    NSCalendar* cal = [NSCalendar currentCalendar];
    NSDateComponents* dc = [cal components:(NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit)
     fromDate:date];
    return [cal dateFromComponents:dc];
}

+ (NSString*) formatLogTimestamp:(NSDate *)date
{
    static NSDateFormatter * df = nil;
    if (df == nil) {
        df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"dd HH:mm:ss";
    }
    return [df stringFromDate:date];
}

+ (NSString*) shortenString:(NSString*)string toLength:(NSInteger)length
{
    if (string.length <= length) {
        return string;
    }
    return [NSString stringWithFormat:@"%@...", [string substringToIndex:length - 3]];
}

+ (BOOL)isValidEmail:(NSString *)email
{
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}"; 
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex]; 

    return [emailTest evaluateWithObject:email];
}

@end

@implementation FLURLConnection
- (void)cancel
{
    assert(false);
}
@end

@interface FLDefaultURLConnection : FLURLConnection
- (id)initWithURLConnection:(NSURLConnection*)uc;
@end

@implementation FLDefaultURLConnection
{
    NSURLConnection* urlConnection;
}

- (void)cancel
{
    [urlConnection cancel];
}

- (id)initWithURLConnection:(NSURLConnection*)uc
{
    urlConnection = uc;
    return self;
}

@end

@interface FLDefaultURLConnectionFactory : FLURLConnectionFactory
@end

@implementation FLDefaultURLConnectionFactory
- (FLURLConnection*)connectionForRequest:(NSURLRequest*)request delegate:(id)delegate
{
    NSURLConnection* urlConnection = [[NSURLConnection alloc]initWithRequest:request delegate:delegate startImmediately:YES];
    return [[FLDefaultURLConnection alloc]initWithURLConnection:urlConnection];
}

@end

FLURLConnectionFactory* _urlConnectionFactory = nil;

@implementation FLURLConnectionFactory

- (FLURLConnection*)connectionForRequest:(NSURLRequest*)request delegate:(id)delegate
{
    assert(false);
}

+ (FLURLConnectionFactory*)factory
{
    if (_urlConnectionFactory == nil) {
        _urlConnectionFactory = [[FLDefaultURLConnectionFactory alloc]init];
    }
    return _urlConnectionFactory;
}

+ (void)setFactory:(FLURLConnectionFactory*)factory
{
    _urlConnectionFactory = factory;
}

@end

@implementation NSData (Base64Encoding)
- (NSString*)asBase64String
{
    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    char* buf = (char*)self.bytes;
    char* be = buf + self.length;
    NSMutableString* result = [[NSMutableString alloc] init];
    
    while (buf < be) {
        short b1 = (buf < be) ? *buf++ : 0;
        short b2 = (buf < be) ? *buf : 0;

        [result appendFormat:@"%c%c",
            table[(b1 & 0xfc) >> 2],
            table[((b1 & 3) << 4) | ((b2 & 0xf0) >> 4)]];

        if (buf < be) {
            buf++;
            char b3 = (buf < be) ? *buf : 0;

            [result appendFormat:@"%c%c",
                table[((b2 & 0x0f) << 2) | ((b3 & 0xc0) >> 6)],
                (buf < be) ? table[b3 & 0x3f] : '='];

            if (buf < be) buf++;
        } else {
            [result appendString:@"=="];
        }
    }

    return result;
}

- (NSString*)asHexString
{
    char* buf = (char*)self.bytes;
    char* be = buf + self.length;
    NSMutableString* result = [[NSMutableString alloc] init];
    static char table[] = "0123456789abcdef";
    
    while (buf < be) {
        char s1 = (*buf & 0xf0) >> 4;
        char s2 = *buf & 0x0f;
        [result appendFormat:@"%c%c", table[s1], table[s2]];
        buf++;
    }
    return result;
}

@end

@implementation FLErrorLog
{
    NSURL* _logFileURL;
    NSFileHandle* _logFileHandle;
}

@synthesize logFileURL = _logFileURL;

- (NSUInteger)logFileSize
{
    return (NSUInteger)_logFileHandle.offsetInFile;
}

+ (FLErrorLog*)errorLog
{
    static FLErrorLog* el = nil;
    if (el == nil) {
        el = [[FLErrorLog alloc] init];
    }
    return el;
}

- (id)init
{
    if (self = [super init]) {
        NSFileManager* fm = [NSFileManager defaultManager];
        NSURL* baseURL = [[fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
        _logFileURL = [baseURL URLByAppendingPathComponent:@"errors.log"];
        if (![fm fileExistsAtPath:_logFileURL.path]) {
            [fm createFileAtPath:_logFileURL.path contents:[[NSData alloc] init] attributes:nil];
        }
        _logFileHandle = [NSFileHandle fileHandleForWritingAtPath:_logFileURL.path];
        [_logFileHandle seekToEndOfFile];
    }
    return self;
}

- (void)logMessage:(NSString*)message
{
    NSDate* d = [NSDate date];
    NSString* timestamp = d.description;
    NSString* msg = [NSString stringWithFormat:@"%@ %@\n", timestamp, message];
    [_logFileHandle writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
}


- (void)flush
{
    [_logFileHandle synchronizeFile];
}

- (void)deleteLogFile
{
    [_logFileHandle truncateFileAtOffset:0];
}

@end

void FLLogError(NSString* fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    NSString* msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"%@", msg);
    [[FLErrorLog errorLog] logMessage:msg];
}

@implementation NSArray (Mapping)
- (NSArray*)arrayByMappingObjectsUsingBlock:(MapObject)block
{
    NSMutableArray* result = [self mutableCopy];
    for (NSInteger i = 0; i < result.count; i++) {
        result[i] = block(result[i]);
    }

    return [NSArray arrayWithArray:result];
}

@end


@implementation NSDictionary (Mapping)

- (NSDictionary*)dictionaryByMappingObjectsUsingBlock:(MapObject)block
{
    NSMutableDictionary* result = [self mutableCopy];
    for (id key in self.keyEnumerator) {
        result[key] = block(result[key]);
    }
    return [NSDictionary dictionaryWithDictionary:result];
}

@end

@implementation NSString (PrefixSearch)

- (NSRange)rangeOfPrefixString:(NSString*)substring range:(NSRange)range
{
    static NSCharacterSet* separators = nil;
    if (separators == nil) {
        NSMutableCharacterSet* s = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [s formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        separators = s;
    }

    if ((substring == nil) || (self.length < substring.length)) {
        return NSMakeRange(NSNotFound, 0);
    }

    NSRange r = NSMakeRange(range.location, substring.length);
    while ((r.location + r.length) <= range.length) {
        if ((r.location > 0) && ![separators characterIsMember:[self characterAtIndex:r.location - 1]]) {
            r.location++;
            continue;
        }

        NSRange substringRange = [self rangeOfString:substring options:NSCaseInsensitiveSearch range:r];
        if (substringRange.location != NSNotFound) {
            return substringRange;
        }

        r.location++;
    }

    return NSMakeRange(NSNotFound, 0);
}

- (NSRange)rangeOfPrefixString:(NSString *)substring
{
    return [self rangeOfPrefixString:substring range:NSMakeRange(0, self.length)];
}

#ifdef TARGET_IS_IPHONE
- (NSAttributedString*)attributedStringHighlightingRange:(NSRange)range
{
    if (range.location == NSNotFound) {
        return [[NSAttributedString alloc] initWithString:self];
    }

    NSDictionary* yellow = @{NSBackgroundColorAttributeName : [UIColor yellowColor]};

    NSMutableAttributedString* res = [[NSMutableAttributedString alloc]
        initWithString:[self substringToIndex:range.location]];
    [res appendAttributedString:[[NSAttributedString alloc] initWithString:[self substringWithRange:range]
        attributes:yellow]];
    [res appendAttributedString:[[NSAttributedString alloc] initWithString:
        [self substringFromIndex:range.location + range.length]]];
    return res;
}
#endif

@end

@implementation NSAttributedString (Highlight)

- (NSAttributedString*)extractHighlightedFragmentFitInLength:(NSInteger)length
{
    return self;
/*
    __block NSInteger highlightPos = NSNotFound;

    NSMutableAttributedString* result = [self mutableCopy];
    NSCharacterSet* nlcs = [NSCharacterSet newlineCharacterSet];
    for (NSInteger i = 0; i < result.length;) {
        NSRange nlr = [result.string rangeOfCharacterFromSet:nlcs options:0 range:NSMakeRange(i, result.length - i)];
        if (nlr.location == NSNotFound) {
            break;
        }
        [result replaceCharactersInRange:nlr withString:@" "];
        i = nlr.location + 1;
    }

    [result enumerateAttribute:NSBackgroundColorAttributeName inRange:NSMakeRange(0, self.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value != nil) {
            highlightPos = range.location;
            *stop = YES;
        }
    }];

    if (highlightPos == NSNotFound) {
        return result;
    }

    NSInteger cutPos = MIN(highlightPos - (length / 2), (NSInteger)result.length - length);

    NSCharacterSet* whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    while ((cutPos >= 0) && (cutPos < highlightPos) && [whitespace characterIsMember:[result.string characterAtIndex:cutPos]]) {
        cutPos++;
    }

    if (cutPos <= 0) {
        return result;
    }

    NSMutableAttributedString* res = [[NSMutableAttributedString alloc] initWithString:@"..." attributes:nil];
    [res appendAttributedString:[result attributedSubstringFromRange:NSMakeRange(cutPos, result.length - cutPos)]];
    return res;
    */
}

@end

