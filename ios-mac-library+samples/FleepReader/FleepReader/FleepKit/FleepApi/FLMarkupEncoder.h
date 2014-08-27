//
//  FLMarkupEncoder.h
//  Fleep
//
//  Created by Erik Laansoo on 24.01.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FLMarkupEncoder : NSObject

+ (NSString*)xmlWithMessage:(NSString*)message;
+ (NSData*)dataWithMessage:(NSString*)message;
+ (void)resetToDefaultSyntax;
- (id)initWithMessage:(NSString*)message;
- (NSString*)result;
- (NSData*)data;

@end
