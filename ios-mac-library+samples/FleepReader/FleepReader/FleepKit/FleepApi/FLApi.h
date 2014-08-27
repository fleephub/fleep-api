//
//  FleepApi.h
//  Fleep
//
//  Created by Erik Laansoo on 11.02.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLApiStats.h"
#import "FLJsonParser.h"
#import "FLClassificators.h"
#import "FLUtils.h"
#import "FLApiRequest.h"

typedef NS_ENUM(NSInteger, FLApiLoginStatus) {
    FLApiLoginStatusNotLoggedIn = 0,
    FLApiLoginStatusLoggingIn = 1,
    FLApiLoginStatusLoggedIn = 2
};

typedef NS_ENUM(NSInteger, FLApiConnectionStatus) {
    FLApiConnectionStatusOffline = 0,
    FLApiConnectionStatusConnecting = 1,
    FLApiConnectionStatusOnline = 2,
    FLApiConnectionStatusError = 3
};

typedef NS_ENUM(NSInteger, FLApiPollType) {
    FLApiPollTypePoll = 1,
    FLApiPollTypeListen = 2
};

@interface FLApi : NSObject <FLApiRequestDelegate>

@property (nonatomic) FLApiPollType pollType;
@property (nonatomic, strong) FLErrorHandler defaultErrorHandler;
@property (nonatomic) BOOL backgroundMode;

@property (nonatomic, readonly) FLApiLoginStatus loginStatus;
@property (nonatomic, readonly) FLApiConnectionStatus connectionStatus;
@property (nonatomic, readonly) NSError* lastError;
@property (nonatomic, readonly) FLApiStats* sessionStats;
@property (nonatomic, readonly) FLApiStats* cumulativeStats;
@property (nonatomic, readonly) float syncProgress;
@property (nonatomic, readonly) NSDate* nextConnectionTime;
@property (nonatomic, readonly) NSError* loginError;
@property (nonatomic, readonly) NSInteger unreadCount;

+ (FLApi*)api;
+ (void)setApplicationId:(NSString*)applicationId;
- (void)retryConnections;
- (void)loginWithSavedCredentials;
- (void)loginWithNotificationId:(NSString*)notifictionId;
- (void)loginWithEmail:(NSString*)email password:(NSString*)password;
- (void)logoutOnError:(FLErrorHandler)onError;
- (BOOL)pollWithCompletion:(FLCompletionHandler)onCompletion onError:(FLErrorHandler)onError;
@end
