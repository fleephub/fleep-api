//
//  FLNetworkOperations.h
//  Fleep
//
//  Created by Erik Laansoo on 06.09.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLUtils.h"

@interface FLNetworkOperation : NSObject <NSURLConnectionDataDelegate>
{
    FLURLConnection* _connection;
    NSUInteger _expectedResponseSize;
    NSURL* _url;
    NSError* _error;
}

@property (nonatomic, readonly) NSError* error;
@property (nonatomic, readonly) NSString* identifier;
@property (nonatomic, readonly) float progress;

+ (BOOL)continuesInBackground;
+ (BOOL)removeWhenFinished;
+ (NSString*)persistenceId;

- (void)submitRequest:(NSMutableURLRequest*)request;
- (void)cancel;
- (NSDictionary*)serialize;
- (id)initWithValues:(NSDictionary*)values;
- (void)setProgress:(float)progress;
- (void)uploadProgress:(float)progress;
- (void)downloadProgress:(float)progress;
- (void)failWithError:(NSError*)error;
- (void)completedWithData:(NSData*)data;
- (void)remove;
@end

@interface FLNetworkOperations : NSObject <NSFastEnumeration>
@property (readonly, nonatomic) NSUInteger count;
@property (readonly, nonatomic) NSUInteger numberInProgress;
@property (nonatomic) BOOL background;

+ (void)declarePersistentOperationClass:(Class)operationClass;
+ (FLNetworkOperations*)networkOperations;
- (FLNetworkOperation*)objectAtIndexedSubscript:(NSUInteger)index;
- (void)saveState;
- (void)logout;
- (NSArray*)operationsWithClass:(Class)class andIdentifier:(NSString*)identifier;
- (void)deleteOperationsWithClass:(Class)class andIdentifier:(NSString*)identifier;
@end
