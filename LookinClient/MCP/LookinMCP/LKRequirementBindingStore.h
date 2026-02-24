//
//  LKRequirementCodeInfoStore.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LKMCPCodeInfoTTLMode) {
    /// 仅当前会话有效，不持久化。
    LKMCPCodeInfoTTLModeSessionOnly = 0,
    /// 持久化后 1 小时过期。
    LKMCPCodeInfoTTLMode1Hour = 1,
    /// 持久化后 1 天过期。
    LKMCPCodeInfoTTLMode1Day = 2,
};

/// Requirement Code Info 存储层（内存 + UserDefaults）。
@interface LKRequirementCodeInfoStore : NSObject

/// 全局单例。
+ (instancetype)sharedInstance;

/// 持久化 TTL 策略。
@property(nonatomic, assign) LKMCPCodeInfoTTLMode ttlMode;

/// 读取指定会话的 requirement 记录。
- (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsForSessionId:(NSString *)sessionId;
/// 保存指定会话的 requirement 记录（覆盖写）。
- (void)saveRecords:(NSArray<NSDictionary<NSString *, NSString *> *> *)records sessionId:(NSString *)sessionId;
/// 删除指定会话的全部记录。
- (void)removeRecordsForSessionId:(NSString *)sessionId;
/// 清理过期持久化记录。
- (void)cleanupExpiredRecords;
/// 清空所有持久化数据与内存缓存。
- (void)clearAllPersistedRecords;
/// 展示全局 Code Info 看板窗口。
- (void)showRequirementCodeInfoBoardForSessionId:(NSString *)sessionId;

@end

NS_ASSUME_NONNULL_END
