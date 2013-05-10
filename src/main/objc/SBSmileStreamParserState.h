//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>
#import <SBJson/SBJsonStreamParser.h>
#import "SBSmileStreamTokeniser.h"

@class SBSmileStreamParser;


@interface SBSmileStreamParserState : NSObject
+ (id)sharedInstance;

- (BOOL)parser:(SBSmileStreamParser*)parser shouldAcceptToken:(sbsmile_token_t)token;
- (SBJsonStreamParserStatus)parserShouldReturn:(SBSmileStreamParser*)parser;
- (void)parser:(SBSmileStreamParser*)parser shouldTransitionTo:(sbsmile_token_t)tok;
- (BOOL)keyMode;
- (BOOL)isError;

- (NSString*)name;
@end

@interface SBSmileStreamParserStateExpectingValue : SBSmileStreamParserState
@end

@interface SBSmileStreamParserStateHeaderComplete: SBSmileStreamParserStateExpectingValue
@end

@interface SBSmileStreamParserStateStart : SBSmileStreamParserStateHeaderComplete
@end

@interface SBSmileStreamParserStateComplete : SBSmileStreamParserState
@end

@interface SBSmileStreamParserStateError : SBSmileStreamParserState
@end


@interface SBSmileStreamParserStateObjectStart : SBSmileStreamParserState
@end

@interface SBSmileStreamParserStateObjectGotKey : SBSmileStreamParserStateExpectingValue
@end

@interface SBSmileStreamParserStateObjectGotValue : SBSmileStreamParserStateObjectStart
@end

@interface SBSmileStreamParserStateArrayStart : SBSmileStreamParserStateExpectingValue
@end

@interface SBSmileStreamParserStateArrayGotValue : SBSmileStreamParserStateArrayStart
@end