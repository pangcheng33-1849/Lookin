//
//  LKRequirementCodeInfoService.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LKRequirementCodeInfoStore;

/// `set_requirement_items` / `get_requirement_code_info` 业务服务。
@interface LKRequirementCodeInfoService : NSObject

/// 指定存储依赖初始化服务。
- (instancetype)initWithStore:(LKRequirementCodeInfoStore *)store;

/// 执行 requirement 列表增删。
/// @param arguments Tool 参数（operation=append/remove）。
/// @param sessionId 当前会话 ID。
/// @param error 失败时返回错误信息。
- (nullable NSDictionary<NSString *, id> *)setRequirementItemsWithArguments:(NSDictionary<NSString *, id> *)arguments
                                                                   sessionId:(NSString *)sessionId
                                                                       error:(NSError **)error;

/// 拉取当前会话下所有 requirement code info 记录。
/// @param sessionId 当前会话 ID。
/// @param error 失败时返回错误信息。
- (nullable NSDictionary<NSString *, id> *)getRequirementCodeInfoWithSessionId:(NSString *)sessionId
                                                                          error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
