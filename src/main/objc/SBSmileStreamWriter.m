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

- (BOOL)writeValue:(id)v {
    if ([v isKindOfClass:[NSData class]])
        return [self writeData:(NSData *)v];
    return [super writeValue:v];
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

- (BOOL)writeData:(NSData *)data {
    if ([self.state isInvalidState:self]) return NO;
    if ([self.state expectingKey:self]) return NO;
    [self checkWriteHeader];

    if (_binaryAllowed)
        [self writeRawBinaryData:data];
    else
        [self write7BitBinaryData:data];

    [self.state transitionState:self];
    return YES;
}

- (void)writeRawBinaryData:(NSData *)data {
    unsigned char values[] = {SMILE_TOKEN_MISC_BINARY_RAW, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    NSUInteger length = data.length;
    NSUInteger index = 1;
    if (length <= UINT_MAX)
        index = [self writeVint:(uint32_t)length toArray:values offset:index];
    else
        index = [self write64Vint:length toArray:values offset:index];
    [self.delegate writer:self appendBytes:values length:index];
    [self.delegate writer:self appendBytes:data.bytes length:length];
}

- (void)write7BitBinaryData:(NSData *)data {
    NSUInteger length = data.length;
    NSUInteger encodedLength = ((length * 8) + 6) / 7;
    unsigned char values[] = {SMILE_TOKEN_MISC_BINARY_7BIT, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    NSUInteger index = 1;
    if (encodedLength <= UINT_MAX)
        index = [self writeVint:(uint32_t)encodedLength toArray:values offset:index];
    else
        index = [self write64Vint:encodedLength toArray:values offset:index];
    [self.delegate writer:self appendBytes:values length:index];

    NSUInteger originalIndex;
    unsigned char const *originalDataBytes = data.bytes;
    NSMutableData *encodedData = [[NSMutableData alloc] initWithLength:encodedLength];
    unsigned char *encodedDataBytes = encodedData.mutableBytes;
    NSUInteger encodedIndex = 0;
    for (originalIndex = 0; (long)originalIndex < (long)length - 6; originalIndex+=7) {
        unsigned char *encodedSegment = encodedDataBytes + encodedIndex;
        unsigned char const *originalSegment = originalDataBytes + originalIndex;

        encodedSegment[0] = (originalSegment[0]       ) >> 1;
        encodedSegment[1] = (originalSegment[0] & 0x01) << 6 | originalSegment[1] >> 2;
        encodedSegment[2] = (originalSegment[1] & 0x03) << 5 | originalSegment[2] >> 3;
        encodedSegment[3] = (originalSegment[2] & 0x07) << 4 | originalSegment[3] >> 4;
        encodedSegment[4] = (originalSegment[3] & 0x0F) << 3 | originalSegment[4] >> 5;
        encodedSegment[5] = (originalSegment[4] & 0x1F) << 2 | originalSegment[5] >> 6;
        encodedSegment[6] = (originalSegment[5] & 0x3F) << 1 | originalSegment[6] >> 7;
        encodedSegment[7] = (originalSegment[6] & 0x7F);

        encodedIndex += 8;
    }
    if (originalIndex < length) {
        unsigned char *encodedSegment = encodedDataBytes + encodedIndex;
        unsigned char const *originalSegment = originalDataBytes + originalIndex;

        NSUInteger remaining = length - originalIndex;
        uint64_t encoded = 0;

        /**
         *  Invariant: encoded always has bytes who's bits are of the form 0xxxxxxx, or the highest bit is always 0.
         *
         *  Start with encoded:                                                          xxxxxxxx 0abcdefg 0higjklm
         *  1) To add a byte, shift encoded by 9 bits and or new byte, which results in: abcdefg0 higjklm0 nopqrstu
         *  2) Mask off the highest order bit from each byte to get:                     a0000000 h0000000 n0000000
         *  3) Shift by 1 bit to the left:                                             a 0000000h 0000000n 00000000
         *  4) And 1 with complement of mask:                                          0 0bcdefg0 0igjklm0 0opqrstu
         *  5) Or last two together:                                                   a 0bcdefgh 0igjklmn 0opqrstu
         */
        uint64_t highOrderMask = 0x8080808080808080;
        for (int i = 0; i < remaining; i++) {
            uint64_t step1 = (encoded << 9) | originalSegment[i];
            uint64_t step3 = (step1 & highOrderMask) << 1;
            encoded = (step1 & ~highOrderMask) | step3;
        }
        NSUInteger remainingEncoded = encodedLength - encodedIndex;
        uint64_t writenBytes = NSSwapHostLongToBig(encoded);
        memcpy(encodedSegment, ((unsigned char *)&writenBytes) + 8 - remainingEncoded, remainingEncoded);
    }
    [self.delegate writer:self appendBytes:encodedDataBytes length:encodedLength];
}


@end