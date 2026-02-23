//
//  LKRequirementBindingStore.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LKMCPBindingTTLMode) {
    LKMCPBindingTTLModeSessionOnly = 0,
    LKMCPBindingTTLMode1Hour = 1,
    LKMCPBindingTTLMode1Day = 2,
};

@interface LKRequirementBindingStore : NSObject

+ (instancetype)sharedInstance;

@property(nonatomic, assign) LKMCPBindingTTLMode ttlMode;

- (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsForSessionId:(NSString *)sessionId;
- (void)saveRecords:(NSArray<NSDictionary<NSString *, NSString *> *> *)records sessionId:(NSString *)sessionId;
- (void)removeRecordsForSessionId:(NSString *)sessionId;
- (void)cleanupExpiredRecords;
- (void)showRequirementBindingBoardForSessionId:(NSString *)sessionId;

@end

NS_ASSUME_NONNULL_END
