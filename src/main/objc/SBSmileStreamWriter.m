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

static NSNumber *kNotANumber;
static NSNumber *kTrue;
static NSNumber *kFalse;
static NSNumber *kPositiveInfinity;
static NSNumber *kNegativeInfinity;

@interface SBSmileStreamWriterSharedString : NSObject
@property (strong) NSString *value;
@property NSUInteger index;

+ (id)stringWithValue:(NSString *)value index:(NSUInteger)index;

- (id)initWithValue:(NSString *)value index:(NSUInteger)index;

@end

@implementation SBSmileStreamWriterSharedString

+ (id)stringWithValue:(NSString *)value index:(NSUInteger)index {
    return [[self alloc] initWithValue:value index:index];
}

- (id)initWithValue:(NSString *)value index:(NSUInteger)index {
    self = [super init];
    if (self) {
        self.value = value;
        self.index=index;
    }

    return self;
}

@end

@implementation SBSmileStreamWriter {
    BOOL _headerWritten;
    BOOL _binaryAllowed;
    NSMutableDictionary *_sharedStringValues;
    NSMutableArray *_sharedStringValueIndexes;
    NSUInteger _sharedStringValueIndex;
    NSMutableDictionary *_sharedStringKeys;
    NSMutableArray *_sharedStringKeyIndexes;
    NSUInteger _sharedStringKeyIndex;
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
        _sharedStringValueIndex = SMILE_MAX_SHARED_NAMES - 1;
        _sharedStringKeyIndex = SMILE_MAX_SHARED_NAMES - 1;
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
        _sharedStringKeys = [[NSMutableDictionary alloc] init];
        _sharedStringKeyIndexes = [[NSMutableArray alloc] init];
    }
    if (_shareStringValues) {
        header[3] |= SMILE_HEADER_BIT_HAS_SHARED_STRING_VALUES;
        _sharedStringValues = [[NSMutableDictionary alloc] init];
        _sharedStringValueIndexes = [[NSMutableArray alloc] init];
    }
    if (_allowRawBinaryData) {
        header[3] |= SMILE_HEADER_BIT_HAS_RAW_BINARY;
        _binaryAllowed = YES;
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
        SBSmileStreamWriterSharedString *shared = _sharedStringKeys[s];
        if (shared != nil) {
            NSUInteger index = shared.index;
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
            _sharedStringKeyIndex = (_sharedStringKeyIndex + 1) % SMILE_MAX_SHARED_NAMES;
            if (_sharedStringKeyIndexes.count > _sharedStringKeyIndex) {
                SBSmileStreamWriterSharedString *existing = _sharedStringKeyIndexes[_sharedStringKeyIndex];
                if (existing != nil)
                    _sharedStringKeys[existing.value] = nil;
            }
            SBSmileStreamWriterSharedString *newString = [SBSmileStreamWriterSharedString stringWithValue:s index:_sharedStringKeyIndex];
            _sharedStringKeys[s] = newString;
            if (_sharedStringKeyIndexes.count > _sharedStringKeyIndex)
                _sharedStringKeyIndexes[_sharedStringKeyIndex] = newString;
            else
                [_sharedStringKeyIndexes addObject:newString];
        }
    }
}

- (void)writeStringValue:(NSString *)s {
    if (s.length == 0) {
        char value = SMILE_TOKEN_LITERAL_STRING;
        [self writeDelegateBytes:&value length:1];
    }
    else {
        SBSmileStreamWriterSharedString *shared = _sharedStringValues[s];
        if (shared != nil) {
            NSUInteger index = shared.index;
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
                length = s.length;
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
                length = s.length;
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
            if (length < SMILE_MAX_SHARED_STRING_LENGTH_BYTES) {
                _sharedStringValueIndex = (_sharedStringValueIndex + 1) % SMILE_MAX_SHARED_NAMES;
                if (_sharedStringValueIndexes.count > _sharedStringValueIndex) {
                    SBSmileStreamWriterSharedString *existing = _sharedStringValueIndexes[_sharedStringValueIndex];
                    if (existing != nil)
                        _sharedStringValues[existing.value] = nil;
                }
                SBSmileStreamWriterSharedString *newString = [SBSmileStreamWriterSharedString stringWithValue:s index:_sharedStringValueIndex];
                _sharedStringValues[s] = newString;
                if (_sharedStringValueIndexes.count > _sharedStringValueIndex)
                    _sharedStringValueIndexes[_sharedStringValueIndex] = newString;
                else
                    [_sharedStringValueIndexes addObject:newString];
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
    char value = SMILE_TOKEN_PREFIX_SMALL_INT + (char)[SmileUtil zigzagEncode:(int)number];
    [self writeDelegateBytes:&value length:1];
}

- (void)write32BitInt:(int32_t)number {
    char values[] = {SMILE_TOKEN_PREFIX_INTEGER + SMILE_TOKEN_MISC_INTEGER_32, 0, 0, 0, 0, 0};
    int index = 1;
    uint32_t encoded = [SmileUtil zigzagEncode:number];
    if (encoded > 0x7FFFFFF) {
        values[index++] = (char)((encoded >> 27) & 0x7F);
    }
    if (encoded > 0xFFFFF) {
        values[index++] = (char)((encoded >> 20) & 0x7F);
    }
    if (encoded > 0x1FFF) {
        values[index++] = (char)((encoded >> 13) & 0x7F);
    }
    if (encoded > 0x3F) {
        values[index++] = (char)((encoded >> 6) & 0x7F);
    }
    values[index++] = (char)(encoded & 0x3F) | 0x80;
    [self writeDelegateBytes:values length:index];
}

- (void)write64BitInt:(int64_t)number {
    char values[] = {SMILE_TOKEN_PREFIX_INTEGER + SMILE_TOKEN_MISC_INTEGER_64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    int index = 1;
    uint64_t encoded = [SmileUtil zigzagEncodeLong:number];
    if (encoded > 0x3FFFFFFFFFFFFFFF) {
        values[index++] = (char)((encoded >> 62) & 0x7F);
    }
    if (encoded > 0x7FFFFFFFFFFFFF) {
        values[index++] = (char)((encoded >> 55) & 0x7F);
    }
    if (encoded > 0xFFFFFFFFFFFF) {
        values[index++] = (char)((encoded >> 48) & 0x7F);
    }
    if (encoded > 0x1FFFFFFFFFF) {
        values[index++] = (char)((encoded >> 41) & 0x7F);
    }
    if (encoded > 0x3FFFFFFFF) {
        values[index++] = (char)((encoded >> 34) & 0x7F);
    }
    values[index++] = (char)((encoded >> 27) & 0x7F);
    values[index++] = (char)((encoded >> 20) & 0x7F);
    values[index++] = (char)((encoded >> 13) & 0x7F);
    values[index++] = (char)((encoded >> 6) & 0x7F);
    values[index++] = (char)(encoded & 0x3F) | 0x80;
    [self writeDelegateBytes:values length:index];
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