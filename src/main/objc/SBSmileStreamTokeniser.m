//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "SBSmileStreamTokeniser.h"


@implementation SBSmileStreamTokeniser {
    NSMutableData *_data;
    const unsigned char *_bytes;
    NSUInteger _index;
    NSUInteger _offset;
}

- (void)setError:(NSString *)error {
    _error = [NSString stringWithFormat:@"%@ at index %lu", error, (unsigned long)(_offset + _index)];
}

- (void)appendData:(NSData *)data {
    if (!_data) {
        _data = [data mutableCopy];

    } else if (_index) {
        // Discard data we've already parsed
        [_data replaceBytesInRange:NSMakeRange(0, _index) withBytes:"" length:0];
        [_data appendData:data];

        // Add to the offset for reporting
        _offset += _index;

        // Reset index to point to current position
        _index = 0u;

    }
    else {
        [_data appendData:data];
    }

    _bytes = [_data bytes];
}

- (BOOL)haveOneMoreCharacter {
    return [self haveRemainingCharacters:1];
}

- (BOOL)haveRemainingCharacters:(NSUInteger)length {
    return _data.length - _index >= length;
}

- (BOOL)getChar:(unsigned char *)ch {
    if ([self haveRemainingCharacters:1]) {
        *ch = _bytes[_index];
        return YES;
    }
    return NO;
}

- (sbsmile_token_t)findVint:(const unsigned char **)token length:(NSUInteger *)length max:(NSUInteger)max retval:(sbsmile_token_t)tok
{
    sbsmile_token_t result = [self findVint:token length:length max:max];
    if (result == sbsmile_token_integer_vint)
        return tok;
    return result;
}

- (sbsmile_token_t)findVint:(const unsigned char **)token length:(NSUInteger *)length max:(NSUInteger)max
{
    NSUInteger start = _index;
    NSUInteger len = 0;
    unsigned char ch;
    while (len < max && [self getChar:&ch]) {
        len++;
        _index++;
        if (ch & 0x80) {
            *token = _bytes + start;
            *length = len;
            return sbsmile_token_integer_vint;
        }
    }
    if (len == max) {
        self.error = [NSString stringWithFormat:@"Vint length exceeds max of %ld", max];
        return sbsmile_token_error;
    }
    _index = start;
    return sbsmile_token_eof;
}

- (sbsmile_token_t)decodeLength:(NSUInteger *)length token:(sbsmile_token_t)token;
{
    NSUInteger len = 0;
    unsigned char ch;
    NSUInteger value = 0;
    while (len < 10 && [self getChar:&ch]) {
        len++;
        _index++;
        if (ch & 0x80) {
            value = (value << 6) | (ch & 0x3F);
            *length = value;
            return token;
        }
        else {
            value = (value << 7) | ch;
        }
    }
    if (len == 10) {
        self.error = [NSString stringWithFormat:@"Vint for length exceeds length max of 10"];
        return sbsmile_token_error;
    }
    return sbsmile_token_eof;
}

- (sbsmile_token_t)findEndOfString:(const unsigned char **)token length:(NSUInteger *)length retval:(sbsmile_token_t)tok
{
    NSUInteger start = _index;
    unsigned char ch;
    while ([self getChar:&ch]) {
        _index++;
        if (ch == 0xFC) {
            *token = _bytes + start + 1;
            *length = _index - start - 2;
            return tok;
        }
    }
    _index = start;
    return sbsmile_token_eof;
}

- (sbsmile_token_t)getToken:(const unsigned char **)token length:(NSUInteger *)length key:(BOOL)keyMode {
    NSUInteger copyOfIndex = _index;

    unsigned char ch;
    if (![self getChar:&ch])
        return sbsmile_token_eof;

    sbsmile_token_t tok;
    if (!keyMode) {
        switch (ch >> 5) {
            case 0:
                //single byte shared string reference;
                tok = sbsmile_token_string_reference;
                *token = (_bytes + _index);
                *length = 1;
                _index++;
                break;
            case 1:
                switch (ch & 0x1F) {
                    case 0:
                        //0x20: empty string
                        tok = sbsmile_token_string_empty;
                        *token = (_bytes + _index);
                        *length = 1;
                        _index++;
                        break;
                    case 1:
                        //0x21: null
                        tok = sbsmile_token_null;
                        *token = (_bytes + _index);
                        *length = 1;
                        _index++;
                        break;
                    case 2:
                    case 3:
                        //0x22, 0x23: false, true
                        tok = ch & 0x1 ? sbsmile_token_bool_true : sbsmile_token_bool_false;
                        *token = (_bytes + _index);
                        *length = 1;
                        _index++;
                        break;
                    case 4:
                        //0x24: 32-bit number
                        _index++;
                        return [self findVint:token length:length max:5 retval:sbsmile_token_integer_32];
                    case 5: {
                        //0x25: 64-bit number
                        _index++;
                        sbsmile_token_t result = [self findVint:token length:length max:10 retval:sbsmile_token_integer_64];
                        if (result == sbsmile_token_integer_64 && *length < 5) {
                            self.error = [NSString stringWithFormat:@"64-bit integer used to express number of length %ld < 5", *length];
                            return sbsmile_token_error;
                        }
                        return result;
                    }
                    case 6: {
                        //0x26: BigInt
                        NSUInteger len;
                        tok = [self decodeLength:&len token:sbsmile_token_integer_big];
                        if (tok == sbsmile_token_integer_big) {
                            *token = (_bytes + _index);
                            *length = len;
                            _index += len;
                        }
                        break;
                    }
                    case 8: {
                        //0x28: 32-bit float
                        _index++;
                        if ([self haveRemainingCharacters:5]) {
                            tok = sbsmile_token_real_32;
                            *token = (_bytes + _index);
                            *length = 5;
                            _index += 5;
                        }
                        else
                            tok = sbsmile_token_eof;
                        break;
                    }
                    case 9: {
                        //0x29: 64-bit float
                        _index++;
                        if ([self haveRemainingCharacters:10]) {
                            tok = sbsmile_token_real_64;
                            *token = (_bytes + _index);
                            *length = 10;
                            _index += 10;
                        }
                        else
                            tok = sbsmile_token_eof;
                        break;
                    }
                    case 0xA: {
                        //0x2A: BigDecimal
                        _index++;
                        NSUInteger start = _index;
                        tok = [self findVint:token length:length max:5 retval:sbsmile_token_integer_32];
                        if (tok == sbsmile_token_integer_32) {
                            NSUInteger len;
                            tok = [self decodeLength:&len token:sbsmile_token_real_big];
                            if (tok == sbsmile_token_real_big) {
                                *token = (_bytes + start);
                                *length = _index - start;
                                _index += len;
                            }
                        }
                        break;
                    }
                    case 0x1A:
                        if ([self haveRemainingCharacters:4]) {
                            tok = sbsmile_token_header;
                            *token = (_bytes + _index);
                            *length = 4;
                            _index += 4;
                        }
                        else
                            tok = sbsmile_token_eof;
                        break;
                    default:
                        self.error = [NSString stringWithFormat:@"Invalid value token 0x%x", ch];
                        return sbsmile_token_error;
                }
                break;
            case 2:
            case 3: {
                //0x40-0x7F: tiny and small ascii
                NSUInteger len = (NSUInteger) (ch & 0x3F) + 1;
                if (![self haveRemainingCharacters:len])
                    return sbsmile_token_eof;
                tok = sbsmile_token_string_ascii;
                *token = (_bytes + _index + 1);
                *length = len;
                _index+= len + 1;
                break;
            }
            case 4:
            case 5: {
                //0x80-0xBF: tiny and small unicode
                NSUInteger len = (NSUInteger) (ch & 0x3F) + 2;
                if (![self haveRemainingCharacters:len])
                    return sbsmile_token_eof;
                tok = sbsmile_token_string_utf8;
                *token = (_bytes + _index + 1);
                *length = len;
                _index+= len + 1;
                break;
            }
            case 6:
                //0xC0-0xDF: small integers;
                tok = sbsmile_token_integer_small;
                *token = (_bytes + _index);
                *length = 1;
                _index++;
                break;
            case 7:
                switch (ch & 0x1F) {
                    case 0:
                        //0xE0: long variable length ascii
                        return [self findEndOfString:token length:length retval:sbsmile_token_string_v_ascii];
                    case 4:
                        //0xE4: long variable length ascii
                        return [self findEndOfString:token length:length retval:sbsmile_token_string_v_utf8];
                    case 8: {
                        //0xE8: 7-bit binary
                        _index++;
                        NSUInteger len;
                        tok = [self decodeLength:&len token:sbsmile_token_binary_escaped];
                        if (tok == sbsmile_token_binary_escaped) {
                            *token = (_bytes + _index);
                            *length = len;
                            _index += len;
                        }
                        break;
                    }
                    case 0xC:
                    case 0xD:
                    case 0xE:
                    case 0xF:
                        //0xEC-0xEF: shared string
                        tok = sbsmile_token_string_reference_long;
                        *token = (_bytes + _index);
                        *length = 2;
                        _index+= 2;
                        break;
                    case 0x18:
                        //0xF8: start array
                        tok = sbsmile_token_array_open;
                        _index++;
                        break;
                    case 0x19:
                        //0xF8: end array
                        tok = sbsmile_token_array_close;
                        _index++;
                        break;
                    case 0x1A:
                        //0xF8: start object
                        tok = sbsmile_token_object_open;
                        _index++;
                        break;
                    case 0x1D: {
                        //0xFD: raw binary
                        _index++;
                        NSUInteger len;
                        tok = [self decodeLength:&len token:sbsmile_token_binary_raw];
                        if (tok == sbsmile_token_binary_raw) {
                            *token = (_bytes + _index);
                            *length = len;
                            _index += len;
                        }
                        break;
                    }
                    default:
                        self.error = [NSString stringWithFormat:@"Invalid value token 0x%x", ch];
                        return sbsmile_token_error;
                }
                break;
            default:
                //should never happen
                self.error = [NSString stringWithFormat:@"Invalid value token 0x%x", ch];
                return sbsmile_token_error;
        }
    } else {
        //keymode
        switch (ch >> 6) {
            case 0:
                switch (ch & 0x3F) {
                    case 20:
                        //0x20: empty string
                        tok = sbsmile_token_string_empty;
                        *token = (_bytes + _index);
                        *length = 1;
                        _index++;
                        break;
                    case 0x30:
                    case 0x31:
                    case 0x32:
                    case 0x33: {
                        //0x30-0x33: long key reference
                        if (![self haveRemainingCharacters:2])
                            return sbsmile_token_eof;
                        tok = sbsmile_token_key_reference_long;
                        *token = (_bytes + _index);
                        *length = 2;
                        _index+= 2;
                        break;
                    }
                    case 0x34:
                        //0x34: unicode key
                        return [self findEndOfString:token length:length retval:sbsmile_token_key_long];
                    default:
                        self.error = [NSString stringWithFormat:@"Invalid key token 0x%x", ch];
                        return sbsmile_token_error;
                }
                break;
            case 1:
                //0x40-0x7F: short key reference
                tok = sbsmile_token_key_reference;
                *token = (_bytes + _index);
                *length = 1;
                _index++;
                break;
            case 2: {
                //0x80-0xBF: short ascii key
                NSUInteger len = (NSUInteger) (ch & 0x3F) + 1;
                if (![self haveRemainingCharacters:len])
                    return sbsmile_token_eof;
                tok = sbsmile_token_key_short_ascii;
                *token = (_bytes + _index + 1);
                *length = len;
                _index+= len + 1;
                break;
            }
            case 3:
                if (ch <= 0xF7) {
                    //0xC0-0xF7: short utf8 key
                    NSUInteger len = (NSUInteger) (ch & 0x3F) + 2;
                    if (![self haveRemainingCharacters:len])
                        return sbsmile_token_eof;
                    tok = sbsmile_token_key_short_utf8;
                    *token = (_bytes + _index + 1);
                    *length = len;
                    _index+= len + 1;
                    break;
                }
                else if (ch == 0xFB) {
                    //End Object
                    tok = sbsmile_token_object_close;
                    *token = (_bytes + _index);
                    *length = 1;
                    _index++;
                    break;
                }
                else {
                    self.error = [NSString stringWithFormat:@"Invalid key token 0x%x", ch];
                    return sbsmile_token_error;
                }
            default:
                //should never happen
                self.error = [NSString stringWithFormat:@"Invalid key token 0x%x", ch];
                return sbsmile_token_error;
        }
    }

    if (tok == sbsmile_token_eof) {
        // We ran out of bytes before we could finish parsing the current token.
        // Back up to the start & wait for more data.
        _index = copyOfIndex;
    }

    return tok;
}

@end