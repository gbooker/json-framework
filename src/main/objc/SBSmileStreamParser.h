//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>
#import <SBJson/SBJsonStreamParser.h>

@class SBSmileStreamParserState;

@interface SBSmileStreamParser : SBJsonStreamParser
@property (nonatomic, strong) SBSmileStreamParserState *smileState;
@end