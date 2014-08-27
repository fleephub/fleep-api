//
//  FLApiRequest.h
//  Fleep
//
//  Created by Erik Laansoo on 27.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLUtils.h"
#import "FLJsonParser.h"

typedef NSError* (^FLApiResponseHandler)(FLJsonParser*);

#define APIREQUEST_TAG_LONGPOLL 1
#define APIREQUEST_TAG_SYNC     2
#define APIREQUEST_TAG_SEARCH   3
#define APIREQUEST_TAG_CONVERSATION_CREATE 4

typedef NS_ENUM(NSInteger, FLApiRequestPriority) {
    FLApiRequestPriorityHighest = 5,
    FLApiRequestPriorityHigher = 4,
    FLApiRequestPriorityNormal = 3,
    FLApiRequestPriorityLower = 2,
    FLApiRequestPriorityLowest = 1
};


@interface FLApiRequest : NSObject

@property (readonly, nonatomic) NSInteger requestSize;
@property (readonly, nonatomic) NSMutableData* responseBody;
@property (readonly, nonatomic) NSString* contentType;
@property (readonly, nonatomic) NSInteger httpStatus;
@property (readonly, nonatomic) NSString* method;
@property (readonly, nonatomic) BOOL canRetry;

@property (readwrite, nonatomic) NSString* requestId;
@property (readwrite, nonatomic, strong) FLApiResponseHandler handler;
@property (readwrite, nonatomic, strong) FLCompletionHandlerWithNr earlyCompletionHandler;
@property (readwrite, nonatomic, strong) FLErrorHandler errorHandler;
@property (readwrite, nonatomic, strong) FLCompletionHandler successHandler;
@property (readwrite, nonatomic) NSInteger tag;
@property (readwrite, nonatomic) FLApiRequestPriority priority;

- (id)initWithMethod:(NSString*)method methodArg:(NSString*)methodArg arguments:(NSDictionary*)args;
- (id)initWithMethod:(NSString *)method arguments:(NSDictionary *)args;
- (BOOL)isMethod:(NSString*)urlPrefix;
- (void)submit;
- (void)cancel;
@end

@protocol FLApiRequestDelegate <NSObject>

- (void)request:(FLApiRequest*)request didFailWithError:(NSError*)error;
- (void)requestCompleted:(FLApiRequest*)request;

@end
