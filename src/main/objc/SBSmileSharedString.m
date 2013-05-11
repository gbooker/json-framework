//
// Created by Graham Booker on 5/6/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <SBJson/SBSmileConstants.h>
#import "SBSmileSharedString.h"


@interface SBSmileSharedStringContainer : NSObject
@property (strong) NSString *value;
@property NSUInteger index;

+ (id)stringWithValue:(NSString *)value index:(NSUInteger)index;

- (id)initWithValue:(NSString *)value index:(NSUInteger)index;

@end

@implementation SBSmileSharedStringContainer

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

@implementation SBSmileSharedString {
    NSMutableDictionary *_strings;
    NSMutableArray *_stringIndexes;
    NSUInteger _stringIndex;
}

- (id)init {
    self = [super init];
    if (self) {
        _stringIndex = 0;
        _strings = [[NSMutableDictionary alloc] init];
        _stringIndexes = [[NSMutableArray alloc] init];
    }

    return self;
}

- (NSNumber *)indexForString:(NSString *)string
{
    SBSmileSharedStringContainer *shared = _strings[string];
    if (shared != nil)
        return @(shared.index);
    return nil;
}

- (NSString *)stringForIndex:(NSInteger)index
{
    SBSmileSharedStringContainer *shared = _stringIndexes[index];
    return shared.value;
}

- (void)addString:(NSString *)string
{
    if (_stringIndex == SMILE_MAX_SHARED_NAMES) {
        [_strings removeAllObjects];
        [_stringIndexes removeAllObjects];
        _stringIndex = 0;
    }
    SBSmileSharedStringContainer *newString = [SBSmileSharedStringContainer stringWithValue:string index:_stringIndex];
    _strings[string] = newString;
    if (_stringIndexes.count > _stringIndex)
        _stringIndexes[_stringIndex] = newString;
    else
        [_stringIndexes addObject:newString];
    _stringIndex++;
}

@end