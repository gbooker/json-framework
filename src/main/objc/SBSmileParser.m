//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <SBJson/SBJsonStreamParserAccumulator.h>
#import "SBSmileParser.h"
#import "SBSmileStreamParser.h"
#import "SBSmileStreamParserAdapter.h"


@implementation SBSmileParser {

}

@synthesize maxDepth;
@synthesize error;

- (id)init {
    self = [super init];
    if (self)
        self.maxDepth = 32u;
    return self;
}


#pragma mark Methods

- (id)objectWithData:(NSData *)data {

    if (!data) {
        self.error = @"Input was 'nil'";
        return nil;
    }

    SBJsonStreamParserAccumulator *accumulator = [[SBJsonStreamParserAccumulator alloc] init];

    SBSmileStreamParserAdapter *adapter = [[SBSmileStreamParserAdapter alloc] init];
    adapter.delegate = accumulator;

    SBSmileStreamParser *parser = [[SBSmileStreamParser alloc] init];
    parser.maxDepth = self.maxDepth;
    parser.smileDelegate = adapter;

    switch ([parser parse:data]) {
        case SBJsonStreamParserComplete:
            return accumulator.value;
            break;

        case SBJsonStreamParserWaitingForData:
            self.error = @"Unexpected end of input";
            break;

        case SBJsonStreamParserError:
            self.error = parser.error;
            break;
    }

    return nil;
}

- (id)objectWithString:(NSString *)string {
    return [self objectWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}
@end