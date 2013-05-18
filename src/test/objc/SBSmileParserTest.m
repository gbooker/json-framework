//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <SBJson/SBSmileConstants.h>
#import <SBJson/SBSmileWriter.h>
#import "SBSmileParser.h"

@interface SBSmileParserTest : SenTestCase
@end

@implementation SBSmileParserTest {

}

- (void)runTestWithData:(char *)data length:(NSUInteger)length equal:(id)object
{
    NSData *value = [NSData dataWithBytes:data length:length];
    SBSmileParser *parser = [[SBSmileParser alloc] init];
    id result = [parser objectWithData:value];
    STAssertEqualObjects(result, object, @"Failed to match object value");
}

- (void)testIntsMedium {
    char value1[] = {':', ')', '\n', 0, 0x24, 0x7, 0x80 + 0x3E};
    [self runTestWithData:value1 length:sizeof(value1) equal:@255];

    char value2[] = {':', ')', '\n', 0, 0x24, 0x1F, 0x80 + 0x0D};
    [self runTestWithData:value2 length:sizeof(value2) equal:@-999];

    char value3[] = {':', ')', '\n', 0, 0x24, 0x01, 0x6B, 0x3C, 0x68, 0x80 + 0x2A};
    [self runTestWithData:value3 length:sizeof(value3) equal:@123456789];
}

- (void)testMinMaxInts {
    char value1[] = {':', ')', '\n', 0, 0x24, 0x1F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3E};
    [self runTestWithData:value1 length:sizeof(value1) equal:@(INT_MAX)];

    char value2[] = {':', ')', '\n', 0, 0x24, 0x1F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3F};
    [self runTestWithData:value2 length:sizeof(value2) equal:@(INT_MIN)];
}

- (void)testBorderLongs {
    long l = (long)INT_MIN - 1L;
    char value1[] = {':', ')', '\n', 0, 0x25, 0x20, 0x00, 0x00, 0x00, 0x80 + 0x01};
    [self runTestWithData:value1 length:sizeof(value1) equal:@(l)];

    l = 1L + (long) INT_MAX;
    char value2[] = {':', ')', '\n', 0, 0x25, 0x20, 0x00, 0x00, 0x00, 0x80 + 0x00};
    [self runTestWithData:value2 length:sizeof(value2) equal:@(l)];
}

- (void)testLongs {
    int64_t l = LONG_MAX;
    char value1[] = {':', ')', '\n', 0, 0x25, 0x3, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3E};
    [self runTestWithData:value1 length:sizeof(value1) equal:@(l)];

    l = LONG_MIN;
    char value2[] = {':', ')', '\n', 0, 0x25, 0x3, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3F};
    [self runTestWithData:value2 length:sizeof(value2) equal:@(l)];
}

- (void)testArrayWithInts {
    char value1[] = {':', ')', '\n', 0, SMILE_TOKEN_LITERAL_START_ARRAY,
            SMILE_TOKEN_PREFIX_SMALL_INT + 2,
            SMILE_TOKEN_PREFIX_SMALL_INT,
            SMILE_TOKEN_PREFIX_SMALL_INT + 1,
            0x24, 0x7, 0x80 + 0x3E,
            0x24, 0x1F, 0x80 + 0x0D,
            0x24, 0x1F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3F,
            0x24, 0x1F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3E,
            0x25, 0x3, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3F,
            0x25, 0x3, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x80 + 0x3E,
            SMILE_TOKEN_LITERAL_END_ARRAY};
    NSArray *result = @[@1, @0, @-1, @255, @-999, @(INT_MIN), @(INT_MAX), @(LONG_MIN), @(LONG_MAX)];
    [self runTestWithData:value1 length:sizeof(value1) equal:result];
}


@end