//
// Created by Graham Booker on 5/5/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <SBJson/SBSmileWriter.h>
#import <SBJson/SBSmileConstants.h>
#import <SBJson/SmileUtil.h>

#define null [NSNull null]

@interface SBSmileGeneratorTest : SenTestCase

@end

@implementation SBSmileGeneratorTest {

}

- (void)verifyData:(NSData *)data withBytes:(const unsigned char *)bytes length:(NSUInteger)length
{
    STAssertEqualObjects(data, [NSData dataWithBytes:bytes length:length], @"Failed to match bytes");
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
    STAssertEquals(length, data.length, @"Failed to match length");
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
        return [writer dataWithObject:@[@YES, null, @NO]];
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
        return [writer dataWithObject:@{@"a": @8, @"b": @[@YES], @"c": @{}, @"d":@{@"3": null}}];
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

/**
 * Simple test to verify that second reference will not output new String, but
 * rather references one output earlier.
 */
- (void)testSharedNameSimple {
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        return [writer dataWithObject:@[@{@"abc": @1}, @{@"abc": @2}]];
    } length:13];
}

// same as above, but with name >= 64 characters
- (void)testSharedNameSimpleLong {
    NSString *digits = @"01234567899";

    // Base is 76 chars; loop over couple of shorter ones too

    NSString *LONG_NAME = [NSString stringWithFormat:@"a%@b%@c%@d%@e%@f%@ABCD", digits, digits, digits, digits, digits, digits];

    for (int i = 0; i < 4; ++i) {
        NSUInteger strLen = LONG_NAME.length - i;
        NSString *field = [LONG_NAME substringToIndex:strLen];
        [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
            writer.writeHeader = NO;
            return [writer dataWithObject:@[@{field: @1}, @{field: @2}]];
        } length:11 + field.length];

//        // better also parse it back...
//        JsonParser parser = _smileParser(result);
//        assertToken(JsonToken.START_ARRAY, parser.nextToken());
//
//        assertToken(JsonToken.START_OBJECT, parser.nextToken());
//        assertToken(JsonToken.FIELD_NAME, parser.nextToken());
//        assertEquals(field, parser.getCurrentName());
//        assertToken(JsonToken.VALUE_NUMBER_INT, parser.nextToken());
//        assertEquals(1, parser.getIntValue());
//        assertToken(JsonToken.END_OBJECT, parser.nextToken());
//
//        assertToken(JsonToken.START_OBJECT, parser.nextToken());
//        assertToken(JsonToken.FIELD_NAME, parser.nextToken());
//        assertEquals(field, parser.getCurrentName());
//        assertToken(JsonToken.VALUE_NUMBER_INT, parser.nextToken());
//        assertEquals(2, parser.getIntValue());
//        assertToken(JsonToken.END_OBJECT, parser.nextToken());
//
//        assertToken(JsonToken.END_ARRAY, parser.nextToken());
    }
}

// [Issue#8] Test by: M. Tarik Yurt  / mtyurt@gmail.com
- (void)testExpandSeenNames {
    id obj = @{@"a1" :null,@"a2" :null,@"a3" :null,@"a4" :null,@"a5" :null,@"a6" :null,@"a7" :null,@"a8" :null,@"a9" :null,@"a10":null,
               @"a11":null,@"a12":null,@"a13":null,@"a14":null,@"a15":null,@"a16":null,@"a17":null,@"a18":null,@"a19":null,@"a20":null,
               @"a21":null,@"a22":null,@"a23":null,@"a24":null,@"a25":null,@"a26":null,@"a27":null,@"a28":null,@"a29":null,@"a30":null,
               @"a31":null,@"a32":null,@"a33":null,@"a34":null,@"a35":null,@"a36":null,@"a37":null,@"a38":null,@"a39":null,@"a40":null,
               @"a41":null,@"a42":null,@"a43":null,@"a44":null,@"a45":null,@"a46":null,@"a47":null,@"a48":null,@"a49":null,@"a50":null,
               @"a51":null,@"a52":null,@"a53":null,@"a54":null,@"a55":null,@"a56":null,@"a57":null,@"a58":null,@"a59":null,@"a60":null,
               @"a61":null,@"a62":null,@"a63":null,@"a64":null,@"a65":@{@"a32":null}};
    /*
     * {@code "a54".hashCode() & 63} has same value as {@code "a32".hashCode() & 63}
     * "a32" is the next node of "a54" before expanding.
     * 33: Null token
     * -6: Start object token
     * -5: End object token
     */
    char expectedResult[] = {-6,-127,97,49,33,-127,97,50,33,-127,97,51,33,-127,97,52,33,-127,97,53,33,-127,97,54,33,-127,97,55,33,-127,97,56,33,-127,97,57,33,
            -126,97,49,48,33,-126,97,49,49,33,-126,97,49,50,33,-126,97,49,51,33,-126,97,49,52,33,-126,97,49,53,33,-126,97,49,54,33,-126,97,49,55,33,-126,97,49,56,33,
            -126,97,49,57,33,-126,97,50,48,33,-126,97,50,49,33,-126,97,50,50,33,-126,97,50,51,33,-126,97,50,52,33,-126,97,50,53,33,-126,97,50,54,33,-126,97,50,55,33,
            -126,97,50,56,33,-126,97,50,57,33,-126,97,51,48,33,-126,97,51,49,33,-126,97,51,50,33,-126,97,51,51,33,-126,97,51,52,33,-126,97,51,53,33,-126,97,51,54,33,
            -126,97,51,55,33,-126,97,51,56,33,-126,97,51,57,33,-126,97,52,48,33,-126,97,52,49,33,-126,97,52,50,33,-126,97,52,51,33,-126,97,52,52,33,-126,97,52,53,33,
            -126,97,52,54,33,-126,97,52,55,33,-126,97,52,56,33,-126,97,52,57,33,-126,97,53,48,33,-126,97,53,49,33,-126,97,53,50,33,-126,97,53,51,33,-126,97,53,52,33,
            -126,97,53,53,33,-126,97,53,54,33,-126,97,53,55,33,-126,97,53,56,33,-126,97,53,57,33,-126,97,54,48,33,-126,97,54,49,33,-126,97,54,50,33,-126,97,54,51,33,
            -126,97,54,52,33,
            // "a65":{"a32":null}} :
            -126,97,54,53,-6,95,33,-5,-5};
    /*
     * First "a32" is encoded as follows: -126,97,51,50
     * Second one should be referenced: 95
     */
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = NO;
        writer.sortKeys = YES;
        writer.sortKeysComparator = ^NSComparisonResult(NSString *s1, NSString *s2) {
            return [s1 compare:s2 options:NSNumericSearch];
        };
        return [writer dataWithObject:obj];
    } bytes:(unsigned char const *) expectedResult length:sizeof(expectedResult)];
}

// [Issue#8] Test by: M. Tarik Yurt  / mtyurt@gmail.com
- (void)testExpandSeenStringValues {
    id obj = @{
            @"a1": @"v1", @"a2": @"v2", @"a3": @"v3", @"a4": @"v4", @"a5": @"v5", @"a6": @"v6", @"a7": @"v7", @"a8": @"v8", @"a9": @"v9", @"a10":@"v10",
            @"a11":@"v11",@"a12":@"v12",@"a13":@"v13",@"a14":@"v14",@"a15":@"v15",@"a16":@"v16",@"a17":@"v17",@"a18":@"v18",@"a19":@"v19",@"a20":@"v20",
            @"a21":@"v21",@"a22":@"v22",@"a23":@"v23",@"a24":@"v24",@"a25":@"v25",@"a26":@"v26",@"a27":@"v27",@"a28":@"v28",@"a29":@"v29",@"a30":@"v30",
            @"a31":@"v31",@"a32":@"v32",@"a33":@"v33",@"a34":@"v34",@"a35":@"v35",@"a36":@"v36",@"a37":@"v37",@"a38":@"v38",@"a39":@"v39",@"a40":@"v40",
            @"a41":@"v41",@"a42":@"v42",@"a43":@"v43",@"a44":@"v44",@"a45":@"v45",@"a46":@"v46",@"a47":@"v47",@"a48":@"v48",@"a49":@"v49",@"a50":@"v50",
            @"a51":@"v51",@"a52":@"v52",@"a53":@"v53",@"a54":@"v54",@"a55":@"v55",@"a56":@"v56",@"a57":@"v57",@"a58":@"v58",@"a59":@"v59",@"a60":@"v60",
            @"a61":@"v61",@"a62":@"v62",@"a63":@"v63",@"a64":@"v64",@"a65":@"v65",@"a66":@"v30"};
    /*
     * {@code "v52".hashCode() & 63} has same value as {@code "v30".hashCode() & 63}
     * "v30" is next node of "v52" before expanding.
     */
    /*
     * -126,-127: Tiny key string token with length
     * 65,66: Tiny value string token with length
     * 97: 'a'
     * -6: Start object token
     * -5: End object token
     */
    char expectedResult[] = {58,41,10,3,-6,-127,97,49,65,118,49,-127,97,50,65,118,50,-127,97,51,65,118,51,-127,97,52,65,118,52,-127,97,53,65,118,53,-127,97,54,65,118,54,
            -127,97,55,65,118,55,-127,97,56,65,118,56,-127,97,57,65,118,57,-126,97,49,48,66,118,49,48,-126,97,49,49,66,118,49,49,-126,97,49,50,66,118,49,50,
            -126,97,49,51,66,118,49,51,-126,97,49,52,66,118,49,52,-126,97,49,53,66,118,49,53,-126,97,49,54,66,118,49,54,-126,97,49,55,66,118,49,55,
            -126,97,49,56,66,118,49,56,-126,97,49,57,66,118,49,57,-126,97,50,48,66,118,50,48,-126,97,50,49,66,118,50,49,-126,97,50,50,66,118,50,50,
            -126,97,50,51,66,118,50,51,-126,97,50,52,66,118,50,52,-126,97,50,53,66,118,50,53,-126,97,50,54,66,118,50,54,-126,97,50,55,66,118,50,55,
            -126,97,50,56,66,118,50,56,-126,97,50,57,66,118,50,57,-126,97,51,48,
            66,118,51,48,       //Here is first "v30"
            -126,97,51,49,66,118,51,49,-126,97,51,50,66,118,51,50,
            -126,97,51,51,66,118,51,51,-126,97,51,52,66,118,51,52,-126,97,51,53,66,118,51,53,-126,97,51,54,66,118,51,54,-126,97,51,55,66,118,51,55,
            -126,97,51,56,66,118,51,56,-126,97,51,57,66,118,51,57,-126,97,52,48,66,118,52,48,-126,97,52,49,66,118,52,49,-126,97,52,50,66,118,52,50,
            -126,97,52,51,66,118,52,51,-126,97,52,52,66,118,52,52,-126,97,52,53,66,118,52,53,-126,97,52,54,66,118,52,54,-126,97,52,55,66,118,52,55,
            -126,97,52,56,66,118,52,56,-126,97,52,57,66,118,52,57,-126,97,53,48,66,118,53,48,-126,97,53,49,66,118,53,49,-126,97,53,50,66,118,53,50,
            -126,97,53,51,66,118,53,51,-126,97,53,52,66,118,53,52,-126,97,53,53,66,118,53,53,-126,97,53,54,66,118,53,54,-126,97,53,55,66,118,53,55,
            -126,97,53,56,66,118,53,56,-126,97,53,57,66,118,53,57,-126,97,54,48,66,118,54,48,-126,97,54,49,66,118,54,49,-126,97,54,50,66,118,54,50,
            -126,97,54,51,66,118,54,51,-126,97,54,52,66,118,54,52,-126,97,54,53,66,118,54,53,-126,97,54,54,

            //The second "v30"
            // broken version would be:
            //"66,118,51,48," +
            // and correct one:
            30,
            -5};
    /* First "v30" is encoded as follows: 66,118,51,48
     * Second one should be referenced: 30
     * But in this example, because this part is not fixed, it's encoded again: 66,118,51,48
     */
    [self runTestWithBlock:^NSData *(SBSmileWriter *writer) {
        writer.writeHeader = YES;
        writer.sortKeys = YES;
        writer.sortKeysComparator = ^NSComparisonResult(NSString *s1, NSString *s2) {
            return [s1 compare:s2 options:NSNumericSearch];
        };
        writer.shareStringValues = YES;
        return [writer dataWithObject:obj];
    } bytes:(unsigned char const *) expectedResult length:sizeof(expectedResult)];
}

@end