//
// Created by Graham Booker on 5/5/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#if !__has_feature(objc_arc)
#error "This source file must be compiled with ARC enabled!"
#endif

#import "SBSmileStreamWriter.h"
#import "SBSmileWriter.h"
#import "SBJsonStreamWriterAccumulator.h"


@interface SBSmileWriter ()
@property (copy) NSString *error;
@end

@implementation SBSmileWriter

@synthesize sortKeys;
@synthesize error;
@synthesize maxDepth;
@synthesize writeHeader;
@synthesize allowRawBinaryData;

@synthesize sortKeysComparator;

- (id)init {
    self = [super init];
    if (self) {
        self.maxDepth = 32u;
        self.writeHeader = YES;
        self.shareKeys = YES;
    }
    return self;
}


- (NSString*)stringWithObject:(id)value {
    NSData *data = [self dataWithObject:value];
    if (data)
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return nil;
}

- (NSData*)dataWithBlock:(BOOL(^)(SBSmileStreamWriter *streamWriter))block {
    self.error = nil;

    SBJsonStreamWriterAccumulator *accumulator = [[SBJsonStreamWriterAccumulator alloc] init];

    SBSmileStreamWriter *streamWriter = [[SBSmileStreamWriter alloc] init];
    streamWriter.sortKeys = self.sortKeys;
    streamWriter.maxDepth = self.maxDepth;
    streamWriter.sortKeysComparator = self.sortKeysComparator;
    streamWriter.writeHeader = self.writeHeader;
    streamWriter.shareKeys = self.shareKeys;
    streamWriter.shareStringValues = self.shareStringValues;
    streamWriter.allowRawBinaryData = self.allowRawBinaryData;
    streamWriter.delegate = accumulator;

    BOOL ok = block(streamWriter);

    if (ok && _writeEndMarker)
        ok = [streamWriter writeEnd];

    if (ok)
        return accumulator.data;

    self.error = streamWriter.error;
    return nil;
}

static BOOL objectWrite(SBSmileWriter *self, id object, SBSmileStreamWriter *streamWriter) {
    if ([object isKindOfClass:[NSDictionary class]])
        return [streamWriter writeObject:object];

    else if ([object isKindOfClass:[NSArray class]])
        return [streamWriter writeArray:object];

    else if ([object isKindOfClass:[NSData class]])
        return [streamWriter writeData:object];

    else if ([object respondsToSelector:@selector(proxyForJson)])
        return objectWrite(self, [object proxyForJson], streamWriter);
    else {
        self.error = @"Not valid type for Smile";
        return NO;
    }
}

- (NSData*)dataWithObject:(id)object {

    return [self dataWithBlock:^BOOL(SBSmileStreamWriter *streamWriter) {
        return objectWrite(self, object, streamWriter);
    }];
}

- (NSData*)dataWithBoolean:(BOOL)value {
    return [self dataWithBlock:^BOOL(SBSmileStreamWriter *streamWriter) {
        return [streamWriter writeBool:value];
    }];
}

- (NSData*)dataWithNull {
    return [self dataWithBlock:^BOOL(SBSmileStreamWriter *streamWriter) {
        return [streamWriter writeNull];
    }];
}

- (NSData*)dataWithString:(NSString *)string {
    return [self dataWithBlock:^BOOL(SBSmileStreamWriter *streamWriter) {
        return [streamWriter writeString:string];
    }];
}

- (NSData *)dataWithNumber:(NSNumber *)number {
    return [self dataWithBlock:^BOOL(SBSmileStreamWriter *streamWriter) {
        return [streamWriter writeNumber:number];
    }];
}

@end