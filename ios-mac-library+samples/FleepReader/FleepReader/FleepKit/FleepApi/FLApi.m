//
//  FleepApi.m
//  Fleep
//
//  Created by Erik Laansoo on 11.02.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLApi.h"
#import "FLApi+Actions.h"
#import "FLApiInternal.h"
#import "FLApiRequest.h"
#import "FLUtils.h"
#import "FLNetworkOperations.h"
#import "FLUserCredentials.h"
#import "FLClassificators.h"
#import "FLUserProfile.h"
#import "FLFileDownloader.h"

#define LONG_POLL_RETRY_TIMEOUT 60

static FLApi* _api = nil;

@implementation FLApi
{
    FLUserCredentials* _credentials;
    NSURL* _baseURL;
    NSURL* _baseApiURL;
    FLApiLoginStatus _loginStatus;
    NSError* _loginError;
    NSDate*         _lastSyncTime;
    NSMutableArray* _pendingRequests;
    NSMutableDictionary* _queuedRequests;
    NSInteger       _eventHorizon;
    NSTimer*        _retryTimer;
    NSError*        _lastRequestError;
    NSTimeInterval  _lastApiResponseTime;
    NSTimeInterval  _backgroundEntryTime;
    BOOL            _backgroundMode;
    NSInteger       _apiTimeoutCount;
    NSInteger       _unreadCount;
    FLApiPollType  _pollType;
    FLApiConnectionStatus _connectionStatus;
    FLApiStats* _sessionStats;
    FLApiStats* _cumulativeStats;
    FLErrorHandler _defaultErrorHandler;
    float _syncProgress;
#ifdef TARGET_IS_IPHONE
    UIBackgroundTaskIdentifier _backgroundTask;
#endif
#ifndef RELEASE
    BOOL _isCustomURL;
#endif
}

@synthesize loginStatus = _loginStatus;
@synthesize loginError = _loginError;
@synthesize lastError = _lastRequestError;
@synthesize connectionStatus = _connectionStatus;
@synthesize sessionStats = _sessionStats;
@synthesize cumulativeStats = _cumulativeStats;
@synthesize defaultErrorHandler = _defaultErrorHandler;
@synthesize syncProgress = _syncProgress;
@synthesize pollType = _pollType;
@synthesize unreadCount = _unreadCount;

- (NSInteger)eventHorizon
{
    return _eventHorizon;
}

- (void)initialSyncCompleted
{
}

- (void)setEventHorizon:(NSInteger)eventHorizon
{
    [self willChangeValueForKey:@"eventHorizon"];
    BOOL syncCompleted = (_eventHorizon < 0) && (eventHorizon > 0);
    _eventHorizon = eventHorizon;
    [[NSUserDefaults standardUserDefaults] setInteger:_eventHorizon forKey:@"EventHorizon"];
    [self didChangeValueForKey:@"eventHorizon"];
    if (syncCompleted) {
        [self initialSyncCompleted];
    }
}

- (FLUserCredentials*)credentials
{
    return _credentials;
}

- (NSURL*)baseURL
{
    return _baseURL;
}

- (NSURL*)baseApiURL
{
    return _baseApiURL;
}

- (void)startTransaction
{
}

- (void)endTransaction
{
}

- (NSError*)handleContact:(FLJsonParser*)contact
{
    return nil;
}

- (NSError*)handleConversation:(FLJsonParser *)conversation isCreateRequest:(BOOL)isCreateRequest
{
    return [self handleConversation:conversation];
}

- (NSError*)handleConversation:(FLJsonParser*)conversation
{
    return nil;
}

- (void)handleUpgradeRequestWithURL:(NSString *)url
{
}

- (NSError*)handleMessage:(FLJsonParser*)message
{
    return nil;
}

- (NSError*)handleMessageNotification:(FLJsonParser *)message
{
    return nil;
}

- (NSError*)handleActivity:(FLJsonParser *)activity
{
    return nil;
}

- (NSError*)handleHook:(FLJsonParser *)hook
{
    return nil;
}

- (NSError*)handleTeam:(FLJsonParser *)team
{
    return nil;
}

- (NSError*)handleRequest:(FLJsonParser*)request
{
    NSString* requestId = [request extractString:@"client_req_id"];
    NSNumber* result_message_nr = [request extractInt:@"result_message_nr" defaultValue:@(0)];

    FLApiRequest* r = [self pendingRequestWithRequestId:requestId];
    if ((r != nil) && (r.earlyCompletionHandler != nil)) {
        r.earlyCompletionHandler(result_message_nr.integerValue);
    }
    return nil;
}

- (void)requestCompleted:(FLApiRequest*)request
{
    [_sessionStats reportTrafficSent:request.requestSize received:request.responseBody.length];
    [_cumulativeStats reportTrafficSent:request.requestSize received:request.responseBody.length];

    NSError* error = nil;
    NSError* streamError = nil;
    NSNumber* newHorizon = nil;
    
@autoreleasepool {
    id response = nil;
    NSString* contentType = request.contentType;
    if ([contentType rangeOfString:@";"].location != NSNotFound) {
        contentType = [contentType componentsSeparatedByString:@";"][0];
    }
    
    if ([contentType isEqualToString:HTTP_CONTENT_TYPE_JSON]) {
        if (request.responseBody != nil) {
            NSError* error;
            response = [NSJSONSerialization JSONObjectWithData:request.responseBody options:0 error:&error];
            if (error != nil) {
                FLLogError(@"Request_fail: %@, Error = %@", request, error);
            }
        } else {
            FLLogError(@"Received response with JSON content-type but no body");
        }
    } else {
        if (request.responseBody != nil) {
            FLLogError(@"Received response with unexpected Content-Type: %@", request.contentType);
        }
    }

    if (request.httpStatus != HTTP_STATUS_SUCCESS) {
        if (response != nil) {
            [self request:request didFailWithError:[FLError errorWithJson:response code:request.httpStatus]];
        } else {
            [self request:request didFailWithError:[FLError errorWithCode:request.httpStatus]];
        }

        if (request.httpStatus == HTTP_STATUS_UNAUTHORIZED) {
            [_credentials erase];
            [self doLogout];
        }

        return;
    }

    if (![response isKindOfClass:[NSDictionary class]]) {
        [self request:request didFailWithError:[FLError errorWithCode:FLEEP_ERROR_INCORRECT_TYPE]];
        return;
    }

    NSDictionary* json = (NSDictionary*)response;
    NSArray *stream = [json objectForKey:@"stream"];
    newHorizon = [json objectForKey:@"event_horizon"];
    NSString* upgradeURL = [json objectForKey:@"download_url"];
    if (upgradeURL != nil) {
        [self handleUpgradeRequestWithURL:upgradeURL];
    }
    
/*
    if ((request.tag != APIREQUEST_TAG_LONGPOLL) || ((stream != nil) && (stream.count > 0))) {
        FLLogDebug(@"APIREQUEST: %@", request);
    }
*/
    [self startTransaction];

    FLJsonParser* jp = [FLJsonParser jsonParserForObject:json];
    NSNumber* syncProgress = [jp extractFloat:@"sync_progress" defaultValue:nil];
    if (syncProgress != nil) {
        FLLogDebug(@"SyncProgress = %f", syncProgress.floatValue);
        [self willChangeValueForKey:@"syncProgress"];
        _syncProgress = syncProgress.floatValue;
        [self didChangeValueForKey:@"syncProgress"];
    }

    if (error == nil) {
        NSDictionary* header = [jp extractObject:@"header" class:NSDictionary.class defaultValue:nil];
        if (header != nil) {
            [self handleConversation:[FLJsonParser jsonParserForObject:header] isCreateRequest:request.tag == APIREQUEST_TAG_CONVERSATION_CREATE];
        }
    }

    if (request.handler != nil) {
        error = request.handler(jp);
    }

    if (stream != nil) {
        if (![stream isKindOfClass:[NSArray class]]) {
            streamError = [FLError errorWithCode:FLEEP_ERROR_INVALID_JSON];
        } else {
            for (id resp in (NSArray*)stream) {
                if ([resp isKindOfClass:[NSDictionary class]]) {
                    FLJsonParser* jp = [FLJsonParser jsonParserForObject:resp];
                    NSError* e = [self handleLongPollResponse:jp];
                    if (streamError == nil) {
                        streamError = e;
                    }
                    
                 } else {
                    streamError = [FLError errorWithCode:FLEEP_ERROR_INVALID_JSON];
                    break;
                 }
            } // for
        } // stream is array
    } // stream not nil

    if ((newHorizon != nil)/* && (streamError == nil)*/) {
        if (newHorizon.integerValue == 0) {
            FLLogError(@"Server side resync requested");
            [self performSelector:@selector(handleResyncRequest) withObject:nil afterDelay:0.1f];
        }
        self.eventHorizon = newHorizon.integerValue;
    }

    [self endTransaction];
    } // @autoreleasepool

    if (error != nil) {
        [self request:request didFailWithError:error];
        return;
    }

    if (streamError != nil) {
        FLLogError(@"APIREQUEST_FAIL_STREAM: %@ => %@", request, streamError);
        _lastRequestError = streamError;
    } else {
        _lastRequestError = nil;
    }

    [_pendingRequests removeObject:request];

    if (request.successHandler != nil) {
        request.successHandler();
    }

    if (request.tag == APIREQUEST_TAG_SYNC) {
        [self sendQueuedRequest];
    }

    _lastApiResponseTime = [[NSDate date] timeIntervalSince1970];
    [_cumulativeStats save];
    [self willChangeValueForKey:@"cumulativeStats"];
    [self willChangeValueForKey:@"sessionStats"];
    [self didChangeValueForKey:@"cumulativeStats"];
    [self didChangeValueForKey:@"sessionStats"];
    
    [self updateStatus];

}

- (void)handleResyncRequest
{
    FLUserCredentials* savedCredentials = _credentials;
    [self doLogout];
    [savedCredentials save];
    [self performSelector:@selector(loginWithSavedCredentials) withObject:nil afterDelay:0.5f];
}

- (void)request:(FLApiRequest*)request didFailWithError:(NSError*)error
{
    if (![FleepUtils isCancel:error]) {
        FLLogError(@"APIREQUEST_FAIL: %@ => %@", request, error);
    };

    if (request != nil) {
        if (![FleepUtils isCancel:error] && (![FLError isBackendError:error.code])) {
            _lastRequestError = error;
        } else {
            _lastRequestError = nil;
        }

        [_pendingRequests removeObject:request];

        if (![FleepUtils isCancel:error]) {
            if (request.errorHandler != nil) {
                request.errorHandler(error);
            } else {
                if ((self.defaultErrorHandler != nil) && ![FLApi isNetworkFailure:error]) {
                    self.defaultErrorHandler(error);
                }
            }

            if (request.tag == APIREQUEST_TAG_SYNC) {
                [self retryConnectionWithError: error];
            }
        }

        [self updateStatus];
    }
}

- (FLApiRequest*)pendingRequestWithTag:(NSInteger)tag
{
    for (FLApiRequest* r in _pendingRequests) {
        if (r.tag == tag) {
            return r;
        }
    }
    return nil;
}

- (FLApiRequest*)pendingRequestWithRequestId:(NSString*)requestId
{
    requestId = [requestId lowercaseString];
    for (FLApiRequest* r in _pendingRequests) {
        if ([requestId isEqualToString:r.requestId]) {
            return r;
        }
    }
    return nil;
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
#ifndef RELEASE
  if (_isCustomURL && [challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
  {
      [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
        forAuthenticationChallenge:challenge];
      return;
  }
#endif

  [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)updateStatus
{
    [self performSelector:@selector(doUpdateStatus) withObject:self afterDelay:0.25f];
}

+ (BOOL)isNetworkFailure:(NSError*) error
{
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        return true;
    }

    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        return true;
    }

    return false;
}

- (void)doUpdateStatus
{
    FLApiConnectionStatus newStatus;

    if (_lastRequestError != nil) {
        BOOL isOffline = [FLApi isNetworkFailure:_lastRequestError];

        newStatus = isOffline ? FLApiConnectionStatusOffline : FLApiConnectionStatusError;
    } else {
        if ([_pendingRequests count] == 0) {
            newStatus = FLApiConnectionStatusOffline;
        } else {
            BOOL requestsPending = (_pendingRequests.count > 1) ||
                ([self pendingRequestWithTag:APIREQUEST_TAG_LONGPOLL] == nil);

            if (_syncProgress < 0.99f) {
                requestsPending = YES;
            }

            newStatus = requestsPending ? FLApiConnectionStatusConnecting : FLApiConnectionStatusOnline;
        }
    }
    
    if (newStatus != _connectionStatus) {
        FLLogInfo(@"API_STATUS = %ld", (long)newStatus);
        [self willChangeValueForKey:@"connectionStatus"];
        _connectionStatus = newStatus;
        [self didChangeValueForKey:@"connectionStatus"];
    }

    if (self.connectionStatus == FLApiConnectionStatusOnline) {
        _lastSyncTime = [NSDate date];
        [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)_lastSyncTime.timeIntervalSinceReferenceDate
            forKey:@"LastSyncTime"];
    }
}

+ (FLApi*)api
{
    assert(_api != nil);
    return _api;
}

- (id)init
{
    assert(_api == nil);
    if (self = [super init] ) {
        _api = self;
        _pollType = FLApiPollTypePoll;
        _pendingRequests = [[NSMutableArray alloc] init];
        _queuedRequests = [[NSMutableDictionary alloc] init];
    #ifdef TARGET_IS_IPHONE
        _backgroundTask = UIBackgroundTaskInvalid;
    #endif

        _loginStatus = FLApiLoginStatusNotLoggedIn;
        _loginError = nil;
        _baseURL = [[NSURL alloc] initWithString:@"https://fleep.io"];
        _baseApiURL = [NSURL URLWithString:@"api/" relativeToURL:_baseURL];
        FLLogInfo(@"BaseApiURL = %@", self.baseApiURL.absoluteString);
    }
    return self;
}

#ifndef RELEASE
- (void)setCustomBaseURL:(NSString*)url
{
    assert(self.loginStatus == FLApiLoginStatusNotLoggedIn);
    if (url.length > 0) {
        _baseURL = [[NSURL alloc] initWithString:url];
        _isCustomURL = YES;
    } else {
        _baseURL = [[NSURL alloc] initWithString:@"https://fleep.io"];
        _isCustomURL = NO;
    }
    _baseApiURL = [NSURL URLWithString:@"api/" relativeToURL:_baseURL];
}
#endif

NSString* _applicationId = nil;

+ (void)setApplicationId:(NSString*)applicationId
{
    _applicationId = applicationId;
}

+ (NSString*)userAgentString
{
#ifdef TARGET_IS_IPHONE
    NSString* osName = [NSString stringWithFormat:@"%@ %@",
        [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion];
#else
    NSString *osName = [NSString stringWithFormat: @"MacOS %@",
        [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
    NSString* executableName = [NSBundle mainBundle].bundleIdentifier;
    if (executableName == nil) {
        executableName = [NSBundle mainBundle].executablePath.pathComponents.lastObject;
    }
    if (_applicationId != nil) {
        executableName = _applicationId;
    }

    NSString* version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    NSString* buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    version = [NSString stringWithFormat:@"%@.%@", version, buildNumber];

    return [NSString stringWithFormat:@"%@/%@ (%@)", executableName, version, osName];
}

- (FLApiRequest*)getPendingRequestOfType:(NSString*)uriPrefix
{
    for (FLApiRequest* r in _pendingRequests) {
        if ([r isMethod:uriPrefix]) {
            return r;
        }
    }
    return nil;
}

- (void)loginWithSavedCredentials
{
    _credentials = [[FLUserCredentials alloc] init];
    if (_credentials.valid) {
        FLUserProfile* up = [[FLUserProfile alloc] init];
        if (up == nil) {
            _credentials = nil;
            return;
        }

        [self login];
    } else {
        _credentials = nil;
    }
}

- (void)sendRequest:(FLApiRequest*)request
{
    [_pendingRequests addObject:request];
    [self updateStatus];
    [request submit];
}

- (NSError*)login
{
    [self willChangeValueForKey:@"loginError"];
    _loginError = nil;
    [self didChangeValueForKey:@"loginError"];

    _eventHorizon = [[NSUserDefaults standardUserDefaults] integerForKey:@"EventHorizon"];
    _cumulativeStats = [[FLApiStats alloc] init];
    _sessionStats = [[FLApiStats alloc] init];
    [_cumulativeStats load];
    _syncProgress = 1.0f;

    FLNetworkOperations* no = [[FLNetworkOperations alloc] init];
    if (no == nil) {
        return [FLError errorWithCode:FLEEP_ERROR_CORE_DATA_CREATE];
    }

    [no addObserver:self forKeyPath:@"numberInProgress" options:0 context:nil];

    [self willChangeValueForKey:@"loginStatus"];
    _loginStatus = FLApiLoginStatusLoggedIn;
    [self didChangeValueForKey:@"loginStatus"];

    [self startLongPollInitial: YES];
    [[NSUserDefaults standardUserDefaults] synchronize];

    return nil;
}

- (void)logoutOnError:(FLErrorHandler)onError
{
    FLLogError(@"FleepApi::User initiated logout");

    if (self.credentials.cookie == nil) {
        [self doLogout];
        return;
    }
    
    FLApiRequest* request = [[FLApiRequest alloc] initWithMethod:@"account/logout" arguments:nil];
    request.successHandler = ^(void) {
        [_credentials erase];
        [self doLogout];
    };
    request.errorHandler = onError;

    [self sendRequest:request];
}

- (void)doLogout
{
    assert(self.loginStatus == FLApiLoginStatusLoggedIn);
    
    FLLogError(@"FleepApi::Logout");

    if ([_pendingRequests count] > 0) {
        FLLogInfo(@"Cancelling %ld pending requests", (long)[_pendingRequests count]);
        while (_pendingRequests.count > 0) {
            FLApiRequest* req = [_pendingRequests objectAtIndex:0];
            [req cancel];
            [_pendingRequests removeObject:req];
        }
    }

    [self willChangeValueForKey:@"unreadCount"];
    _unreadCount = 0;
    [self didChangeValueForKey:@"unreadCount"];

    [_queuedRequests removeAllObjects];
    [_retryTimer invalidate];
    _retryTimer = nil;
    _apiTimeoutCount = 0;

    [self updateStatus];
    [self willChangeValueForKey:@"loginStatus"];
    _loginStatus = FLApiLoginStatusNotLoggedIn;
    [self didChangeValueForKey:@"loginStatus"];

    [[FLNetworkOperations networkOperations] removeObserver:self forKeyPath:@"numberInProgress"];
    [[FLNetworkOperations networkOperations] logout];

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* bundleId = [NSBundle mainBundle].bundleIdentifier;
    if (bundleId == nil) {
        bundleId = [NSBundle mainBundle].executablePath.pathComponents.lastObject;
    }

    [defaults removePersistentDomainForName:bundleId];
    [defaults synchronize];

    _credentials = nil;
    _sessionStats = nil;
    _cumulativeStats = nil;

    _lastRequestError = nil;
    [self updateStatus];
}

- (void)sendQueuedRequest
{
    if ([self pendingRequestWithTag:APIREQUEST_TAG_SYNC] != nil) {
        return;
    }

    __block FLApiRequest* request = nil;
    __block NSString* key = nil;

    [_queuedRequests enumerateKeysAndObjectsUsingBlock:^(NSString* k, FLApiRequest* r, BOOL *stop) {
        if ((request == nil) || (r.priority > request.priority)) {
            request = r;
            key = k;
        }
    }];

#ifdef TARGET_IS_IPHONE
    if (_backgroundMode) {
        if ((request == nil) || (request.priority < FLApiRequestPriorityNormal)) {
            [self endBackgroundTaskIfDone];
            return;
        }
    }
#endif

    if (request == nil) {
        return;
    }

    [_queuedRequests removeObjectForKey:key];
    request.tag = APIREQUEST_TAG_SYNC;
    FLLogDebug(@"SendQueuedRequest (prio = %ld): %@", (long)request.priority, request.method);
    [self sendRequest:request];
}

- (void)queueRequest:(FLApiRequest *)request name:(NSString *)name
{
    _queuedRequests[name] = request;
    if (_retryTimer == nil) {
        [self performSelector:@selector(sendQueuedRequest) withObject:nil afterDelay:0.1f];
    }
}

// ===============
// Login
// ===============

- (NSError*)handleLoginResponse:(FLJsonParser*)response
{
    NSString* sessionTicket = [response extractString:@"ticket"];
    NSString* accountId = [response extractString:@"account_id"];
    NSString* email = nil;
    for (NSInteger i = 0; [response extractString:
            [NSString stringWithFormat: @"profiles[%ld]/account_id", (long)i] defaultValue:nil] != nil; i++) {
        NSString* aid = [response extractString:
            [NSString stringWithFormat:@"profiles[%ld]/account_id", (long)i]];
        if ([accountId isEqualToString:aid]) {
            email = [response extractString:[NSString stringWithFormat:@"profiles[%ld]/email", (long)i]];
        }
    }

    if (response.error != nil) {
        return response.error;
    }

    _credentials.email = email;
    _credentials.ticket = sessionTicket;
    _credentials.uuid = accountId;
    [_credentials save];

    FLUserProfile* up = [[FLUserProfile alloc] init];
    if (up == nil) {
        return [FLError errorWithCode:FLEEP_ERROR_CORE_DATA_CREATE];
    }

    NSError* result = [self login];

    [self startTransaction];
    if (result == nil) {
        NSDictionary* prof = [response extractObject:@"profiles[0]" class:NSDictionary.class];
        result = [self handleContact:[FLJsonParser jsonParserForObject: prof]];
    }
    [self endTransaction];

    return result;
}

- (void)handleLoginError:(NSError*)error
{
    if (self.loginStatus == FLApiLoginStatusLoggingIn) {
        [self willChangeValueForKey:@"loginError"];
        [self willChangeValueForKey:@"loginStatus"];
        _loginError = error;
        _loginStatus = FLApiLoginStatusNotLoggedIn;
        [self didChangeValueForKey:@"loginStatus"];
        [self didChangeValueForKey:@"loginError"];
    };
}

- (void)loginWithEmail:(NSString*)email password:(NSString*)password
{
    FLLogInfo(@"FleepApi::LoginWithUserId(%@, %@)", email,
        [FleepUtils stringOfChar:'*' ofLength:password.length]);
    assert(self.loginStatus == FLApiLoginStatusNotLoggedIn);

    _credentials = [[FLUserCredentials alloc] initWithUserEmail:email];

    FLApiRequest* request = [[FLApiRequest alloc] initWithMethod:@"account/login" arguments:
        @{@"email": email,
          @"password": password,
          @"remember_me": [NSNumber numberWithBool: YES]
        } ];

    request.handler = ^NSError* (FLJsonParser* response) {
        return [self handleLoginResponse:response];
      };

    request.errorHandler = ^void (NSError* error) {
        [self handleLoginError:error];
    };

    [self willChangeValueForKey:@"loginStatus"];
    _loginStatus = FLApiLoginStatusLoggingIn;
    [self didChangeValueForKey:@"loginStatus"];
    [self sendRequest:request];
}

- (void)loginWithNotificationId:(NSString *)notifictionId
{
    assert(self.loginStatus == FLApiLoginStatusNotLoggedIn);

    FLApiRequest* request = [[FLApiRequest alloc] initWithMethod:@"account/confirm" arguments:
        @{@"notification_id": notifictionId }];

    _credentials = [[FLUserCredentials alloc] init];

    request.handler = ^NSError* (FLJsonParser* response) {
        return [self handleLoginResponse:response];
      };

    request.errorHandler = ^void (NSError* error) {
        [self handleLoginError:error];
      };

    [self willChangeValueForKey:@"loginStatus"];
    _loginStatus = FLApiLoginStatusLoggingIn;
    [self didChangeValueForKey:@"loginStatus"];
    [self sendRequest:request];
}

- (void)retryConnections
{
    if (_retryTimer != nil) {
        [_retryTimer invalidate];
        _retryTimer = nil;
    }

    if ((_lastRequestError != nil) && [self.class isNetworkFailure:_lastRequestError]) {
        _lastRequestError = nil;
    }

    [self startLongPollInitial:YES];
    [self sendQueuedRequest];
}

- (void)retryConnectionWithError: (NSError*) error
{
    NSTimeInterval retryTime = SECONDS_IN_MINUTE;
    // Allow API call to time out or fail with network error five times before increasing retry delay

    if ([FLApi isNetworkFailure:error] && (_apiTimeoutCount++ < 10)) {
        retryTime = _apiTimeoutCount < 3 ? 0.5f : 10.0f;
    }

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeSinceLastTraffic = now - _lastApiResponseTime;
    NSTimeInterval timeInBackground = _backgroundMode ? (now - _backgroundEntryTime) : 0;

    if (MIN(timeSinceLastTraffic, timeInBackground) > 15 * SECONDS_IN_MINUTE) {
        retryTime = 5 * SECONDS_IN_MINUTE;
        if (timeSinceLastTraffic > SECONDS_IN_HOUR) {
            retryTime = 30 * SECONDS_IN_MINUTE;
        }
    }

    if (_retryTimer != nil) {
        [_retryTimer invalidate];
        _retryTimer = nil;
    }

    if (retryTime < 1) {
        [self retryConnections];
    } else {
        _retryTimer = [NSTimer timerWithTimeInterval:retryTime target:self
            selector:@selector(retryConnections) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:_retryTimer forMode:NSDefaultRunLoopMode];
        [self willChangeValueForKey:@"nextConnectionTime"];
        [self didChangeValueForKey:@"nextConnectionTime"];
    }
}

- (NSError*)handleLongPollResponse:(FLJsonParser*) response
{
    NSNumber* recType = [response extractEnum:@"mk_rec_type" valueMap:[FLClassificators mk_entity_type]
        defaultValue:nil];
    if (recType == nil) {
        return nil;
    }

    switch (recType.integerValue) {
        case FLEntityTypeContact:
            return [self handleContact:response];
        case FLEntityTypeConversation:
            return [self handleConversation:response];
        case FLEntityTypeMessage:
            return [self handleMessage:response];
        case FLEntityTypeActivity:
            return [self handleActivity:response];
        case FLEntityTypeHook:
            return [self handleHook:response];
        case FLEntityTypeTeam:
            return [self handleTeam:response];
        case FLEntityTypeRequest:
            return [self handleRequest:response];
        default:
            assert(NO);
    };
}

// ===============
// Long poll
// ===============

- (NSError*)handleListenResponse:(FLJsonParser*) obj
{
    NSNumber* cc = [obj extractInt:@"conv_count" defaultValue:nil];
    if (cc != nil) {
        [self willChangeValueForKey:@"unreadCount"];
        _unreadCount = cc.integerValue;
        [self didChangeValueForKey:@"unreadCount"];
    }

    NSArray* messages = [obj extractObject:@"messages" class:NSArray.class defaultValue:nil];
    if (messages != nil) {
        for (NSDictionary* d in messages) {
            FLJsonParser* message = [FLJsonParser jsonParserForObject:d];
            [self handleMessageNotification:message];
        }
    }
    return nil;
}

- (BOOL)pollWithCompletion:(FLCompletionHandler)onCompletion onError:(FLErrorHandler)onError
{
    NSString* call = (_pollType == FLApiPollTypeListen) ? @"account/listen" : @"account/poll";

    if ([self getPendingRequestOfType:call] != nil) {
        return NO;
    }

    FLApiRequest* request = [[FLApiRequest alloc]initWithMethod:call arguments:
        @{@"event_horizon": [NSNumber numberWithInteger:_eventHorizon],
          @"wait": [NSNumber numberWithBool:NO]}];

    if (_pollType == FLApiPollTypeListen) {
        request.handler = ^NSError* (FLJsonParser* response) {
            return [self handleListenResponse:response];
        };
    }
    
    request.errorHandler = ^void (NSError* error) {
        if (!_backgroundMode) {
            [self retryConnectionWithError: error];
        }
        if (onError != nil) {
            onError(error);
        }
    };

    request.successHandler = ^void(void) {
        _apiTimeoutCount = 0;
        if (!_backgroundMode) {
            [self startLongPollInitial:_eventHorizon <= 0];
        }
        if (onCompletion != nil) {
            onCompletion();
        }
    };

    [self sendRequest:request];

    return YES;
}

- (void)startLongPollInitial:(BOOL)initial
{
    NSString* call = (_pollType == FLApiPollTypeListen) ? @"account/listen" : @"account/poll";

    if ([self getPendingRequestOfType:call] != nil) {
        return;
    }

    FLApiRequest* request = [[FLApiRequest alloc]initWithMethod:call arguments:
        @{@"event_horizon": [NSNumber numberWithInteger:_eventHorizon],
          @"wait": [NSNumber numberWithBool:!initial]}];

    if (_pollType == FLApiPollTypeListen) {
    request.handler = ^NSError* (FLJsonParser* response) {
        return [self handleListenResponse:response];
      };
    }
    
    request.errorHandler = ^void (NSError* error) {
        [self retryConnectionWithError: error];
    };

    request.successHandler = ^void(void) {
        _apiTimeoutCount = 0;

        if (_backgroundMode) {
#ifdef TARGET_IS_IPHONE
            [self endBackgroundTaskIfDone];
#endif
        } else {
            [self startLongPollInitial:_eventHorizon <= 0];
        }
    };

    if (!initial) {
        request.tag = APIREQUEST_TAG_LONGPOLL;
    }

    [self sendRequest:request];
}	

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"numberInProgress"]) {
#ifdef TARGET_IS_IPHONE
        [self endBackgroundTaskIfDone];
#endif
    }
}

- (NSDate*)nextConnectionTime
{
    return _retryTimer.fireDate;
}

- (BOOL)backgroundMode
{
    return _backgroundMode;
}

- (void)setBackgroundMode:(BOOL)backgroundMode
{
    if (backgroundMode == _backgroundMode) {
        return;
    }

    FLLogInfo(@"FleepApi:SetBackgroundMode(%ld)", (long)backgroundMode);
    _backgroundMode = backgroundMode;

    if (_loginStatus != FLApiLoginStatusLoggedIn) {
        return;
    }

    [FLNetworkOperations networkOperations].background = backgroundMode;
    if (_retryTimer != nil) {
        [_retryTimer invalidate];
        _retryTimer = nil;
    }

    if (!_backgroundMode) {
        _apiTimeoutCount = 0;
        [self startLongPollInitial:YES];
        [self sendQueuedRequest];
#ifdef TARGET_IS_IPHONE
        if (_backgroundTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
            _backgroundTask = UIBackgroundTaskInvalid;
        }
#endif
        [self updateStatus];
    } else {
        FLApiRequest* longPollRequest = [self pendingRequestWithTag:APIREQUEST_TAG_LONGPOLL];
        if (longPollRequest != nil) {
            [longPollRequest cancel];
        }

        if ((_lastRequestError != nil) && [self.class isNetworkFailure:_lastRequestError]) {
            _lastRequestError = nil;
        }
#ifdef TARGET_IS_IPHONE
        if ([self hasBackgroundTasks]) {
            FLLogInfo(@"Requesting background task");
            // Request a background task to finish pending sync requests
            _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                FLLogInfo(@"Background task expired");
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
                _backgroundTask = UIBackgroundTaskInvalid;
            }];
            FLLogInfo(@"Background task id = %ld", (long)_backgroundTask);
        }
#endif
    }
}

#pragma mark iPhone specific
#ifdef TARGET_IS_IPHONE

- (void)endBackgroundTaskIfDone
{
    if (_backgroundMode) {
#ifdef DEBUG
        NSTimeInterval backgroundTimeRemaining = [UIApplication sharedApplication].backgroundTimeRemaining;

        FLLogInfo(@"EndBackgroundTasksIfDone: Running in background, time remaining = %f",
            backgroundTimeRemaining);
#endif

        if (![self hasBackgroundTasks]) {
            FLLogInfo(@"EndBackgroundTasksIfDone: all background tasks completed");
            if (_backgroundTask != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
                _backgroundTask = UIBackgroundTaskInvalid;
            }
        }
    }
}

- (BOOL)hasBackgroundTasks
{
    NSInteger networkOperationCount = [FLNetworkOperations networkOperations].numberInProgress;
    NSInteger requestCount = _pendingRequests.count;
    for (FLApiRequest* r in _queuedRequests.allValues) {
        if (r.priority >= FLApiRequestPriorityNormal) {
            requestCount++;
        }
    }
    
    FLLogDebug(@"BackgroundTaskCheck: QueuedRequests = %ld, NetworkOperations = %ld", (long)requestCount, (long)networkOperationCount);
    return (requestCount + networkOperationCount) > 0;
}

#endif

@end


