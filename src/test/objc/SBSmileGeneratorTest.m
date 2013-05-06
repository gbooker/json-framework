//
// Created by Graham Booker on 5/5/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <SBJson/SBSmileWriter.h>
#import <SBJson/SBSmileConstants.h>
#import <SBJson/SmileUtil.h>

@interface SBSmileGeneratorTest : SenTestCase

@end

@implementation SBSmileGeneratorTest {

}

- (void)verifyData:(NSData *)data withBytes:(const unsigned char *)bytes length:(NSUInteger)length
{
    STAssertEqualObjects([NSData dataWithBytes:bytes length:length], data, @"Failed to match bytes");
}

- (void)runTestWithBlock:(NSData *(^)(SBSmileWriter *writer))block bytes:(const unsigned char *)bytes length:(NSUInteger)length
{
    SBSmileWriter *writer;

    writer = [[SBSmileWriter alloc] init];
    NSData *data = block(writer);
    [self verifyData:data withBytes:bytes length:length];
}

- (void)runTestWithBlock:(NSData *(^)(SBSmileWriter *writer))block length:(NSUInteger)length
{
    SBSmileWriter *writer;

    writer = [[SBSmileWriter alloc] init];
    NSData *data = block(writer);
    STAssertEquals(data.length, length, @"Failed to match length");
}

- (NSData *)writeRepeated:(SBSmileWriter *)writer string:(NSString *)value shared:(BOOL)shared
{
    writer.writeHeader = YES;
    writer.shareStringValues = shared;
    return [writer dataWithObject:@[value, value]];
}

- (void)testSimpleLiterals {
    unsigned char value1[] = {SMILE_TOKEN_LITERAL_TRUE};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithBoolean:YES];
    } bytes:value1 length:1];

    unsigned char value2[] = {SMILE_TOKEN_LITERAL_FALSE};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithBoolean:NO];
    } bytes:value2 length:1];

    unsigned char value3[] = {SMILE_TOKEN_LITERAL_NULL};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNull];
    } bytes:value3 length:1];

    unsigned char value4[] = {SMILE_HEADER_BYTE_1, SMILE_HEADER_BYTE_2, SMILE_HEADER_BYTE_3, SMILE_HEADER_BYTE_4 | SMILE_HEADER_BIT_HAS_SHARED_NAMES,
            SMILE_TOKEN_LITERAL_TRUE};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        return [writer dataWithBoolean:YES];
    } bytes:value4 length:5];

    unsigned char value5[] = {SMILE_HEADER_BYTE_1, SMILE_HEADER_BYTE_2, SMILE_HEADER_BYTE_3, SMILE_HEADER_BYTE_4 | SMILE_HEADER_BIT_HAS_SHARED_NAMES,
            SMILE_TOKEN_LITERAL_NULL, SMILE_MARKER_END_OF_CONTENT};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeEndMarker = YES;
        return [writer dataWithNull];
    } bytes:value5 length:6];
}

- (void)testSimpleArray {
    unsigned char value1[] = {SMILE_TOKEN_LITERAL_START_ARRAY, SMILE_TOKEN_LITERAL_END_ARRAY};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithObject:@[]];
    } bytes:value1 length:2];

    // then simple array with 3 literals
    unsigned char value2[] = {SMILE_TOKEN_LITERAL_START_ARRAY, SMILE_TOKEN_LITERAL_TRUE, SMILE_TOKEN_LITERAL_NULL, SMILE_TOKEN_LITERAL_FALSE, SMILE_TOKEN_LITERAL_END_ARRAY};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithObject:@[@YES, [NSNull null], @NO]];
    } bytes:value2 length:5];

    // and then array containing another array and short String
    // 4 bytes for start/end arrays; 3 bytes for short ascii string
    unsigned char value3[] = {SMILE_TOKEN_LITERAL_START_ARRAY, SMILE_TOKEN_LITERAL_START_ARRAY, SMILE_TOKEN_LITERAL_END_ARRAY, SMILE_TOKEN_PREFIX_TINY_ASCII + 1, '1', '2', SMILE_TOKEN_LITERAL_END_ARRAY};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithObject:@[@[], @"12"]];
    } bytes:value3 length:7];
}

- (void)testShortAscii {
    unsigned char value1[] = {0x42, 'a', 'b', 'c'};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithString:@"abc"];
    } bytes:value1 length:4];
}

- (void)testTrivialObject {
    unsigned char value1[] = {SMILE_TOKEN_LITERAL_START_OBJECT, 0x80, 'a', 0xC0 + (char)[SmileUtil zigzagEncode:6], SMILE_TOKEN_LITERAL_END_OBJECT};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithObject:@{@"a": @6}];
    } bytes:value1 length:5];
}

- (void)test2FieldObject {
    unsigned char value1[] = {SMILE_TOKEN_LITERAL_START_OBJECT,
            0x80, 'a', 0xC0 + (char)[SmileUtil zigzagEncode:1],
            0x80, 'b', 0xC0 + (char)[SmileUtil zigzagEncode:2],
            SMILE_TOKEN_LITERAL_END_OBJECT};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithObject:@{@"a": @1, @"b": @2}];
    } bytes:value1 length:sizeof(value1)];
}

- (void)testAnotherObject {
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithObject:@{@"a": @8, @"b": @[@YES], @"c": @{}, @"d":@{@"3": [NSNull null]}}];
    } length:21];
}

- (void)testSharedStrings {
    // first, no sharing, 2 separate Strings
    NSString *VALUE = @"abcde12345";
    NSUInteger SHARED_LEN = 18;
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        return [self writeRepeated:writer string:VALUE shared:YES];
    } length:SHARED_LEN];

    NSUInteger UNSHARED_LEN = 28;
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        return [self writeRepeated:writer string:VALUE shared:NO];
    } length:UNSHARED_LEN];
}

- (void)testSmallInt {
    unsigned char value1[] = {0xC0 + (3 << 1)};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@3];
    } bytes:value1 length:sizeof(value1)];

    unsigned char value2[] = {0xC0};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@0];
    } bytes:value2 length:sizeof(value2)];

    unsigned char value3[] = {0xC0 + (6 << 1) - 1};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@-6];
    } bytes:value3 length:sizeof(value3)];

    unsigned char value4[] = {0xC0 + (15 << 1)};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@15];
    } bytes:value4 length:sizeof(value4)];

    unsigned char value5[] = {0xC0 + (16 << 1) - 1};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@-16];
    } bytes:value5 length:sizeof(value5)];
}

- (void)testOtherInt {
    unsigned char value1[] = {0x24, 0x80 + (16 << 1)};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@16];
    } bytes:value1 length:sizeof(value1)];

    unsigned char value2[] = {0x24, 0x80 + (17 << 1) - 1};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@-17];
    } bytes:value2 length:sizeof(value2)];

    unsigned char value3[] = {0x24, 0x7F, 0x80 + 0x3E};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@0xFFF];
    } bytes:value3 length:sizeof(value3)];

    unsigned char value4[] = {0x24, 0x7F, 0x80 + 0x3F};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@-4096];
    } bytes:value4 length:sizeof(value4)];

    unsigned char value5[] = {0x24, 0x01, 0x00, 0x80};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@0x1000];
    } bytes:value5 length:sizeof(value5)];

    unsigned char value6[] = {0x24, /*0x7a120*/0x7A, 0x09, 0x80 + 0x00};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@500000];
    } bytes:value6 length:sizeof(value6)];

    unsigned char value7[] = {0x24, /*0x7FFFFFFF*/ 0x1F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3E};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@INT_MAX];
    } bytes:value7 length:sizeof(value7)];

    unsigned char value8[] = {0x24, 0x1F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3F};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@INT_MIN];
    } bytes:value8 length:sizeof(value8)];

    unsigned char value9[] = {0x25, 0x3, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3E};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@LONG_MAX];
    } bytes:value9 length:sizeof(value9)];

    unsigned char value10[] = {0x25, 0x3, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3F};
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@LONG_MIN];
    } bytes:value10 length:sizeof(value10)];
}

- (void)testFloats {
    // float length is fixed, 6 bytes
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@0.125f];
    } length:6];
}

- (void)testDoubles {
    // double length is fixed, 11 bytes
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithNumber:@0.125];
    } length:11];
}

@end