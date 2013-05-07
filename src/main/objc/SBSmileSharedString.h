//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>


@interface SBSmileSharedString : NSObject {
}


- (NSNumber *)indexForString:(NSString *)string;

- (NSString *)stringForIndex:(NSInteger)index1;

- (void)addString:(NSString *)string;
@end