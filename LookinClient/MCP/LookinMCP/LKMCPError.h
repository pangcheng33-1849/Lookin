//
//  LKMCPError.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// MCP 模块统一错误域。
extern NSErrorDomain const LKMCPErrorDomain;

/// 无有效 Inspect 会话。
extern NSString * const LKMCPErrorCodeNoSession;
/// 当前没有选中视图。
extern NSString * const LKMCPErrorCodeNoSelection;
/// 请求内 requirementId 重复。
extern NSString * const LKMCPErrorCodeDuplicateRequirementID;
/// 指定 requirementId 不存在。
extern NSString * const LKMCPErrorCodeRequirementNotFound;
/// 参数非法或不满足约束。
extern NSString * const LKMCPErrorCodeBadArgument;
/// 指定 nodeId 未找到。
extern NSString * const LKMCPErrorCodeNodeNotFound;
/// 截图导出失败。
extern NSString * const LKMCPErrorCodeScreenshotFailed;

/// `NSError.userInfo` 中的稳定错误码键。
extern NSString * const LKMCPErrorUserInfoCodeKey;
/// `NSError.userInfo` 中的“是否可恢复”键。
extern NSString * const LKMCPErrorUserInfoRecoverableKey;
/// `NSError.userInfo` 中的恢复提示键。
extern NSString * const LKMCPErrorUserInfoHintKey;
/// `NSError.userInfo` 中的会话 ID 键。
extern NSString * const LKMCPErrorUserInfoSessionIDKey;
/// `NSError.userInfo` 中的毫秒时间戳键。
extern NSString * const LKMCPErrorUserInfoTimestampKey;

/// MCP 错误构造与序列化工具。
@interface LKMCPError : NSObject

/// 生成符合 MCP 约定的 NSError。
/// @param code 稳定错误码（`LOOKIN_MCP_*`）。
/// @param message 面向调用方的错误描述。
/// @param recoverable 是否可通过重试/切换状态恢复。
/// @param hint 恢复建议。
/// @param sessionId 关联会话 ID，可为空。
+ (NSError *)errorWithCode:(NSString *)code
                   message:(NSString *)message
               recoverable:(BOOL)recoverable
                      hint:(nullable NSString *)hint
                 sessionId:(nullable NSString *)sessionId;

/// 将 NSError 转换为 MCP error.data 字典。
/// @param error 原始错误对象。
/// @param defaultCode 当 error 中缺失 code 时使用的兜底错误码。
/// @param defaultMessage 当 error 中缺失 message 时使用的兜底文案。
/// @param sessionId 当前会话 ID（用于兜底填充）。
+ (NSDictionary<NSString *, id> *)errorDataFromError:(NSError *)error
                                         defaultCode:(NSString *)defaultCode
                                      defaultMessage:(NSString *)defaultMessage
                                           sessionId:(nullable NSString *)sessionId;

/// 当前 Unix 毫秒时间戳。
+ (NSNumber *)currentTimestampMs;

@end

NS_ASSUME_NONNULL_END
