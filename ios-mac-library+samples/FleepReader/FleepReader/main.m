//
//  main.m
//  FleepReader
//
//  Created by Erik Laansoo on 02.08.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "DataModel.h"
#import "ReaderApi.h"
#import "FLCommandLineClient.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        ReaderApi* api = [[ReaderApi alloc] init];
        DataModel* dm = [[DataModel alloc] init];
        if ((dm == nil) || (api == nil)) {
            FLLogError(@"Initialization failed");
            return -1;
        }

        [api loginWithSavedCredentials];
        FLCommandLineClient* clc = [[FLCommandLineClient alloc] initWithArgc:argc argv:argv];
        [clc setDefaultBody:^(NSArray *args) {
            [dm setPollInterval:60.0f];
            printf("FleepReader initialized and waiting\n");
        }];
        [clc run];
    }
    return 0;
}

