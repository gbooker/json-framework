//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <SBJson/SmileUtil.h>
#import <SBJson/SBSmileConstants.h>
#import "SBSmileStreamParser.h"
#import "SBSmileStreamTokeniser.h"
#import "SBSmileStreamParserState.h"
#import "SBSmileSharedString.h"


@implementation SBSmileStreamParser {
    SBSmileStreamTokeniser *_tokeniser;
    SBSmileSharedString *_sharedKeys;
    SBSmileSharedString *_sharedValues;
    BOOL _allowRawBinary;
}

#pragma mark Housekeeping

- (id)init {
    self = [super init];
    if (self) {
        _smileState = [SBSmileStreamParserStateStart sharedInstance];
        _tokeniser = [[SBSmileStreamTokeniser alloc] init];
        _sharedKeys = [[SBSmileSharedString alloc] init];
    }
    return self;
}

- (void)setSmileDelegate:(id <SBSmileStreamParserDelegate>)smileDelegate {
    _smileDelegate = smileDelegate;
    self.delegate = smileDelegate;
}

#pragma mark Methods

- (NSString*)tokenName:(sbsmile_token_t)token {
    switch (token) {
        case sbsmile_token_header:
            return @"header";

        case sbsmile_token_array_open:
            return @"start of array";

        case sbsmile_token_array_close:
            return @"end of array";

        case sbsmile_token_integer_small:
        case sbsmile_token_integer_32:
        case sbsmile_token_integer_64:
        case sbsmile_token_integer_big:
        case sbsmile_token_integer_vint:
        case sbsmile_token_real_32:
        case sbsmile_token_real_64:
        case sbsmile_token_real_big:
            return @"number";

        case sbsmile_token_string_empty:
        case sbsmile_token_string_reference:
        case sbsmile_token_string_reference_long:
        case sbsmile_token_string_ascii:
        case sbsmile_token_string_utf8:
        case sbsmile_token_string_v_ascii:
        case sbsmile_token_string_v_utf8:
            return @"string";

        case sbsmile_token_bool_true:
        case sbsmile_token_bool_false:
            return @"boolean";

        case sbsmile_token_null:
            return @"null";

        case sbsmile_token_object_open:
            return @"start of object";

        case sbsmile_token_object_close:
            return @"end of object";

        case sbsmile_token_binary_escaped:
        case sbsmile_token_binary_raw:
            return @"binary";

        case sbsmile_token_key_reference:
        case sbsmile_token_key_reference_long:
        case sbsmile_token_key_long:
        case sbsmile_token_key_short_ascii:
        case sbsmile_token_key_short_utf8:
            return @"key";

        case sbsmile_token_eof:
        case sbsmile_token_error:
            break;
    }
    NSAssert(NO, @"Should not get here");
    return @"<aaiiie!>";
}

- (void)maxDepthError {
    self.error = [NSString stringWithFormat:@"Input depth exceeds max depth of %lu", (unsigned long)self.maxDepth];
    self.smileState = [SBSmileStreamParserStateError sharedInstance];
}

- (void)handleHeader:(const unsigned char *)header
{
    if (memcmp(header, ":)\n", 3)) {
        self.error = [NSString stringWithFormat:@"Incorrect header start: %c%c%c", header[0], header[1], header[2]];
        self.smileState = [SBSmileStreamParserStateError sharedInstance];
        return;
    }

    unsigned char flags = header[3];
    if ((flags & 0xF0) != 0) {
        self.error = [NSString stringWithFormat:@"Incorrect version: %d", flags >> 4];
        self.smileState = [SBSmileStreamParserStateError sharedInstance];
        return;
    }

    if ((flags & SMILE_HEADER_BIT_HAS_RAW_BINARY) != 0)
        _allowRawBinary = YES;
    if ((flags & SMILE_HEADER_BIT_HAS_SHARED_STRING_VALUES) != 0)
        _sharedValues = [[SBSmileSharedString alloc] init];
    if ((flags & SMILE_HEADER_BIT_HAS_SHARED_NAMES) == 0)
        _sharedKeys = nil;
}

- (void)handleObjectStart {
    if (self.stateStack.count >= self.maxDepth) {
        [self maxDepthError];
        return;
    }

    [self.delegate parserFoundObjectStart:self];
    [self.stateStack addObject:_smileState];
    _smileState = [SBSmileStreamParserStateObjectStart sharedInstance];
}

- (void)handleObjectEnd: (sbsmile_token_t) tok  {
    _smileState = [self.stateStack lastObject];
    [self.stateStack removeLastObject];
    [_smileState parser:self shouldTransitionTo:tok];
    [self.delegate parserFoundObjectEnd:self];
}

- (void)handleArrayStart {
    if (self.stateStack.count >= self.maxDepth) {
        [self maxDepthError];
        return;
    }

    [self.delegate parserFoundArrayStart:self];
    [self.stateStack addObject:_smileState];
    _smileState = [SBSmileStreamParserStateArrayStart sharedInstance];
}

- (void)handleArrayEnd: (sbsmile_token_t) tok  {
    _smileState = [self.stateStack lastObject];
    [self.stateStack removeLastObject];
    [_smileState parser:self shouldTransitionTo:tok];
    [self.delegate parserFoundArrayEnd:self];
}

- (void) handleTokenNotExpectedHere: (sbsmile_token_t) tok  {
    NSString *tokenName = [self tokenName:tok];
    NSString *stateName = [_smileState name];

    self.error = [NSString stringWithFormat:@"Token '%@' not expected %@", tokenName, stateName];
    _smileState = [SBSmileStreamParserStateError sharedInstance];
}

- (SBJsonStreamParserStatus)parse:(NSData *)data_ {
    @autoreleasepool {
        [_tokeniser appendData:data_];

        for (;;) {

            if ([_smileState isError])
                return SBJsonStreamParserError;

            const unsigned char *token;
            NSUInteger token_len;
            sbsmile_token_t tok = [_tokeniser getToken:&token length:&token_len key:_smileState.keyMode];

            switch (tok) {
                case sbsmile_token_eof:
                    return [_smileState parserShouldReturn:self];

                case sbsmile_token_error:
                    _smileState = [SBSmileStreamParserStateError sharedInstance];
                    self.error = _tokeniser.error;
                    return SBJsonStreamParserError;

                default:

                    if (![_smileState parser:self shouldAcceptToken:tok]) {
                        [self handleTokenNotExpectedHere: tok];
                        return SBJsonStreamParserError;
                    }

                    switch (tok) {
                        case sbsmile_token_header:
                            [self handleHeader:token];
                            [_smileState parser:self shouldTransitionTo:tok];
                            break;
                        case sbsmile_token_object_open:
                            [self handleObjectStart];
                            break;

                        case sbsmile_token_object_close:
                            [self handleObjectEnd: tok];
                            break;

                        case sbsmile_token_array_open:
                            [self handleArrayStart];
                            break;

                        case sbsmile_token_array_close:
                            [self handleArrayEnd: tok];
                            break;

                        case sbsmile_token_bool_true:
                        case sbsmile_token_bool_false:
                            [self.delegate parser:self foundBoolean:tok == sbsmile_token_bool_true];
                            [_smileState parser:self shouldTransitionTo:tok];
                            break;

                        case sbsmile_token_null:
                            [self.delegate parserFoundNull:self];
                            [_smileState parser:self shouldTransitionTo:tok];
                            break;

                        case sbsmile_token_integer_small:
                        case sbsmile_token_integer_32:
                        case sbsmile_token_integer_64:
                        case sbsmile_token_integer_big: {
                            NSNumber *number = [self parseInt:token length:token_len type:tok];
                            [self.delegate parser:self foundNumber:number];
                            [_smileState parser:self shouldTransitionTo:tok];
                            break;
                        }

                        case sbsmile_token_real_32:
                        case sbsmile_token_real_64: {
                            NSNumber *number = [self parseFloat:token length:token_len type:tok];
                            [self.delegate parser:self foundNumber:number];
                            [_smileState parser:self shouldTransitionTo:tok];
                            break;
                        }

                        case sbsmile_token_real_big:
                            //TODO
                            //There is no native library that provides an equivalent of BigDecimal, so give up
                            @throw @"FUT FUT FUT";

                        case sbsmile_token_string_empty:
                            [self.delegate parser:self foundString:@""];
                            [_smileState parser:self shouldTransitionTo:tok];
                            break;

                        case sbsmile_token_string_reference:
                        case sbsmile_token_string_reference_long: {
                            int index;
                            if (tok == sbsmile_token_string_reference)
                                index = (token[0] & 0x1F) - 1;
                            else
                                index = ((token[0] & 0x3) << 8) | token[1];
                            [self.delegate parser:self foundString:[_sharedValues stringForIndex:index]];
                            [_smileState parser:self shouldTransitionTo:tok];
                            break;
                        }
                        case sbsmile_token_string_ascii:
                        case sbsmile_token_string_v_ascii:
                        case sbsmile_token_string_utf8:
                        case sbsmile_token_string_v_utf8: {
                            NSString *string;
                            if (tok == sbsmile_token_string_ascii || tok == sbsmile_token_string_v_ascii) {
                                string = [[NSString alloc] initWithBytes:token length:token_len encoding:NSASCIIStringEncoding];
                            }
                            else {
                                string = [[NSString alloc] initWithBytes:token length:token_len encoding:NSUTF8StringEncoding];
                            }
                            if (string == nil) {
                                self.error = @"Failed to decode string";
                                _smileState = [SBSmileStreamParserStateError sharedInstance];
                            }
                            else {
                                if (token_len <= SMILE_MAX_SHARED_STRING_LENGTH_BYTES)
                                    [_sharedValues addString:string];
                                [self.delegate parser:self foundString:string];
                                [_smileState parser:self shouldTransitionTo:tok];
                            }
                            break;
                        }
                        case sbsmile_token_key_reference:
                        case sbsmile_token_key_reference_long: {
                            int index;
                            if (tok == sbsmile_token_key_reference)
                                index = (token[0] & 0x3F);
                            else
                                index = ((token[0] & 0x3) << 8) | token[1];
                            [self.delegate parser:self foundObjectKey:[_sharedKeys stringForIndex:index]];
                            [_smileState parser:self shouldTransitionTo:tok];
                            break;
                        }
                        case sbsmile_token_key_short_ascii:
                        case sbsmile_token_key_short_utf8:
                        case sbsmile_token_key_long: {
                            NSString *string;
                            if (tok == sbsmile_token_key_short_ascii) {
                                string = [[NSString alloc] initWithBytes:token length:token_len encoding:NSASCIIStringEncoding];
                            }
                            else {
                                string = [[NSString alloc] initWithBytes:token length:token_len encoding:NSUTF8StringEncoding];
                            }
                            if (string == nil) {
                                self.error = @"Failed to decode string";
                                _smileState = [SBSmileStreamParserStateError sharedInstance];
                            }
                            else {
                                [_sharedKeys addString:string];
                                [self.delegate parser:self foundObjectKey:string];
                                [_smileState parser:self shouldTransitionTo:tok];
                            }
                            break;
                        }
                        case sbsmile_token_binary_escaped:
                        case sbsmile_token_binary_raw: {
                            NSData *data = [NSData dataWithBytes:token length:token_len];
                            if (tok == sbsmile_token_binary_escaped)
                                data = [self unescapeData:data];
                            [_smileDelegate parser:self foundData:data];
                            [_smileState parser:self shouldTransitionTo:tok];
                            break;
                        }
                        default:
                            break;
                    }
                    break;
            }
        }
        return SBJsonStreamParserComplete;
    }
}

- (NSNumber *)parseInt:(const unsigned char *)bytes length:(NSUInteger)length type:(sbsmile_token_t)type {
    switch (type) {
        case sbsmile_token_integer_small:
            return [NSNumber numberWithInt:[SmileUtil zigzagDecode:(uint32) (*bytes & 0x1F)]];
        case sbsmile_token_integer_32:
        case sbsmile_token_integer_64: {
            uint64_t encoded = 0;
            for (int i = 0; i < length - 1; i++) {
                encoded = (encoded << 7) | bytes[i];
            }
            encoded = (encoded << 6) | (bytes[length - 1] & 0x3F);
            int64_t value = [SmileUtil zigzagDecodeLong:encoded];
            if (value <= INT_MAX && value >= INT_MIN)
                return [NSNumber numberWithInt:(int) value];
            return [NSNumber numberWithLongLong:value];
        }
        case sbsmile_token_integer_big:
            //TODO
            //There is no native library that provides an equivalent of BigInteger, so give up
        default: @throw @"FUT FUT FUT";
    }
}

- (NSNumber *)parseFloat:(const unsigned char *)bytes length:(NSUInteger)length type:(sbsmile_token_t)type {
    if (type == sbsmile_token_real_32) {
        uint32_t encoded =
                        (((uint32_t)bytes[0] & 0x7F) << 28) |
                        (((uint32_t)bytes[1] & 0x7F) << 21) |
                        (((uint32_t)bytes[2] & 0x7F) << 14) |
                        (((uint32_t)bytes[3] & 0x7F) << 7) |
                        (((uint32_t)bytes[4] & 0x7F));
        float number;
        memcpy(&number, &encoded, 4);
        return [NSNumber numberWithFloat:number];
    } else {
        uint64_t encoded =
                        (((uint64_t)bytes[0] & 0x7F) << 63) |
                        (((uint64_t)bytes[1] & 0x7F) << 56) |
                        (((uint64_t)bytes[2] & 0x7F) << 49) |
                        (((uint64_t)bytes[3] & 0x7F) << 42) |
                        (((uint64_t)bytes[4] & 0x7F) << 35) |
                        (((uint64_t)bytes[5] & 0x7F) << 28) |
                        (((uint64_t)bytes[6] & 0x7F) << 21) |
                        (((uint64_t)bytes[7] & 0x7F) << 14) |
                        (((uint64_t)bytes[8] & 0x7F) << 7) |
                        (((uint64_t)bytes[9] & 0x7F));
        double number;
        memcpy(&number, &encoded, 8);
        return [NSNumber numberWithDouble:number];
    }
}

- (NSData *)unescapeData:(NSData *)escaped
{
    NSUInteger escapedLength = escaped.length;
    NSUInteger originalLength = (escapedLength * 7) / 8;

    unsigned char const *escapedDataBytes = escaped.bytes;
    NSMutableData *originalData = [[NSMutableData alloc] initWithLength:originalLength];
    unsigned char *originalDataBytes = originalData.mutableBytes;

    int originalIndex = 0;
    int escapedIndex;
    for (escapedIndex = 0; (long)escapedIndex < (long)escapedLength - 7; escapedIndex+=8) {
        unsigned char const *escapedSegment = escapedDataBytes + escapedIndex;
        unsigned char *originalSegment = originalDataBytes + originalIndex;

        originalSegment[0] = (escapedSegment[0] << 1) | ((escapedSegment[1] & 0x7F) >> 6);
        originalSegment[1] = (escapedSegment[1] << 2) | ((escapedSegment[2] & 0x7F) >> 5);
        originalSegment[2] = (escapedSegment[2] << 3) | ((escapedSegment[3] & 0x7F) >> 4);
        originalSegment[3] = (escapedSegment[3] << 4) | ((escapedSegment[4] & 0x7F) >> 3);
        originalSegment[4] = (escapedSegment[4] << 5) | ((escapedSegment[5] & 0x7F) >> 2);
        originalSegment[5] = (escapedSegment[5] << 6) | ((escapedSegment[6] & 0x7F) >> 1);
        originalSegment[6] = (escapedSegment[6] << 7) |  (escapedSegment[7] & 0x7F)      ;

        originalIndex += 7;
    }

    if (escapedIndex < escapedLength) {
        unsigned char const *escapedSegment = escapedDataBytes + escapedIndex;
        unsigned char *originalSegment = originalDataBytes + originalIndex;

        NSUInteger remaining = escapedLength - escapedIndex;

        unsigned char remainingBits = escapedSegment[0] & 0x7F;
        for (int i = 1; i < remaining; i++) {
            NSUInteger bytesLeft = remaining - i - 1;
            unsigned char nextBits = escapedSegment[i] & 0x7F;
            unsigned char value = (remainingBits << (7 - bytesLeft)) | nextBits >> (bytesLeft);
            originalSegment[i-1] = value;
            remainingBits = nextBits;
        }
    }
    return originalData;
}

@end