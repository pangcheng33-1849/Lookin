//
//  LKMCPContextService.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 提供 MCP 所需的会话、选中节点上下文与截图能力。
@interface LKMCPContextService : NSObject

/// 获取当前活跃会话 ID。
- (nullable NSString *)currentSessionId;

/// 构造 `lookin.health` 的 structuredContent。
- (NSDictionary<NSString *, id> *)healthStructuredContent;

/// 构造 `lookin.get_selected_view_context` 返回内容。
/// @param arguments Tool 参数（当前支持 `childrenDepth`）。
/// @param error 失败时返回错误信息。
- (nullable NSDictionary<NSString *, id> *)selectedViewContextWithArguments:(NSDictionary<NSString *, id> *)arguments
                                                                       error:(NSError **)error;

/// 导出当前选中视图截图并返回路径与元数据。
/// @param arguments Tool 参数（格式、scale、高亮开关）。
/// @param error 失败时返回错误信息。
- (nullable NSDictionary<NSString *, id> *)captureSelectedViewScreenshotWithArguments:(NSDictionary<NSString *, id> *)arguments
                                                                                 error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
