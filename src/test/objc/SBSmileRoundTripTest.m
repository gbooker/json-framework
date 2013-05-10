//
// Created by Graham Booker on 5/8/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <SBJson/SBSmileWriter.h>
#import <SBJson/SBSmileParser.h>
#import "SBSmileRoundTripTest.h"


@implementation SBSmileRoundTripTest {

}

- (void)doRoundTrip:(id)object writeBlock:(NSData *(^)(SBSmileWriter *writer, id object))writeBlock verifyBlock:(void(^)(id object, NSData *data))verifyBlock {
    SBSmileWriter *writer;

    writer = [[SBSmileWriter alloc] init];
    NSData *data = writeBlock(writer, object);

    SBSmileParser *parser = [[SBSmileParser alloc] init];
    id result = [parser objectWithData:data];
    STAssertEqualObjects(result, object, @"Failed to match object");
    if (verifyBlock != nil)
        verifyBlock(object, data);
}

- (void)doRoundTrip:(id)object writeBlock:(NSData *(^)(SBSmileWriter *writer, id object))writeBlock {
    [self doRoundTrip:object writeBlock:writeBlock verifyBlock:nil];
}

- (void)doObjectRoundTrip:(id)object writeBlock:(void(^)(SBSmileWriter *writer, id object))writeBlock verifyBlock:(void(^)(id object, NSData *data))verifyBlock {
    [self doRoundTrip:object writeBlock:^NSData *(SBSmileWriter *writer, id object) {
        if (writeBlock != nil)
            writeBlock(writer, object);
        return [writer dataWithObject:object];
    } verifyBlock:verifyBlock];
}

- (void)doObjectRoundTrip:(id)object writeBlock:(void(^)(SBSmileWriter *writer, id object))writeBlock {
    [self doObjectRoundTrip:object writeBlock:writeBlock verifyBlock:nil];
}

- (void)testFloats {
    [self doRoundTrip:@0.37f writeBlock:^NSData *(SBSmileWriter *writer, NSNumber *number) {
        return [writer dataWithNumber:number];
    }];
}

- (void)testDoubles {
    [self doRoundTrip:@-12.0986 writeBlock:^NSData *(SBSmileWriter *writer, NSNumber *number) {
        return [writer dataWithNumber:number];
    }];
}

- (void)testArrayWithDoubles {
    [self doObjectRoundTrip:@[@0.1f, @0.333] writeBlock:nil];
}

- (void)testObjectWithDoubles {
    [self doObjectRoundTrip:@{@"x" : @0.5, @"y" : @0.01338} writeBlock:nil];
}

- (void)testLongNames {
    [self doTestWithName:[self generateName:5000]];
}

- (void)testBinForLargeObjects {
    NSMutableString *name = [[NSMutableString alloc] initWithString:@"longString"];
    int minLength = 9000;
    for (int i = 1; name.length < minLength; ++i) {
        [name appendFormat:@".%d", i];
    }
    [self doTestWithName:name];
}

- (void )doTestWithName:(NSString *)name {
    [self doObjectRoundTrip:@{name : @13} writeBlock:nil];
}

- (NSString *)generateName:(int)minLen
{
    NSMutableString *string = [[NSMutableString alloc] init];
    while (string.length < minLen){
        int ch = arc4random_uniform(96);
        unichar append;
        if (ch < 32) { // ascii (single byte)
            append = (unichar) (48 + ch);
        } else if (ch < 64) { // 2 byte
            append = (unichar) (128 + ch);
        } else { // 3 byte
            append = (unichar) (4000 + ch);
        }
        [string appendFormat:@"%C", append];
    }
    return string;
}

/**
 * Simple test to verify that second reference will not output new String, but
 * rather references one output earlier with longer strings.
 */
- (void)testSharedNameSimpleLong {
    NSString *digits = @"01234567899";

    // Base is 76 chars; loop over couple of shorter ones too

    NSString *LONG_NAME = [NSString stringWithFormat:@"a%@b%@c%@d%@e%@f%@ABCD", digits, digits, digits, digits, digits, digits];

    for (int i = 0; i < 4; ++i) {
        NSUInteger strLen = LONG_NAME.length - i;
        NSString *field = [LONG_NAME substringToIndex:strLen];
        [self doObjectRoundTrip:@[@{field: @1}, @{field: @2}] writeBlock:^(SBSmileWriter *writer, id object) {
            writer.writeHeader = NO;
        } verifyBlock:^(id object, NSData *data) {
            STAssertEquals(data.length, 11 + field.length, @"Failed to match shared long string length");
        }];
    }
}

- (void)testLongNamesNonShared {
    [self doTestLongNames:NO];
}

- (void)testLongNamesShared {
    [self doTestLongNames:YES];
}

// For issue [JACKSON-552]
- (void)doTestLongNames:(BOOL)shareNames {
    // 68 bytes long (on boundary)
    NSString *FIELD_NAME = @"dossier.domaine.supportsDeclaratifsForES.SupportDeclaratif.reference";
    NSString *VALUE = @"11111";

    [self doObjectRoundTrip:@{@"query":@{FIELD_NAME:VALUE}} writeBlock:^(SBSmileWriter *writer, id object) {
        writer.shareKeys = shareNames;
    }];
}


@end