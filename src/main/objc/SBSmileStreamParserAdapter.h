//
// Created by Graham Booker on 5/11/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>
#import <SBJson/SBJsonStreamParserAccumulator.h>
#import "SBSmileStreamParser.h"


@interface SBSmileStreamParserAdapter : SBJsonStreamParserAdapter <SBSmileStreamParserDelegate>
@end