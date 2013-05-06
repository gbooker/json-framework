//
// Created by Graham Booker on 5/5/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>


/**
 The Smile writer class.

 This uses SBSmileStreamWriter internally.

 */
@interface SBSmileWriter : NSObject
/**
 The maximum recursing depth.

 Defaults to 32. If the input is nested deeper than this the input will be deemed to be
 malicious and the parser returns nil, signalling an error. ("Nested too deep".) You can
 turn off this security feature by setting the maxDepth value to 0.
 */
@property NSUInteger maxDepth;

/**
 Return an error trace, or nil if there was no errors.

 Note that this method returns the trace of the last method that failed.
 You need to check the return value of the call you're making to figure out
 if the call actually failed, before you know call this method.
 */
@property (readonly, copy) NSString *error;

/**
 Whether or not to sort the dictionary keys in the output.

 If this is set to YES, the dictionary keys in the Smile output will be in sorted order.
 (This is useful if you need to compare two structures, for example.) The default is NO.
 */
@property BOOL sortKeys;

/**
 An optional comparator to be used if sortKeys is YES.

 If this is nil, sorting will be done via @selector(compare:).
 */
@property (copy) NSComparator sortKeysComparator;

@property BOOL writeHeader;
@property BOOL shareKeys;
@property BOOL shareStringValues;
@property BOOL allowRawBinaryData;
@property BOOL writeEndMarker;

/**
 Generates Smile representation for the given object.

 Returns an NSData object containing Smile represented as UTF8 text, or nil on error.

 @param value any instance that can be represented as Smile data.
 */
- (NSData*)dataWithObject:(id)value;

- (NSData *)dataWithBoolean:(BOOL)value;

- (NSData *)dataWithNull;

- (NSData *)dataWithString:(NSString *)string;

- (NSData *)dataWithNumber:(NSNumber *)number;
@end