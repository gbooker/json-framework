//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>
#import <SBJson/SBJsonStreamParser.h>

@class SBSmileStreamParserState;

@protocol SBSmileStreamParserDelegate <SBJsonStreamParserDelegate>
/// Called when a data value is found
- (void)parser:(SBJsonStreamParser*)parser foundData:(NSData *)data;
@end

@interface SBSmileStreamParser : SBJsonStreamParser
@property (nonatomic, weak) id<SBSmileStreamParserDelegate> smileDelegate;
@property (nonatomic, strong) SBSmileStreamParserState *smileState;
@end