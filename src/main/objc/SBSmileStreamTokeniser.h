//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>

typedef enum {
    sbsmile_token_error = -1,
    sbsmile_token_eof,

    sbsmile_token_header,

    sbsmile_token_array_open,
    sbsmile_token_array_close,

    sbsmile_token_object_open,
    sbsmile_token_object_close,

    sbsmile_token_bool_true,
    sbsmile_token_bool_false,
    sbsmile_token_null,

    sbsmile_token_integer_small,
    sbsmile_token_integer_32,
    sbsmile_token_integer_64,
    sbsmile_token_integer_big,
    sbsmile_token_integer_vint,
    sbsmile_token_real_32,
    sbsmile_token_real_64,
    sbsmile_token_real_big,

    sbsmile_token_string_empty,
    sbsmile_token_string_reference,
    sbsmile_token_string_reference_long,
    sbsmile_token_string_ascii,
    sbsmile_token_string_utf8,
    sbsmile_token_string_v_ascii,
    sbsmile_token_string_v_utf8,

    sbsmile_token_binary_escaped,
    sbsmile_token_binary_raw,

    sbsmile_token_key_reference,
    sbsmile_token_key_reference_long,
    sbsmile_token_key_long,
    sbsmile_token_key_short_ascii,
    sbsmile_token_key_short_utf8,
} sbsmile_token_t;

@interface SBSmileStreamTokeniser : NSObject

@property (nonatomic, readonly, copy) NSString *error;

- (void)appendData:(NSData*)data_;

- (sbsmile_token_t)getToken:(const unsigned char **)tok length:(NSUInteger *)len key:(BOOL)keyMode;
@end