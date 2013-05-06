//
// Created by Graham Booker on 5/5/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "SmileUtil.h"


@implementation SmileUtil {

}

+ (uint32_t)zigzagEncode:(int32_t)input {
    // Canonical version:
    //return (input << 1) ^  (input >> 31);
    // but this is even better
    if (input < 0) {
        return (uint32_t)(input << 1) ^ -1;
    }
    return (uint32_t)(input << 1);
}

+ (int32_t)zigzagDecode:(uint32)encoded {
    // canonical:
    //return (encoded >> 1) ^ (-(encoded & 1));
    if ((encoded & 1) == 0) { // positive
        return (encoded >> 1);
    }
    // negative
    return (encoded >> 1) ^ -1;
}

+ (uint64)zigzagEncodeLong:(int64_t)input {
    // Canonical version
    //return (input << 1) ^  (input >> 63);
    if (input < 0L) {
        return (uint64) ((input << 1) ^ -1L);
    }
    return (uint64) (input << 1);
}

+ (int64_t)zigzagDecodeLong:(uint64)encoded {
    // canonical:
    //return (encoded >>> 1) ^ (-(encoded & 1));
    if ((encoded & 1) == 0) { // positive
        return (long)(encoded >> 1);
    }
    // negative
    return (encoded >> 1) ^ -1L;
}

@end