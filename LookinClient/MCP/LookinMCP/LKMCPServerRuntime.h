//
//  LKMCPServerRuntime.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LKMCPToolRouter;

/// Lookin 内嵌 MCP HTTP 运行时，负责服务生命周期与 Tool 请求分发。
@interface LKMCPServerRuntime : NSObject

/// 全局单例。
+ (instancetype)sharedInstance;

/// 服务是否已启动。
@property(nonatomic, assign, readonly, getter=isRunning) BOOL running;
/// 当前监听端口（未启动时为 0）。
@property(nonatomic, assign, readonly) NSUInteger listeningPort;
/// 当前活跃会话 ID（由外部在会话变化时更新）。
@property(nonatomic, copy, nullable) NSString *sessionId;
/// Tool 路由器实例。
@property(nonatomic, strong, readonly) LKMCPToolRouter *toolRouter;

/// 启动 MCP 服务。
/// @param port 期望监听端口。
/// @param error 启动失败时返回错误信息。
/// @return 启动成功返回 YES。
- (BOOL)startWithPort:(NSUInteger)port error:(NSError **)error;
/// 停止 MCP 服务并释放监听资源。
- (void)stop;

/// 直接处理一次 Tool 调用（供 HTTP 入口或本地调试复用）。
/// @param toolName Tool 名称（例如 `lookin.health`）。
/// @param arguments Tool 参数，允许为空。
/// @param error 调用失败时返回错误信息。
/// @return Tool 的 `structuredContent` 结果。
- (nullable NSDictionary<NSString *, id> *)handleToolRequestWithName:(NSString *)toolName
                                                            arguments:(nullable NSDictionary<NSString *, id> *)arguments
                                                                error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
