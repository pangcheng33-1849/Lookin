//
//  LKMCPToolRouter.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LKMCPContextService, LKRequirementCodeInfoService;

/// MCP Tool 路由器：按 Tool 名称分发到对应服务实现。
@interface LKMCPToolRouter : NSObject

/// 指定依赖初始化路由器。
/// @param contextService 视图上下文服务；传 nil 时内部使用默认实现。
/// @param codeInfoService 需求代码信息服务；传 nil 时内部使用默认实现。
- (instancetype)initWithContextService:(nullable LKMCPContextService *)contextService
                       codeInfoService:(nullable LKRequirementCodeInfoService *)codeInfoService;

/// 路由并执行 Tool。
/// @param toolName Tool 名称（`lookin.*`）。
/// @param arguments Tool 参数，允许为空。
/// @param error 调用失败时返回错误信息。
/// @return Tool `structuredContent`；失败时返回 nil。
- (nullable NSDictionary<NSString *, id> *)routeToolName:(NSString *)toolName
                                                arguments:(nullable NSDictionary<NSString *, id> *)arguments
                                                    error:(NSError **)error;

/// 返回 MCP `tools/list` 所需的工具定义元数据。
- (NSArray<NSDictionary<NSString *, id> *> *)mcpToolDefinitions;

@end

NS_ASSUME_NONNULL_END
