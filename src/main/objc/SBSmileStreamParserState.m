//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#if !__has_feature(objc_arc)
#error "This source file must be compiled with ARC enabled!"
#endif

#import "SBSmileStreamParserState.h"
#import "SBSmileStreamParser.h"

#define SINGLETON \
+ (id)sharedInstance { \
    static id state = nil; \
    if (!state) { \
        @synchronized(self) { \
            if (!state) state = [[self alloc] init]; \
        } \
    } \
    return state; \
}

@implementation SBSmileStreamParserState

+ (id)sharedInstance { return nil; }

- (BOOL)parser:(SBSmileStreamParser*)parser shouldAcceptToken:(sbsmile_token_t)token {
    return NO;
}

- (SBJsonStreamParserStatus)parserShouldReturn:(SBSmileStreamParser*)parser {
    return SBJsonStreamParserWaitingForData;
}

- (void)parser:(SBSmileStreamParser*)parser shouldTransitionTo:(sbsmile_token_t)tok {}

- (BOOL)keyMode {
    return NO;
}

- (NSString*)name {
    return @"<aaiie!>";
}

- (BOOL)isError {
    return NO;
}

@end

#pragma mark -

@implementation SBSmileStreamParserStateHeaderComplete

SINGLETON

- (BOOL)parser:(SBSmileStreamParser*)parser shouldAcceptToken:(sbsmile_token_t)token {
    return [[SBSmileStreamParserStateExpectingValue sharedInstance] parser:parser shouldAcceptToken:token];
}

- (void)parser:(SBSmileStreamParser*)parser shouldTransitionTo:(sbsmile_token_t)tok {

    SBSmileStreamParserState *state = nil;
    switch (tok) {
        case sbsmile_token_array_open:
            state = [SBSmileStreamParserStateArrayStart sharedInstance];
            break;

        case sbsmile_token_object_open:
            state = [SBSmileStreamParserStateObjectStart sharedInstance];
            break;

        case sbsmile_token_array_close:
        case sbsmile_token_object_close:
        case sbsmile_token_bool_true:
        case sbsmile_token_bool_false:
        case sbsmile_token_null:

        case sbsmile_token_integer_small:
        case sbsmile_token_integer_32:
        case sbsmile_token_integer_64:
        case sbsmile_token_integer_big:
        case sbsmile_token_integer_vint:
        case sbsmile_token_real_32:
        case sbsmile_token_real_64:

        case sbsmile_token_string_empty:
        case sbsmile_token_string_reference:
        case sbsmile_token_string_reference_long:
        case sbsmile_token_string_ascii:
        case sbsmile_token_string_utf8:
        case sbsmile_token_string_v_ascii:
        case sbsmile_token_string_v_utf8:

        case sbsmile_token_binary_escaped:
        case sbsmile_token_binary_raw:
            if (parser.supportMultipleDocuments)
                state = parser.smileState;
            else
                state = [SBSmileStreamParserStateComplete sharedInstance];
            break;

        case sbsmile_token_eof:
            return;

        default:
            state = [SBSmileStreamParserStateError sharedInstance];
            break;
    }


    parser.smileState = state;
}

- (NSString*)name { return @"before outer-most array or object"; }

@end

#pragma mark -

@implementation SBSmileStreamParserStateStart

SINGLETON

- (BOOL)parser:(SBSmileStreamParser *)parser shouldAcceptToken:(sbsmile_token_t)token {
    if (token == sbsmile_token_header)
        return true;
    return [super parser:parser shouldAcceptToken:token];
}

- (void)parser:(SBSmileStreamParser *)parser shouldTransitionTo:(sbsmile_token_t)tok {
    if (tok == sbsmile_token_header)
        parser.smileState = [SBSmileStreamParserStateHeaderComplete sharedInstance];
    else
        [super parser:parser shouldTransitionTo:tok];
}


@end

#pragma mark -

@implementation SBSmileStreamParserStateComplete

SINGLETON

- (NSString*)name { return @"after outer-most array or object"; }

- (SBJsonStreamParserStatus)parserShouldReturn:(SBSmileStreamParser*)parser {
    return SBJsonStreamParserComplete;
}

@end

#pragma mark -

@implementation SBSmileStreamParserStateError

SINGLETON

- (NSString*)name { return @"in error"; }

- (SBJsonStreamParserStatus)parserShouldReturn:(SBSmileStreamParser*)parser {
    return SBJsonStreamParserError;
}

- (BOOL)isError {
    return YES;
}

@end

#pragma mark -

@implementation SBSmileStreamParserStateExpectingValue

SINGLETON

- (BOOL)parser:(SBSmileStreamParser *)parser shouldAcceptToken:(sbsmile_token_t)token {
    switch (token) {
        case sbsmile_token_array_open:
        case sbsmile_token_array_close:

        case sbsmile_token_object_open:
        case sbsmile_token_object_close:

        case sbsmile_token_bool_true:
        case sbsmile_token_bool_false:
        case sbsmile_token_null:

        case sbsmile_token_integer_small:
        case sbsmile_token_integer_32:
        case sbsmile_token_integer_64:
        case sbsmile_token_integer_big:
        case sbsmile_token_integer_vint:
        case sbsmile_token_real_32:
        case sbsmile_token_real_64:

        case sbsmile_token_string_empty:
        case sbsmile_token_string_reference:
        case sbsmile_token_string_reference_long:
        case sbsmile_token_string_ascii:
        case sbsmile_token_string_utf8:
        case sbsmile_token_string_v_ascii:
        case sbsmile_token_string_v_utf8:

        case sbsmile_token_binary_escaped:
        case sbsmile_token_binary_raw:
            return YES;
        default:
            return NO;
    }
}


@end

@implementation SBSmileStreamParserStateObjectStart

SINGLETON

- (NSString*)name { return @"at beginning of object"; }

- (BOOL)parser:(SBSmileStreamParser*)parser shouldAcceptToken:(sbsmile_token_t)token {
    switch (token) {
        case sbsmile_token_object_close:
        case sbsmile_token_key_reference:
        case sbsmile_token_key_reference_long:
        case sbsmile_token_key_long:
        case sbsmile_token_key_short_ascii:
        case sbsmile_token_key_short_utf8:
            return YES;
            break;
        default:
            return NO;
            break;
    }
}

- (void)parser:(SBSmileStreamParser*)parser shouldTransitionTo:(sbsmile_token_t)tok {
    parser.smileState = [SBSmileStreamParserStateObjectGotKey sharedInstance];
}

- (BOOL)keyMode {
    return YES;
}

@end

#pragma mark -

@implementation SBSmileStreamParserStateObjectGotKey

SINGLETON

- (NSString*)name { return @"after object key"; }

- (void)parser:(SBSmileStreamParser*)parser shouldTransitionTo:(sbsmile_token_t)tok {
    parser.smileState = [SBSmileStreamParserStateObjectGotValue sharedInstance];
}

@end

#pragma mark -

@implementation SBSmileStreamParserStateObjectGotValue

SINGLETON

- (NSString*)name { return @"after object value"; }

- (BOOL)parser:(SBSmileStreamParser*)parser shouldAcceptToken:(sbsmile_token_t)token {
    if (token == sbsmile_token_object_close)
        return YES;
    return [super parser:parser shouldAcceptToken:token];
}

- (void)parser:(SBSmileStreamParser*)parser shouldTransitionTo:(sbsmile_token_t)tok {
    parser.smileState = [SBSmileStreamParserStateObjectGotKey sharedInstance];
}


@end

#pragma mark -

@implementation SBSmileStreamParserStateArrayStart

SINGLETON

- (NSString*)name { return @"at array start"; }

- (BOOL)parser:(SBSmileStreamParser*)parser shouldAcceptToken:(sbsmile_token_t)token {
    if (token == sbsmile_token_array_close)
        return YES;
    return [super parser:parser shouldAcceptToken:token];
}

- (void)parser:(SBSmileStreamParser*)parser shouldTransitionTo:(sbsmile_token_t)tok {
    parser.smileState = [SBSmileStreamParserStateArrayGotValue sharedInstance];
}

@end

#pragma mark -

@implementation SBSmileStreamParserStateArrayGotValue

SINGLETON

- (NSString*)name { return @"after array value"; }

@end
