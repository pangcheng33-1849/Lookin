//
//  LKRequirementCodeInfoStore.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LKMCPCodeInfoTTLMode) {
    LKMCPCodeInfoTTLModeSessionOnly = 0,
    LKMCPCodeInfoTTLMode1Hour = 1,
    LKMCPCodeInfoTTLMode1Day = 2,
};

@interface LKRequirementCodeInfoStore : NSObject

+ (instancetype)sharedInstance;

@property(nonatomic, assign) LKMCPCodeInfoTTLMode ttlMode;

- (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsForSessionId:(NSString *)sessionId;
- (void)saveRecords:(NSArray<NSDictionary<NSString *, NSString *> *> *)records sessionId:(NSString *)sessionId;
- (void)removeRecordsForSessionId:(NSString *)sessionId;
- (void)cleanupExpiredRecords;
- (void)showRequirementCodeInfoBoardForSessionId:(NSString *)sessionId;

@end

NS_ASSUME_NONNULL_END
