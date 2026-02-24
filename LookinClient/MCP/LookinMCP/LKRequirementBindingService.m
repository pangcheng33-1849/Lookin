//
//  LKRequirementCodeInfoService.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKRequirementBindingService.h"
#import "LKRequirementBindingStore.h"
#import "LKMCPError.h"
#import "LKMCPNotifications.h"
#define LKMCPCodeInfoServiceLog(fmt, ...) NSLog((@"[LookinMCP][CodeInfoService] " fmt), ##__VA_ARGS__)

NSString * const NotificationName_RequirementCodeInfoDidChange = @"NotificationName_RequirementCodeInfoDidChange";
NSString * const LKMCPRequirementCodeInfoChangedSessionIdKey = @"sessionId";
NSString * const LKMCPRequirementCodeInfoChangedOperationKey = @"operation";

@interface LKRequirementCodeInfoService ()

@property(nonatomic, strong) LKRequirementCodeInfoStore *store;

@end

@implementation LKRequirementCodeInfoService

- (instancetype)initWithStore:(LKRequirementCodeInfoStore *)store {
    self = [super init];
    if (self) {
        _store = store;
    }
    return self;
}

- (NSDictionary<NSString *,id> *)setRequirementItemsWithArguments:(NSDictionary<NSString *,id> *)arguments
                                                         sessionId:(NSString *)sessionId
                                                             error:(NSError *__autoreleasing  _Nullable *)error {
    // Validate operation contract first, then normalize payload for append/remove flow.
    NSString *operation = [arguments[@"operation"] isKindOfClass:[NSString class]] ? arguments[@"operation"] : nil;
    NSArray *items = [arguments[@"items"] isKindOfClass:[NSArray class]] ? arguments[@"items"] : nil;
    if ((operation.length == 0) || (items.count == 0)) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"Invalid arguments for lookin.set_requirement_items."
                                   recoverable:YES
                                          hint:@"operation must be append/remove and items must be non-empty."
                                     sessionId:sessionId];
        }
        LKMCPCodeInfoServiceLog(@"reject invalid set_requirement_items arguments, sessionId=%@", sessionId ?: @"");
        return nil;
    }
    if (![operation isEqualToString:@"append"] && ![operation isEqualToString:@"remove"]) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"Unsupported operation."
                                   recoverable:YES
                                          hint:@"Use operation=append or operation=remove."
                                     sessionId:sessionId];
        }
        LKMCPCodeInfoServiceLog(@"reject unsupported operation=%@", operation ?: @"");
        return nil;
    }

    NSMutableSet<NSString *> *seenInRequest = [NSMutableSet set];
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *normalized = [NSMutableArray array];
    for (id obj in items) {
        NSDictionary *item = [obj isKindOfClass:[NSDictionary class]] ? (NSDictionary *)obj : nil;
        NSString *rid = [item[@"requirementId"] isKindOfClass:[NSString class]] ? item[@"requirementId"] : nil;
        if (rid.length == 0) {
            if (error) {
                *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                           message:@"requirementId is required."
                                       recoverable:YES
                                              hint:@"Each item must include a non-empty requirementId."
                                         sessionId:sessionId];
            }
            return nil;
        }
        if ([seenInRequest containsObject:rid]) {
            if (error) {
                *error = [LKMCPError errorWithCode:LKMCPErrorCodeDuplicateRequirementID
                                           message:[NSString stringWithFormat:@"Duplicate requirementId detected: %@", rid]
                                       recoverable:YES
                                              hint:@"Ensure requirementId is unique in one request."
                                         sessionId:sessionId];
            }
            return nil;
        }
        [seenInRequest addObject:rid];

        NSString *desc = [item[@"description"] isKindOfClass:[NSString class]] ? item[@"description"] : @"";
        if ([operation isEqualToString:@"append"] && desc.length == 0) {
            if (error) {
                *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                           message:@"description is required for append."
                                       recoverable:YES
                                              hint:@"append items must include non-empty description."
                                         sessionId:sessionId];
            }
            return nil;
        }

        [normalized addObject:@{
            @"requirementId": rid,
            @"description": desc,
            @"codeInfo": @""
        }];
    }

    NSMutableArray<NSDictionary<NSString *, NSString *> *> *records = [[self.store recordsForSessionId:sessionId] mutableCopy];
    records = records ?: [NSMutableArray array];
    NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *index = [NSMutableDictionary dictionary];
    [records enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *obj, NSUInteger idx, BOOL *stop) {
        NSString *rid = obj[@"requirementId"];
        if (rid.length > 0) {
            index[rid] = obj;
        }
    }];

    if ([operation isEqualToString:@"append"]) {
        for (NSDictionary<NSString *, NSString *> *item in normalized) {
            NSString *rid = item[@"requirementId"];
            if (index[rid] != nil) {
                if (error) {
                    *error = [LKMCPError errorWithCode:LKMCPErrorCodeDuplicateRequirementID
                                               message:[NSString stringWithFormat:@"Duplicate requirementId detected: %@", rid]
                                           recoverable:YES
                                                  hint:@"Use unique requirementId or remove existing one first."
                                             sessionId:sessionId];
                }
                LKMCPCodeInfoServiceLog(@"append rejected duplicate requirementId=%@", rid ?: @"");
                return nil;
            }
        }
        [records addObjectsFromArray:normalized];
    } else {
        for (NSDictionary<NSString *, NSString *> *item in normalized) {
            NSString *rid = item[@"requirementId"];
            if (index[rid] == nil) {
                if (error) {
                    *error = [LKMCPError errorWithCode:LKMCPErrorCodeRequirementNotFound
                                               message:[NSString stringWithFormat:@"Requirement not found: %@", rid]
                                           recoverable:YES
                                                  hint:@"Call get_requirement_code_info and remove existing requirementId only."
                                             sessionId:sessionId];
                }
                LKMCPCodeInfoServiceLog(@"remove rejected missing requirementId=%@", rid ?: @"");
                return nil;
            }
        }
        NSMutableSet<NSString *> *toDelete = [NSMutableSet set];
        [normalized enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *obj, NSUInteger idx, BOOL *stop) {
            [toDelete addObject:obj[@"requirementId"]];
        }];
        [records filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary<NSString *, NSString *> *record, NSDictionary<NSString *,id> *_) {
            return ![toDelete containsObject:record[@"requirementId"]];
        }]];
    }

    [self.store saveRecords:records sessionId:sessionId];
    [[NSNotificationCenter defaultCenter] postNotificationName:NotificationName_RequirementCodeInfoDidChange
                                                        object:nil
                                                      userInfo:@{
        LKMCPRequirementCodeInfoChangedSessionIdKey: sessionId ?: @"",
        LKMCPRequirementCodeInfoChangedOperationKey: operation
    }];
    LKMCPCodeInfoServiceLog(@"set_requirement_items success, operation=%@, total=%@, sessionId=%@", operation, @(records.count), sessionId ?: @"");

    NSMutableArray<NSDictionary<NSString *, NSString *> *> *responseItems = [NSMutableArray array];
    [records enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *obj, NSUInteger idx, BOOL *stop) {
        [responseItems addObject:@{
            @"requirementId": obj[@"requirementId"] ?: @"",
            @"description": obj[@"description"] ?: @""
        }];
    }];
    return @{
        @"sessionId": sessionId,
        @"timestamp": [LKMCPError currentTimestampMs],
        @"operation": operation,
        @"total": @(records.count),
        @"items": responseItems
    };
}

- (NSDictionary<NSString *,id> *)getRequirementCodeInfoWithSessionId:(NSString *)sessionId
                                                                error:(NSError *__autoreleasing  _Nullable *)error {
    (void)error;
    // Keep output minimal and stable for MCP consumers.
    NSArray<NSDictionary<NSString *, NSString *> *> *records = [self.store recordsForSessionId:sessionId];
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *result = [NSMutableArray arrayWithCapacity:records.count];
    [records enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *obj, NSUInteger idx, BOOL *stop) {
        [result addObject:@{
            @"requirementId": obj[@"requirementId"] ?: @"",
            @"description": obj[@"description"] ?: @"",
            @"codeInfo": obj[@"codeInfo"] ?: @""
        }];
    }];
    return @{
        @"sessionId": sessionId,
        @"timestamp": [LKMCPError currentTimestampMs],
        @"records": result
    };
}

@end
