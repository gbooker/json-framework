//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>


@interface SBSmileParser : NSObject
/**
 The maximum recursing depth.

 Defaults to 32. If the input is nested deeper than this the input will be deemed to be
 malicious and the parser returns nil, signalling an error. ("Nested too deep".) You can
 turn off this security feature by setting the maxDepth value to 0.
 */
@property NSUInteger maxDepth;

/**
 Description of parse error

 This method returns the trace of the last method that failed.
 You need to check the return value of the call you're making to figure out
 if the call actually failed, before you know call this method.

 @return A string describing the error encountered, or nil if no error occured.

 */
@property(copy) NSString *error;

/**
 Return the object represented by the given NSData object.

 The data *must* be UTF8 encoded.

 @param data An NSData containing UTF8 encoded data to parse.
 @return The NSArray or NSDictionary represented by the object, or nil if an error occured.

 */
- (id)objectWithData:(NSData*)data;

/**
 Parse string and return the represented dictionary or array.

 Calls objectWithData: internally.

 @param string An NSString containing JSON text.

 @return The NSArray or NSDictionary represented by the object, or nil if an error occured.
 */
- (id)objectWithString:(NSString *)string;
@end