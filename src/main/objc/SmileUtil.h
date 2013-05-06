//
// Created by Graham Booker on 5/5/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>


@interface SmileUtil : NSObject
+ (uint32_t)zigzagEncode:(int32_t)input;

+ (int32_t)zigzagDecode:(uint32)encoded;

+ (uint64_t)zigzagEncodeLong:(int64_t)input;

+ (int64_t)zigzagDecodeLong:(uint64_t)encoded;
@end