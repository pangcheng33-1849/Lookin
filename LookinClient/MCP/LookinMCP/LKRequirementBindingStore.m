//
//  LKRequirementCodeInfoStore.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKRequirementBindingStore.h"
#import "LKMCPError.h"
#import "LKMCPRequirementCodeInfoBoardController.h"

static NSString * const LKMCPCodeInfoPersistencePrefix = @"mcp_requirement_code_info_";
static NSString * const LKMCPCodeInfoPayloadSavedAtKey = @"savedAtMs";
static NSString * const LKMCPCodeInfoPayloadRecordsKey = @"records";

static NSString * const LKMCPCodeInfoFieldRequirementId = @"requirementId";
static NSString * const LKMCPCodeInfoFieldDescription = @"description";
static NSString * const LKMCPCodeInfoFieldCodeInfo = @"codeInfo";

@interface LKRequirementCodeInfoStore ()

@property(nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSDictionary<NSString *, NSString *> *> *> *memoryStore;
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

- (NSArray<NSDictionary<NSString *,NSString *> *> *)recordsForSessionId:(NSString *)sessionId {
    [self cleanupExpiredRecords];
    NSArray<NSDictionary<NSString *, NSString *> *> *records = self.memoryStore[sessionId];
    if (records) {
        return records.copy;
    }

    if (self.ttlMode == LKMCPCodeInfoTTLModeSessionOnly) {
        return @[];
    }

    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:[self _persistedKeyForSessionId:sessionId]];
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return @[];
    }

    NSArray *persistedRecords = payload[LKMCPCodeInfoPayloadRecordsKey];
    if (![persistedRecords isKindOfClass:[NSArray class]]) {
        return @[];
    }

    NSArray<NSDictionary<NSString *, NSString *> *> *normalized = [self _normalizeRecordsArray:persistedRecords];
    self.memoryStore[sessionId] = normalized;
    return normalized.copy;
}

- (void)saveRecords:(NSArray<NSDictionary<NSString *,NSString *> *> *)records sessionId:(NSString *)sessionId {
    NSArray<NSDictionary<NSString *, NSString *> *> *normalized = [self _normalizeRecordsArray:records];
    self.memoryStore[sessionId] = normalized;

    NSString *persistedKey = [self _persistedKeyForSessionId:sessionId];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (self.ttlMode == LKMCPCodeInfoTTLModeSessionOnly) {
        [defaults removeObjectForKey:persistedKey];
        return;
    }

    NSDictionary *payload = @{
        LKMCPCodeInfoPayloadSavedAtKey: [LKMCPError currentTimestampMs],
        LKMCPCodeInfoPayloadRecordsKey: normalized
    };
    [defaults setObject:payload forKey:persistedKey];
}

- (void)removeRecordsForSessionId:(NSString *)sessionId {
    [self.memoryStore removeObjectForKey:sessionId];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self _persistedKeyForSessionId:sessionId]];
}

- (void)cleanupExpiredRecords {
    if (self.ttlMode == LKMCPCodeInfoTTLModeSessionOnly) {
        return;
    }
    NSTimeInterval ttlSeconds = [self _ttlSeconds];
    if (ttlSeconds <= 0) {
        return;
    }

    long long nowMs = [LKMCPError currentTimestampMs].longLongValue;
    NSDictionary<NSString *, id> *allDefaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    [allDefaults enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (![key hasPrefix:LKMCPCodeInfoPersistencePrefix]) {
            return;
        }
        NSDictionary *payload = [obj isKindOfClass:[NSDictionary class]] ? (NSDictionary *)obj : nil;
        NSNumber *savedAt = [payload[LKMCPCodeInfoPayloadSavedAtKey] isKindOfClass:[NSNumber class]] ? payload[LKMCPCodeInfoPayloadSavedAtKey] : nil;
        if (!savedAt) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
            return;
        }
        long long elapsedMs = nowMs - savedAt.longLongValue;
        if (elapsedMs > (long long)(ttlSeconds * 1000.0)) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
            NSString *sessionId = [key substringFromIndex:LKMCPCodeInfoPersistencePrefix.length];
            [self.memoryStore removeObjectForKey:sessionId];
        }
    }];
}

- (void)showRequirementCodeInfoBoardForSessionId:(NSString *)sessionId {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.codeInfoBoardController) {
            self.codeInfoBoardController = [[LKMCPRequirementCodeInfoBoardController alloc] initWithStore:self];
        }
        [self.codeInfoBoardController showBoardForSessionId:sessionId ?: @""];
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

- (NSArray<NSDictionary<NSString *, NSString *> *> *)_normalizeRecordsArray:(NSArray *)records {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *result = [NSMutableArray array];
    [records enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary *raw = [obj isKindOfClass:[NSDictionary class]] ? (NSDictionary *)obj : nil;
        if (!raw) {
            return;
        }
        NSString *rid = [raw[LKMCPCodeInfoFieldRequirementId] isKindOfClass:[NSString class]] ? raw[LKMCPCodeInfoFieldRequirementId] : @"";
        NSString *desc = [raw[LKMCPCodeInfoFieldDescription] isKindOfClass:[NSString class]] ? raw[LKMCPCodeInfoFieldDescription] : @"";
        NSString *codeInfo = [raw[LKMCPCodeInfoFieldCodeInfo] isKindOfClass:[NSString class]] ? raw[LKMCPCodeInfoFieldCodeInfo] : @"";
        if (rid.length == 0) {
            return;
        }
        [result addObject:@{
            LKMCPCodeInfoFieldRequirementId: rid,
            LKMCPCodeInfoFieldDescription: desc,
            LKMCPCodeInfoFieldCodeInfo: codeInfo
        }];
    }];
    return result.copy;
}

@end
