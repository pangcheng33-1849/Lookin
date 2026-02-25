//
//  LKRequirementCodeInfoStore.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKRequirementBindingStore.h"
#import "LKMCPError.h"
#import "LKMCPRequirementCodeInfoBoardController.h"
#define LKMCPCodeInfoStoreLog(fmt, ...) NSLog((@"[LookinMCP][CodeInfoStore] " fmt), ##__VA_ARGS__)

static NSString * const LKMCPCodeInfoPersistencePrefix = @"mcp_requirement_code_info_";
static NSString * const LKMCPCodeInfoPayloadSavedAtKey = @"savedAtMs";
static NSString * const LKMCPCodeInfoPayloadRecordsKey = @"records";
static NSString * const LKMCPCodeInfoForceMemoryOnlyDefaultsKey = @"mcp_code_info_force_memory_only";

static NSString * const LKMCPCodeInfoFieldRequirementId = @"requirementId";
static NSString * const LKMCPCodeInfoFieldDescription = @"description";
static NSString * const LKMCPCodeInfoFieldCodeInfo = @"codeInfo";

@implementation LKRequirementCodeInfoRecord

- (instancetype)initWithRequirementId:(NSString *)requirementId
                      itemDescription:(NSString *)itemDescription
                             codeInfo:(NSString *)codeInfo {
    self = [super init];
    if (self) {
        _requirementId = [requirementId copy] ?: @"";
        _itemDescription = [itemDescription copy] ?: @"";
        _codeInfo = [codeInfo copy] ?: @"";
    }
    return self;
}

+ (instancetype)recordFromDictionary:(NSDictionary<NSString *,NSString *> *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSString *rid = [([dictionary[LKMCPCodeInfoFieldRequirementId] isKindOfClass:[NSString class]] ? dictionary[LKMCPCodeInfoFieldRequirementId] : @"") copy];
    if (rid.length == 0) {
        return nil;
    }
    NSString *desc = [([dictionary[LKMCPCodeInfoFieldDescription] isKindOfClass:[NSString class]] ? dictionary[LKMCPCodeInfoFieldDescription] : @"") copy];
    NSString *codeInfo = [([dictionary[LKMCPCodeInfoFieldCodeInfo] isKindOfClass:[NSString class]] ? dictionary[LKMCPCodeInfoFieldCodeInfo] : @"") copy];
    return [[self alloc] initWithRequirementId:rid itemDescription:desc codeInfo:codeInfo];
}

- (NSDictionary<NSString *,NSString *> *)dictionaryRepresentation {
    return @{
        LKMCPCodeInfoFieldRequirementId: self.requirementId ?: @"",
        LKMCPCodeInfoFieldDescription: self.itemDescription ?: @"",
        LKMCPCodeInfoFieldCodeInfo: self.codeInfo ?: @""
    };
}

- (id)copyWithZone:(NSZone *)zone {
    return [[LKRequirementCodeInfoRecord allocWithZone:zone] initWithRequirementId:self.requirementId
                                                                    itemDescription:self.itemDescription
                                                                           codeInfo:self.codeInfo];
}

@end

@interface LKRequirementCodeInfoStore ()

@property(nonatomic, strong) NSMutableDictionary<NSString *, NSArray<LKRequirementCodeInfoRecord *> *> *memoryStore;
@property(nonatomic, strong) LKMCPRequirementCodeInfoBoardController *codeInfoBoardController;

@end

@implementation LKRequirementCodeInfoStore

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static LKRequirementCodeInfoStore *instance = nil;
    dispatch_once(&onceToken,^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memoryStore = [NSMutableDictionary dictionary];
        _ttlMode = LKMCPCodeInfoTTLModeSessionOnly;
    }
    return self;
}

- (NSArray<LKRequirementCodeInfoRecord *> *)recordModelsForSessionId:(NSString *)sessionId {
    NSString *safeSessionId = sessionId ?: @"";
    // Read-through strategy: memory first, then UserDefaults fallback.
    [self cleanupExpiredRecords];
    NSArray<LKRequirementCodeInfoRecord *> *records = self.memoryStore[safeSessionId];
    if (records) {
        return [self _copiedRecordModels:records];
    }

    if (![self _shouldPersistToUserDefaults]) {
        return @[];
    }

    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:[self _persistedKeyForSessionId:safeSessionId]];
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return @[];
    }

    NSArray *persistedRecords = payload[LKMCPCodeInfoPayloadRecordsKey];
    if (![persistedRecords isKindOfClass:[NSArray class]]) {
        return @[];
    }

    NSArray<LKRequirementCodeInfoRecord *> *normalized = [self _normalizeRecordModelsArray:persistedRecords];
    self.memoryStore[safeSessionId] = normalized;
    return [self _copiedRecordModels:normalized];
}

- (void)saveRecordModels:(NSArray<LKRequirementCodeInfoRecord *> *)records sessionId:(NSString *)sessionId {
    NSString *safeSessionId = sessionId ?: @"";
    // Normalize before persisting to keep schema stable across UI/tool writes.
    NSArray<LKRequirementCodeInfoRecord *> *normalized = [self _normalizeRecordModelsArray:records];
    self.memoryStore[safeSessionId] = normalized;

    NSString *persistedKey = [self _persistedKeyForSessionId:safeSessionId];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![self _shouldPersistToUserDefaults]) {
        [defaults removeObjectForKey:persistedKey];
        return;
    }

    NSDictionary *payload = @{
        LKMCPCodeInfoPayloadSavedAtKey: [LKMCPError currentTimestampMs],
        LKMCPCodeInfoPayloadRecordsKey: [self _dictionariesFromRecordModels:normalized]
    };
    [defaults setObject:payload forKey:persistedKey];
}

- (NSArray<NSDictionary<NSString *,NSString *> *> *)recordsForSessionId:(NSString *)sessionId {
    NSArray<LKRequirementCodeInfoRecord *> *records = [self recordModelsForSessionId:sessionId];
    return [self _dictionariesFromRecordModels:records];
}

- (void)saveRecords:(NSArray<NSDictionary<NSString *,NSString *> *> *)records sessionId:(NSString *)sessionId {
    NSArray<LKRequirementCodeInfoRecord *> *models = [self _normalizeRecordModelsArray:records];
    [self saveRecordModels:models sessionId:sessionId];
}

- (void)removeRecordsForSessionId:(NSString *)sessionId {
    NSString *safeSessionId = sessionId ?: @"";
    [self.memoryStore removeObjectForKey:safeSessionId];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self _persistedKeyForSessionId:safeSessionId]];
}

- (void)cleanupExpiredRecords {
    if (![self _shouldPersistToUserDefaults]) {
        return;
    }
    NSTimeInterval ttlSeconds = [self _ttlSeconds];
    if (ttlSeconds <= 0) {
        return;
    }

    long long nowMs = [LKMCPError currentTimestampMs].longLongValue;
    NSDictionary<NSString *, id> *allDefaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    __block NSUInteger removedCount = 0;
    [allDefaults enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (![key hasPrefix:LKMCPCodeInfoPersistencePrefix]) {
            return;
        }
        NSDictionary *payload = [obj isKindOfClass:[NSDictionary class]] ? (NSDictionary *)obj : nil;
        NSNumber *savedAt = [payload[LKMCPCodeInfoPayloadSavedAtKey] isKindOfClass:[NSNumber class]] ? payload[LKMCPCodeInfoPayloadSavedAtKey] : nil;
        if (!savedAt) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
            removedCount += 1;
            return;
        }
        long long elapsedMs = nowMs - savedAt.longLongValue;
        if (elapsedMs > (long long)(ttlSeconds * 1000.0)) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
            NSString *sessionId = [key substringFromIndex:LKMCPCodeInfoPersistencePrefix.length];
            [self.memoryStore removeObjectForKey:sessionId];
            removedCount += 1;
        }
    }];
    if (removedCount > 0) {
        LKMCPCodeInfoStoreLog(@"cleanup removed expired persisted records=%@", @(removedCount));
    }
}

- (void)clearAllPersistedRecords {
    NSUInteger memoryCount = self.memoryStore.count;
    [self.memoryStore removeAllObjects];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary<NSString *, id> *allDefaults = [defaults dictionaryRepresentation];
    __block NSUInteger removedCount = 0;
    [allDefaults enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if ([key hasPrefix:LKMCPCodeInfoPersistencePrefix]) {
            [defaults removeObjectForKey:key];
            removedCount += 1;
        }
    }];
    LKMCPCodeInfoStoreLog(@"clear all records, memorySessions=%@, persistedKeys=%@", @(memoryCount), @(removedCount));
}

- (void)showRequirementCodeInfoBoardForSessionId:(NSString *)sessionId {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.codeInfoBoardController) {
            self.codeInfoBoardController = [[LKMCPRequirementCodeInfoBoardController alloc] initWithStore:self];
        }
        [self.codeInfoBoardController showBoardForSessionId:sessionId ?: @""];
        LKMCPCodeInfoStoreLog(@"show board for sessionId=%@", sessionId ?: @"");
    });
}

- (NSString *)_persistedKeyForSessionId:(NSString *)sessionId {
    return [LKMCPCodeInfoPersistencePrefix stringByAppendingString:sessionId];
}

- (NSTimeInterval)_ttlSeconds {
    switch (self.ttlMode) {
        case LKMCPCodeInfoTTLMode1Hour:
            return 3600;
        case LKMCPCodeInfoTTLMode1Day:
            return 24 * 3600;
        case LKMCPCodeInfoTTLModeSessionOnly:
        default:
            return 0;
    }
}

- (BOOL)_shouldPersistToUserDefaults {
    if (self.ttlMode == LKMCPCodeInfoTTLModeSessionOnly) {
        return NO;
    }

    NSString *envRaw = [[NSProcessInfo processInfo].environment[@"LOOKIN_MCP_CODE_INFO_FORCE_MEMORY_ONLY"] lowercaseString] ?: @"";
    if (envRaw.length > 0) {
        return ![self _isTruthyString:envRaw];
    }

    id defaultsValue = [[NSUserDefaults standardUserDefaults] objectForKey:LKMCPCodeInfoForceMemoryOnlyDefaultsKey];
    if ([defaultsValue respondsToSelector:@selector(stringValue)]) {
        NSString *raw = [[defaultsValue stringValue] lowercaseString];
        if (raw.length > 0) {
            return ![self _isTruthyString:raw];
        }
    }
    return YES;
}

- (BOOL)_isTruthyString:(NSString *)raw {
    static NSSet<NSString *> *truthyValues = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        truthyValues = [NSSet setWithArray:@[@"1", @"true", @"yes", @"on"]];
    });
    return [truthyValues containsObject:[raw lowercaseString] ?: @""];
}

- (NSArray<LKRequirementCodeInfoRecord *> *)_normalizeRecordModelsArray:(NSArray *)records {
    NSMutableArray<LKRequirementCodeInfoRecord *> *result = [NSMutableArray array];
    [records enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        LKRequirementCodeInfoRecord *record = nil;
        if ([obj isKindOfClass:[LKRequirementCodeInfoRecord class]]) {
            record = [(LKRequirementCodeInfoRecord *)obj copy];
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            record = [LKRequirementCodeInfoRecord recordFromDictionary:(NSDictionary *)obj];
        }
        if (!record || record.requirementId.length == 0) {
            return;
        }
        [result addObject:record];
    }];
    return result.copy;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)_dictionariesFromRecordModels:(NSArray<LKRequirementCodeInfoRecord *> *)records {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *result = [NSMutableArray arrayWithCapacity:records.count];
    [records enumerateObjectsUsingBlock:^(LKRequirementCodeInfoRecord *obj, NSUInteger idx, BOOL *stop) {
        if (![obj isKindOfClass:[LKRequirementCodeInfoRecord class]]) {
            return;
        }
        if (obj.requirementId.length == 0) {
            return;
        }
        [result addObject:[obj dictionaryRepresentation]];
    }];
    return result.copy;
}

- (NSArray<LKRequirementCodeInfoRecord *> *)_copiedRecordModels:(NSArray<LKRequirementCodeInfoRecord *> *)records {
    NSMutableArray<LKRequirementCodeInfoRecord *> *result = [NSMutableArray arrayWithCapacity:records.count];
    [records enumerateObjectsUsingBlock:^(LKRequirementCodeInfoRecord *obj, NSUInteger idx, BOOL *stop) {
        if (![obj isKindOfClass:[LKRequirementCodeInfoRecord class]]) {
            return;
        }
        [result addObject:[obj copy]];
    }];
    return result.copy;
}

@end
