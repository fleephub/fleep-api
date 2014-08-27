//
//  FleepUtils.h
//  Fleep
//
//  Created by Erik Laansoo on 19.02.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "TargetConditionals.h"

#if TARGET_IPHONE_SIMULATOR
#define TARGET_IS_IPHONE
#endif

#if TARGET_OS_IPHONE
#define TARGET_IS_IPHONE
#endif

#define SECONDS_IN_MINUTE 60
#define SECONDS_IN_HOUR (SECONDS_IN_MINUTE * 60)
#define SECONDS_IN_DAY (SECONDS_IN_HOUR * 24)

#define FLEEP_ERROR_DOMAIN @"FLApiError"

#define HTTP_STATUS_SUCCESS 200
#define HTTP_STATUS_INVALID_REQUEST 400
#define HTTP_STATUS_UNAUTHORIZED 401
#define HTTP_STATUS_FORBIDDEN 403
#define HTTP_STATUS_NOT_FOUND 404

#define FLEEP_ERROR_BACKEND_ERROR 430

#define FLEEP_ERROR_CANCELLED 1000
#define FLEEP_ERROR_INVALID_JSON 1001
#define FLEEP_ERROR_MISSING_VALUE 1002
#define FLEEP_ERROR_INCORRECT_TYPE 1003
#define FLEEP_ERROR_INCORRECT_ENUM 1004
#define FLEEP_ERROR_INCORRECT_BOOL 1005
#define FLEEP_ERROR_INCORRECT_DATE 1006
#define FLEEP_ERROR_TECH_FAILURE 1007
#define FLEEP_ERROR_CORE_DATA_CREATE 1008
#define FLEEP_ERROR_FILE_CREATE_FAILED 1009
#define FLEEP_ERROR_NO_FILE_DATA 1010

#define FLLog(fmt...) NSLog(fmt)
#ifdef DEBUG
#define FLLogDebug(fmt...) FLLog(fmt)
#define FLLogInfo(fmt...) FLLog(fmt)
#else
#define FLLogDebug(fmt...) /* */
#define FLLogInfo(fmt...) /* */
#endif

#ifdef xTARGET_IS_IPHONE
#undef FLLogDebug
#undef FLLogInfo
#define FLLogDebug(fmt...) /* */
#define FLLogInfo(fmt...) /* */
#endif

#define FLLogWarning(fmt...) FLLog(fmt)

void FLLogError(NSString* fmt, ...);

#define FLEEP_ERROR_ID_UNKNOWN = @"UNKNOWN_ERROR"
#define FLEEP_NOTIFICATION_FATAL_ERROR @"FleepFatalError"

#define HTTP_CONTENT_TYPE_JSON @"application/json"

#define ALL_DATE_COMPONENTS (NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit\
 | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit | NSTimeZoneCalendarUnit)

/*
 *  System Versioning Preprocessor Macros
 */ 

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending

extern NSString* FLFadingHighlightAttributeName;

@class FLError;

typedef void(^FLCompletionHandler)(void);
typedef void(^FLCompletionHandlerWithGuid)(NSString* objectId);
typedef void(^FLCompletionHandlerWithNr)(NSInteger nr);
typedef void(^FLErrorHandler)(NSError*);
typedef void(^FLProgressHandler)(CGFloat progress);
typedef NSString*(^FLErrorLocalizer)(FLError*);

@interface FLError : NSError
@property (readonly, nonatomic) NSString* backendErrorId;

+ (void)setErrorLocalizer:(FLErrorLocalizer)localizer;
+ (BOOL)isBackendError:(NSInteger)errorCode;
+ (id)errorWithCode:(NSInteger) code;
+ (id)errorWithCode:(NSInteger) code andUserInfo:(NSDictionary*)userInfo;
+ (id)errorWithBackendErrorId:(NSString*)errorId code:(NSInteger)code;;
+ (id)errorWithJson:(NSDictionary*)errorObj code:(NSInteger)code;

- (id)initWithCode:(NSInteger) code;
- (id)initWithCode:(NSInteger) code andUserInfo:(NSDictionary*)userInfo;
- (id)initWithBackendErrorId:(NSString*)errorId code:(NSInteger)code;
- (id)initWithJson:(NSDictionary*)errorObj code:(NSInteger)code;

- (NSString*)localizedDescription;
@end

@interface FleepUtils : NSObject
+ (NSString*) stringOfChar:(const unichar)ch ofLength:(NSInteger)length;
+ (NSString*) shortenString:(NSString*)string toLength:(NSInteger)length;
+ (BOOL)isCancel:(NSError*)error;

+ (NSDate*)extractDateFrom:(NSDate*)date;
+ (NSString*)formatLogTimestamp:(NSDate*)date;
+ (BOOL)isValidEmail:(NSString*)email;
+ (NSString*)cleanPhoneNumber:(NSString*)phoneNumber;
+ (NSString*)generateUUID;
@end

@interface FLErrorLog : NSObject
@property (nonatomic, readonly) NSURL* logFileURL;
@property (nonatomic, readonly) NSUInteger logFileSize;

+ (FLErrorLog*)errorLog;
- (void)logMessage:(NSString*)message;
- (void)flush;
- (void)deleteLogFile;
@end

@interface FLURLConnection : NSObject
- (void)cancel;
@end

@interface FLURLConnectionFactory : NSObject
- (FLURLConnection*)connectionForRequest:(NSURLRequest*)request delegate:(id)delegate;
+ (FLURLConnectionFactory*)factory;
+ (void)setFactory:(FLURLConnectionFactory*)factory;
@end

@interface NSData (Base64Encoding)
- (NSString*)asBase64String;
- (NSString*)asHexString;
@end

typedef id (^MapObject)(id obj);

@interface NSArray (Mapping)
- (NSArray*)arrayByMappingObjectsUsingBlock:(MapObject)block;
@end

@interface NSDictionary (Mapping)
- (NSDictionary*)dictionaryByMappingObjectsUsingBlock:(MapObject)block;
@end

@interface NSString (PrefixSearch)
- (NSRange)rangeOfPrefixString:(NSString*)substring;
- (NSRange)rangeOfPrefixString:(NSString *)substring range:(NSRange)range;
#ifdef TARGET_IS_IPHONE
- (NSAttributedString*)attributedStringHighlightingRange:(NSRange)range;
#endif
@end

@interface NSAttributedString (Highlight)
- (NSAttributedString*)extractHighlightedFragmentFitInLength:(NSInteger)position;
@end
