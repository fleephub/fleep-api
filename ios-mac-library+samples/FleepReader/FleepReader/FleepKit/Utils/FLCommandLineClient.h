//
//  FLCommandLineClient.h
//  FleepClient
//
//  Created by Erik Laansoo on 29.10.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^FLCommandLineCommand)(NSArray* args);

@interface FLCommandLineClient : NSObject
- (id)initWithArgc:(int)argc argv:(const char *[])argv;
- (void)addCommand:(NSString*)cmd requiredArgs:(NSArray*)requiredArgs
    optionalArgs:(NSArray*)optionalArgs body:(FLCommandLineCommand)body;
- (void)setDefaultBody:(FLCommandLineCommand)body;
- (void)exitWithMessage:(NSString*)message;
- (void)handleApiError:(NSError*)error;
- (NSString*)readStandardInput;
- (void)run;
@end
