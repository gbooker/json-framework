//
// Created by Graham Booker on 5/5/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>
#import "SBJsonStreamWriter.h"


@interface SBSmileStreamWriter : SBJsonStreamWriter
@property (nonatomic) BOOL writeHeader;
@property (nonatomic) BOOL shareKeys;
@property (nonatomic) BOOL shareStringValues;
@property (nonatomic) BOOL allowRawBinaryData;

- (BOOL)writeEnd;
@end