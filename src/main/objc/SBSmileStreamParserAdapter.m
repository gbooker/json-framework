//
// Created by Graham Booker on 5/11/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "SBSmileStreamParserAdapter.h"


@interface SBJsonStreamParserAdapter ()

- (void)parser:(SBJsonStreamParser*)parser found:(id)obj;

@end

@implementation SBSmileStreamParserAdapter {

}

- (void)parser:(SBJsonStreamParser *)parser foundData:(NSData *)data {
    [self parser:parser found:data];
}

@end