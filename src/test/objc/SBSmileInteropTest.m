//
// Created by Graham Booker on 5/10/13.
// Copyright (c) 2013 Stig Brautaset. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <SBJson/SBSmileParser.h>
#import <SBJson/SBJsonParser.h>

@interface SBSmileInteropTest : SenTestCase
@end

@implementation SBSmileInteropTest {

}

- (NSString *)checkEqual:(NSDictionary *)obj1 object:(NSDictionary *)obj2 path:(NSString *)path
{
    NSSet *firstKeys = [NSSet setWithArray:obj1.allKeys];
    NSSet *secondKeys = [NSSet setWithArray:obj2.allKeys];

    if (![firstKeys isEqualToSet:secondKeys])
        return [NSString stringWithFormat:@"%@ Failed to keys %@ %@", path, firstKeys, secondKeys];
    NSString * __block result = nil;
    [obj1 enumerateKeysAndObjectsUsingBlock:^(id key, id value1, BOOL *stop) {
        id value2 = obj2[key];
        result = [self checkEqual:value1 to:value2 path:[path stringByAppendingPathComponent:key]];
        if (result != nil)
            *stop = YES;
    }];
    return result;
}

- (NSString *)checkEqual:(NSArray *)array1 array:(NSArray *)array2 path:(NSString *)path
{
    if (array1.count != array2.count)
        return [NSString stringWithFormat:@"%@ Failed to match array size %ld %ld", path, array1.count, array2.count];
    NSString * __block result = nil;
    [array1 enumerateObjectsUsingBlock:^(id value1, NSUInteger idx, BOOL *stop) {
        id value2 = array2[idx];
        result = [self checkEqual:value1 to:value2 path:[path stringByAppendingPathComponent:[@(idx) stringValue]]];
        if (result != nil)
            *stop = YES;
    }];
    return result;
}

- (NSString *)fail:(NSNumber *)num1 number:(NSNumber *)num2 path:(NSString *)path
{
    return [NSString stringWithFormat:@"%@ Failed to match number %@ %@", path, num1, num2];
}

- (BOOL)aboutEqual:(double)d1 to:(double)d2 {
    double epsilon = MAX(fabs(d1), fabs(d2))* 1E-14;
    return fabs(d1 - d2) <= epsilon;
}

- (NSString *)checkEqual:(NSNumber *)num1 number:(NSNumber *)num2 path:(NSString *)path
{
    if (num1 == [NSNumber numberWithBool:YES] || num1 == [NSNumber numberWithBool:NO]) {
        return [num1 boolValue] == [num2 boolValue] ? nil : [self fail:num1 number:num2 path:path];
    }
    const char *objcType = [num1 objCType];
    switch (objcType[0]) {
        case 'c': case 'i': case 's': case 'l': case 'q':
            return [num1 longLongValue] == [num2 longLongValue] ? nil : [self fail:num1 number:num2 path:path];
        case 'C': case 'I': case 'S': case 'L': case 'Q':
            return [num1 unsignedLongLongValue] == [num2 unsignedLongLongValue] ? nil : [self fail:num1 number:num2 path:path];
        case 'f': case 'd': default:
            return [self aboutEqual:[num1 doubleValue] to:[num2 doubleValue]] ? nil : [self fail:num1 number:num2 path:path];
    }
}

- (NSString *)checkEqual:(id)obj1 to:(id)obj2 path:(NSString *)path
{
    if ([obj1 isKindOfClass:[NSDictionary class]]) {
        if ([obj2 isKindOfClass:[NSDictionary class]])
            return [self checkEqual:obj1 object:obj2 path:path];
        else
            return [NSString stringWithFormat:@"Failed to match value type %@ %@", [obj1 class], [obj2 class]];
    }
    else if ([obj1 isKindOfClass:[NSArray class]]) {
        if ([obj2 isKindOfClass:[NSArray class]])
            return [self checkEqual:obj1 array:obj2 path:path];
        else
            return [NSString stringWithFormat:@"Failed to match value type %@ %@", [obj1 class], [obj2 class]];
    }
    else if ([obj1 isKindOfClass:[NSNumber class]]) {
        if ([obj2 isKindOfClass:[NSNumber class]])
            return [self checkEqual:obj1 number:obj2 path:path];
        else
            return [NSString stringWithFormat:@"Failed to match value type %@ %@", [obj1 class], [obj2 class]];
    }
    else if ([obj1 isKindOfClass:[NSString class]]) {
        if ([obj2 isKindOfClass:[NSString class]])
            return [(NSString *)obj1 isEqualToString:obj2] ? nil : [NSString stringWithFormat:@"%@ Failed to match string <%@><%@>", path, obj1, obj2];
        else
            return [NSString stringWithFormat:@"Failed to match value type %@ %@", [obj1 class], [obj2 class]];
    }
    else if ([obj1 isKindOfClass:[NSNull class]]) {
        if ([obj2 isKindOfClass:[NSNull class]])
            return nil;
        else
            return [NSString stringWithFormat:@"Failed to match value type %@ %@", [obj1 class], [obj2 class]];
    }
    return [NSString stringWithFormat:@"Unknown Type %@", [obj1 class]];
}

- (void)doCompare:(NSData *)smileData json:(NSData *)jsonData name:(NSString *)name
{
    SBSmileParser *smileParser = [[SBSmileParser alloc] init];
    id smileObj = [smileParser objectWithData:smileData];
    
    SBJsonParser *jsonParser = [[SBJsonParser alloc] init];
    id jsonObject = [jsonParser objectWithData:jsonData];

    NSString *error = [self checkEqual:smileObj to:jsonObject path:@""];
    STAssertNil(error, @"Failed to match data for %@: %@", name, error);
}

- (void)doDataDirCompare:(NSString *)name
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    
    NSString *smileFile = [bundle pathForResource:name ofType:@"smile"];
    NSData *smileData = [NSData dataWithContentsOfFile:smileFile];
    
    NSString *jsonFile = [bundle pathForResource:name ofType:@"jsn"];
    NSData *jsonData = [NSData dataWithContentsOfFile:jsonFile];
    
    [self doCompare:smileData json:jsonData name:name];
}

- (void)testDataDir
{
    for (NSString *name in @[
            @"db100.xml",
            @"json-org-sample1",
            @"json-org-sample2",
            @"json-org-sample3",
            @"json-org-sample4",
            @"json-org-sample5",
            @"map-spain.xml",
            @"ns-invoice100.xml",
            @"ns-soap.xml",
            @"numbers-fp-4k",
            @"numbers-fp-64k",
            @"numbers-int-4k",
            @"numbers-int-64k",
            @"test1",
            @"test2",
    ]) {
        [self doDataDirCompare:name];
    }
}
@end