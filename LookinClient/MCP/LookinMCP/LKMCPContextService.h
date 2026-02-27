//
//  LKMCPContextService.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LookinDisplayItem;

/// 提供 MCP 所需的会话、选中节点上下文与截图能力。
@interface LKMCPContextService : NSObject

/// 生成 displayItem 对应的 nodeId（优先 view/layer oid，回退到 displayingObject oid）。
+ (NSString *)nodeIdForDisplayItem:(nullable LookinDisplayItem *)item;

/// 获取当前活跃会话 ID。
- (nullable NSString *)currentSessionId;

/// 构造 `lookin.health` 的 structuredContent。
- (NSDictionary<NSString *, id> *)healthStructuredContent;

/// 构造 `lookin.get_selected_view_context` 返回内容。
/// @param arguments Tool 参数（当前支持 `childrenDepth`）。
/// @param error 失败时返回错误信息。
- (nullable NSDictionary<NSString *, id> *)selectedViewContextWithArguments:(NSDictionary<NSString *, id> *)arguments
                                                                       error:(NSError **)error;

/// 构造 `lookin.get_hierarchy_by_node_id` 返回内容。
/// @param nodeId 可选，未传时从 roots 开始。
/// @param arguments Tool 参数（当前支持 `depth`）。
/// @param error 失败时返回错误信息。
- (nullable NSDictionary<NSString *, id> *)buildHierarchyPayloadByNodeId:(nullable NSString *)nodeId
                                                                arguments:(NSDictionary<NSString *, id> *)arguments
                                                                    error:(NSError **)error;

/// 构造 `lookin.get_view_context_by_node_id` 返回内容。
/// @param nodeId 目标节点 ID。
/// @param arguments Tool 参数（当前支持 `childrenDepth`）。
/// @param error 失败时返回错误信息。
- (nullable NSDictionary<NSString *, id> *)buildViewContextPayloadByNodeId:(NSString *)nodeId
                                                                  arguments:(NSDictionary<NSString *, id> *)arguments
                                                                      error:(NSError **)error;

/// 导出当前选中视图截图并返回路径与元数据。
/// @param arguments Tool 参数（当前支持 `format`）。
/// @param error 失败时返回错误信息。
- (nullable NSDictionary<NSString *, id> *)captureSelectedViewScreenshotWithArguments:(NSDictionary<NSString *, id> *)arguments
                                                                                 error:(NSError **)error;

/// 导出指定节点截图并返回路径与元数据。
/// @param nodeId 目标节点 ID。
/// @param arguments Tool 参数（当前支持 `format`）。
/// @param error 失败时返回错误信息。
- (nullable NSDictionary<NSString *, id> *)captureScreenshotByNodeId:(NSString *)nodeId
                                                            arguments:(NSDictionary<NSString *, id> *)arguments
                                                                error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
