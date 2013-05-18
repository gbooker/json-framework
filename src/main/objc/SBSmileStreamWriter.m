//
// Created by Graham Booker on 5/5/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <SBJson/SmileUtil.h>
#import "SBSmileStreamWriter.h"
#import "SBJsonStreamWriterState.h"
#import "SBSmileConstants.h"
#import "SBSmileSharedString.h"

static NSNumber *kNotANumber;
static NSNumber *kTrue;
static NSNumber *kFalse;
static NSNumber *kPositiveInfinity;
static NSNumber *kNegativeInfinity;

@implementation SBSmileStreamWriter {
    BOOL _headerWritten;
    BOOL _binaryAllowed;
    SBSmileSharedString *_sharedValues;
    SBSmileSharedString *_sharedKeys;
}

+ (void)initialize {
    kNotANumber = [NSDecimalNumber notANumber];
    kPositiveInfinity = [NSNumber numberWithDouble:+HUGE_VAL];
    kNegativeInfinity = [NSNumber numberWithDouble:-HUGE_VAL];
    kTrue = [NSNumber numberWithBool:YES];
    kFalse = [NSNumber numberWithBool:NO];
}

- (id)init {
    self = [super init];
    if (self) {
        _writeHeader = YES;
        _shareKeys = YES;
    }

    return self;
}

- (void)writeDelegateBytes:(const void *)bytes length:(NSUInteger)length
{
    [self.delegate writer:self appendBytes:bytes length:length];
}

- (void)checkWriteHeader
{
    if(_headerWritten)
        return;

    char header[] = {SMILE_HEADER_BYTE_1, SMILE_HEADER_BYTE_2, SMILE_HEADER_BYTE_3, SMILE_HEADER_BYTE_4};
    if (_shareKeys) {
        header[3] |= SMILE_HEADER_BIT_HAS_SHARED_NAMES;
        _sharedKeys = [[SBSmileSharedString alloc] init];
    }
    if (_shareStringValues) {
        header[3] |= SMILE_HEADER_BIT_HAS_SHARED_STRING_VALUES;
        _sharedValues = [[SBSmileSharedString alloc] init];
        _writeHeader = YES;
    }
    if (_allowRawBinaryData) {
        header[3] |= SMILE_HEADER_BIT_HAS_RAW_BINARY;
        _binaryAllowed = YES;
        _writeHeader = YES;
    }
    if (_writeHeader)
        [self writeDelegateBytes:header length:4];
    _headerWritten = YES;
}

- (BOOL)writeBlock:(void (^)())block {
    if ([self.state isInvalidState:self]) return NO;
    if ([self.state expectingKey:self]) return NO;
    [self checkWriteHeader];

    block();
    [self.state transitionState:self];
    return YES;
}

- (BOOL)writeEnd {
    if (self.state != [SBJsonStreamWriterStateComplete sharedInstance]) return NO;
    char value = SMILE_MARKER_END_OF_CONTENT;
    [self writeDelegateBytes:&value length:1];
    return YES;
}

- (BOOL)writeBool:(BOOL)x {
    return [self writeBlock:^{
        char value = x ? SMILE_TOKEN_LITERAL_TRUE : SMILE_TOKEN_LITERAL_FALSE;
        [self writeDelegateBytes:&value length:1];
    }];
}

- (BOOL)writeNull {
    return [self writeBlock:^{
        char value = SMILE_TOKEN_LITERAL_NULL;
        [self writeDelegateBytes:&value length:1];
    }];
}

- (BOOL)writeString:(NSString *)s {
    if ([self.state isInvalidState:self]) return NO;

    if ([self.state expectingKey:self]) {
        [self writeStringKey:s];
    }
    else {
        [self writeStringValue:s];
    }

    [self.state transitionState:self];
    return YES;
}

- (void)writeStringKey:(NSString *)s {
    if (s.length == 0) {
        char value = SMILE_TOKEN_KEY_EMPTY_STRING;
        [self writeDelegateBytes:&value length:1];
    }
    else {
        NSNumber *indexNum = [_sharedKeys indexForString:s];
        if (indexNum != nil) {
            NSUInteger index = [indexNum unsignedIntegerValue];
            if (index <= SMILE_MAX_SHORT_SHARED_NAME_REFERENCE_NUMBER)
            {
                char value = (char)(SMILE_TOKEN_PREFIX_KEY_SHARED_SHORT + index);
                [self writeDelegateBytes:&value length:1];
            }
            else {
                char values[] = {(char)(SMILE_TOKEN_PREFIX_KEY_SHARED_LONG + index >> 8), (char)(index & 0xFF)};
                [self writeDelegateBytes:values length:2];
            }
        }
        else {
            NSUInteger length;
            if ([s canBeConvertedToEncoding:NSASCIIStringEncoding]) {
                NSData *data = [s dataUsingEncoding:NSASCIIStringEncoding];
                length = s.length;
                char value;
                if (length <= SMILE_MAX_SHORT_NAME_ASCII_BYTES) {
                    value = (char)(SMILE_TOKEN_PREFIX_KEY_ASCII + length - 1);
                }
                else {
                    value = SMILE_TOKEN_KEY_LONG_STRING;
                }
                [self writeDelegateBytes:&value length:1];
                [self writeDelegateBytes:data.bytes length:data.length];
                if (length > SMILE_MAX_SHORT_NAME_ASCII_BYTES) {
                    value = SMILE_MARKER_END_OF_STRING;
                    [self writeDelegateBytes:&value length:1];
                }
            }
            else {
                NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
                length = s.length;
                char value;
                if (length <= SMILE_MAX_SHORT_NAME_UNICODE_BYTES) {
                    value = (char)(SMILE_TOKEN_PREFIX_KEY_UNICODE + length - 2);
                }
                else {
                    value = SMILE_TOKEN_KEY_LONG_STRING;
                }
                [self writeDelegateBytes:&value length:1];
                [self writeDelegateBytes:data.bytes length:data.length];
                if (length > SMILE_MAX_SHORT_NAME_UNICODE_BYTES) {
                    value = SMILE_MARKER_END_OF_STRING;
                    [self writeDelegateBytes:&value length:1];
                }
            }
            [_sharedKeys addString:s];
        }
    }
}

- (void)writeStringValue:(NSString *)s {
    if (s.length == 0) {
        char value = SMILE_TOKEN_LITERAL_STRING;
        [self writeDelegateBytes:&value length:1];
    }
    else {
        NSNumber *indexNum = [_sharedValues indexForString:s];
        if (indexNum != nil) {
            NSUInteger index = [indexNum unsignedIntegerValue];
            if (index <= SMILE_MAX_SHORT_SHARED_VALUE_REFERENCE_NUMBER)
            {
                char value = (char)(SMILE_TOKEN_PREFIX_SHARED_STRING_SHORT + index + 1);
                [self writeDelegateBytes:&value length:1];
            }
            else {
                char values[] = {(char)(SMILE_TOKEN_PREFIX_SHARED_STRING_LONG + index >> 8), (char)(index & 0xFF)};
                [self writeDelegateBytes:values length:2];
            }
        }
        else {
            NSUInteger length;
            if ([s canBeConvertedToEncoding:NSASCIIStringEncoding]) {
                NSData *data = [s dataUsingEncoding:NSASCIIStringEncoding];
                length = data.length;
                char value;
                if (length <= SMILE_MAX_SHORT_VALUE_STRING_BYTES) {
                    value = (char)(SMILE_TOKEN_PREFIX_TINY_ASCII + length - 1);
                }
                else {
                    value = SMILE_TOKEN_MISC_LONG_TEXT_ASCII;
                }
                [self writeDelegateBytes:&value length:1];
                [self writeDelegateBytes:data.bytes length:data.length];
                if (length > SMILE_MAX_SHORT_VALUE_STRING_BYTES) {
                    value = SMILE_MARKER_END_OF_STRING;
                    [self writeDelegateBytes:&value length:1];
                }
            }
            else {
                NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
                length = data.length;
                char value;
                if (length <= SMILE_MAX_SHORT_VALUE_STRING_BYTES) {
                    value = (char)(SMILE_TOKEN_PREFIX_TINY_UNICODE + length - 2);
                }
                else {
                    value = SMILE_TOKEN_MISC_LONG_TEXT_UNICODE;
                }
                [self writeDelegateBytes:&value length:1];
                [self writeDelegateBytes:data.bytes length:data.length];
                if (length > SMILE_MAX_SHORT_VALUE_STRING_BYTES) {
                    value = SMILE_MARKER_END_OF_STRING;
                    [self writeDelegateBytes:&value length:1];
                }
            }
            if (length <= SMILE_MAX_SHARED_STRING_LENGTH_BYTES) {
                [_sharedValues addString:s];
            }
        }
    }
}

- (BOOL)writeNumber:(NSNumber *)number {
    if (number == kTrue || number == kFalse)
        return [self writeBool:[number boolValue]];

    if ([self.state isInvalidState:self]) return NO;
    if ([self.state expectingKey:self]) return NO;

    if ([kPositiveInfinity isEqualToNumber:number]) {
        self.error = @"+Infinity is not a valid number in JSON";
        return NO;

    } else if ([kNegativeInfinity isEqualToNumber:number]) {
        self.error = @"-Infinity is not a valid number in JSON";
        return NO;

    } else if ([kNotANumber isEqualToNumber:number]) {
        self.error = @"NaN is not a valid number in JSON";
        return NO;
    }

    const char *objcType = [number objCType];

    switch (objcType[0]) {
        case 'c': case 'i': case 's': case 'l': case 'q':
            [self writeLongLong:number];
            break;
        case 'C': case 'I': case 'S': case 'L': case 'Q':
            [self writeUnsignedLongLong:number];
            break;
        case 'f': case 'd': default:
            if ([number isKindOfClass:[NSDecimalNumber class]]) {
                //TODO
                char const *utf8 = [[number stringValue] UTF8String];
                [self writeDelegateBytes:utf8 length: strlen(utf8)];
                [self.state transitionState:self];
                return YES;
            }
            if (objcType[0] == 'f')
                [self writeFloat:[number floatValue]];
            else
                [self writeDouble:[number doubleValue]];
            break;
    }
    [self.state transitionState:self];
    return YES;
}

- (void)writeLongLong:(NSNumber *)number {
    long long value = [number longLongValue];
    if (value <= 15 && value >= -16) {
        [self writeShortInt:[number intValue]];
    }
    else if (value <= INT_MAX && value >= INT_MIN) {
        [self write32BitInt:(int32_t) value];
    }
    else {
        [self write64BitInt:(int64_t) value];
    }
}

- (void)writeUnsignedLongLong:(NSNumber *)number {
    unsigned long long value = [number unsignedLongLongValue];
    if (value <= 15) {
        [self writeShortInt:[number intValue]];
    }
    else if (value <= INT_MAX) {
        [self write32BitInt:(int32_t) value];
    }
    else if (value <= LONG_MAX) {
        [self write64BitInt:(int64_t) value];
    }
    else {
        //TODO BigInt
        ;
    }
}

- (void)writeShortInt:(int)number {
    char value = SMILE_TOKEN_PREFIX_SMALL_INT + (char)[SmileUtil zigzagEncode:number];
    [self writeDelegateBytes:&value length:1];
}

- (void)write32BitInt:(int32_t)number {
    unsigned char values[] = {SMILE_TOKEN_PREFIX_INTEGER + SMILE_TOKEN_MISC_INTEGER_32, 0, 0, 0, 0, 0};
    NSUInteger index = 1;
    uint32_t encoded = [SmileUtil zigzagEncode:number];
    index = [self writeVint:encoded toArray:values offset:index];
    [self writeDelegateBytes:values length:index];
}

- (void)write64BitInt:(int64_t)number {
    unsigned char values[] = {SMILE_TOKEN_PREFIX_INTEGER + SMILE_TOKEN_MISC_INTEGER_64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    NSUInteger index = 1;
    uint64_t encoded = [SmileUtil zigzagEncodeLong:number];
    index = [self write64Vint:encoded toArray:values offset:index];
    [self writeDelegateBytes:values length:index];
}

- (NSUInteger)writeVint:(uint32_t)value toArray:(unsigned char *)bytes offset:(NSUInteger)offset {
    if (value > 0x7FFFFFF) {
        bytes[offset++] = (unsigned char)((value >> 27) & 0x7F);
    }
    if (value > 0xFFFFF) {
        bytes[offset++] = (unsigned char)((value >> 20) & 0x7F);
    }
    if (value > 0x1FFF) {
        bytes[offset++] = (unsigned char)((value >> 13) & 0x7F);
    }
    if (value > 0x3F) {
        bytes[offset++] = (unsigned char)((value >> 6) & 0x7F);
    }
    bytes[offset++] = (unsigned char)(value & 0x3F) | 0x80;
    return offset;
}

- (NSUInteger)write64Vint:(uint64_t)value toArray:(unsigned char *)bytes offset:(NSUInteger)offset {
    if (value > 0x3FFFFFFFFFFFFFFF) {
        bytes[offset++] = (unsigned char)((value >> 62) & 0x7F);
    }
    if (value > 0x7FFFFFFFFFFFFF) {
        bytes[offset++] = (unsigned char)((value >> 55) & 0x7F);
    }
    if (value > 0xFFFFFFFFFFFF) {
        bytes[offset++] = (unsigned char)((value >> 48) & 0x7F);
    }
    if (value > 0x1FFFFFFFFFF) {
        bytes[offset++] = (unsigned char)((value >> 41) & 0x7F);
    }
    if (value > 0x3FFFFFFFF) {
        bytes[offset++] = (unsigned char)((value >> 34) & 0x7F);
    }
    bytes[offset++] = (unsigned char)((value >> 27) & 0x7F);
    bytes[offset++] = (unsigned char)((value >> 20) & 0x7F);
    bytes[offset++] = (unsigned char)((value >> 13) & 0x7F);
    bytes[offset++] = (unsigned char)((value >> 6) & 0x7F);
    bytes[offset++] = (unsigned char)(value & 0x3F) | 0x80;
    return offset;
}

- (void)writeFloat:(float)number {
    char values[] = {SMILE_TOKEN_PREFIX_FP + SMILE_TOKEN_MISC_FLOAT_32, 0, 0, 0, 0, 0};
    uint32_t encoded;
    memcpy(&encoded, &number, 4);
    values[1] = (char)((encoded >> 28) & 0x7F);
    values[2] = (char)((encoded >> 21) & 0x7F);
    values[3] = (char)((encoded >> 14) & 0x7F);
    values[4] = (char)((encoded >> 7) & 0x7F);
    values[5] = (char)(encoded & 0x7F);
    [self writeDelegateBytes:values length:6];
}

- (void)writeDouble:(double)number {
    char values[] = {SMILE_TOKEN_PREFIX_FP + SMILE_TOKEN_MISC_FLOAT_64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    uint64_t encoded;
    memcpy(&encoded, &number, 8);
    values[1] = (char)((encoded >> 63) & 0x7F);
    values[2] = (char)((encoded >> 56) & 0x7F);
    values[3] = (char)((encoded >> 49) & 0x7F);
    values[4] = (char)((encoded >> 42) & 0x7F);
    values[5] = (char)((encoded >> 35) & 0x7F);
    values[6] = (char)((encoded >> 28) & 0x7F);
    values[7] = (char)((encoded >> 21) & 0x7F);
    values[8] = (char)((encoded >> 14) & 0x7F);
    values[9] = (char)((encoded >> 7) & 0x7F);
    values[10] = (char)(encoded & 0x7F);
    [self writeDelegateBytes:values length:11];
}

- (BOOL)writeArrayOpen {
    if ([self.state isInvalidState:self]) return NO;
    if ([self.state expectingKey:self]) return NO;
    [self checkWriteHeader];

    [self.stateStack addObject:self.state];
    self.state = [SBJsonStreamWriterStateArrayStart sharedInstance];

    if (self.maxDepth && self.stateStack.count > self.maxDepth) {
        self.error = @"Nested too deep";
        return NO;
    }

    char value = SMILE_TOKEN_LITERAL_START_ARRAY;
    [self writeDelegateBytes:&value length:1];
    return YES;
}

- (BOOL)writeArrayClose {
    if ([self.state isInvalidState:self]) return NO;
    if ([self.state expectingKey:self]) return NO;

    self.state = [self.stateStack lastObject];
    [self.stateStack removeLastObject];

    char value = SMILE_TOKEN_LITERAL_END_ARRAY;
    [self writeDelegateBytes:&value length:1];

    [self.state transitionState:self];
    return YES;
}

- (BOOL)writeObjectOpen {
    if ([self.state isInvalidState:self]) return NO;
    if ([self.state expectingKey:self]) return NO;
    [self checkWriteHeader];

    [self.stateStack addObject:self.state];
    self.state = [SBJsonStreamWriterStateObjectStart sharedInstance];

    if (self.maxDepth && self.stateStack.count > self.maxDepth) {
        self.error = @"Nested too deep";
        return NO;
    }

    char value = SMILE_TOKEN_LITERAL_START_OBJECT;
    [self writeDelegateBytes:&value length:1];
    return YES;
}

- (BOOL)writeObjectClose {
    if ([self.state isInvalidState:self]) return NO;

    self.state = [self.stateStack lastObject];
    [self.stateStack removeLastObject];

    char value = SMILE_TOKEN_LITERAL_END_OBJECT;
    [self writeDelegateBytes:&value length:1];

    [self.state transitionState:self];
    return YES;
}


@end