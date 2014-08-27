//
//  FLFileDownloader.h
//  Fleep
//
//  Created by Erik Laansoo on 23.05.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLFileDownloader.h"
#import "FLDataModel.h"

@interface FLMessageFileDownloader : FLFileDownloader
@property (nonatomic, readonly) NSString* messageId;

- (id)initWithMessage:(Message*)message;

@end
