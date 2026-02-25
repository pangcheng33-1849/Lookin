//
//  LKMCPError.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKMCPError.h"

NSErrorDomain const LKMCPErrorDomain = @"lookin.mcp.error";

NSString * const LKMCPErrorCodeNoSession = @"LOOKIN_MCP_NO_SESSION";
NSString * const LKMCPErrorCodeNoSelection = @"LOOKIN_MCP_NO_SELECTION";
NSString * const LKMCPErrorCodeDuplicateRequirementID = @"LOOKIN_MCP_DUP_REQUIREMENT_ID";
NSString * const LKMCPErrorCodeRequirementNotFound = @"LOOKIN_MCP_REQUIREMENT_NOT_FOUND";
NSString * const LKMCPErrorCodeBadArgument = @"LOOKIN_MCP_BAD_ARGUMENT";
NSString * const LKMCPErrorCodeNodeNotFound = @"LOOKIN_MCP_NODE_NOT_FOUND";
NSString * const LKMCPErrorCodeScreenshotFailed = @"LOOKIN_MCP_SCREENSHOT_FAILED";

NSString * const LKMCPErrorUserInfoCodeKey = @"mcpCode";
NSString * const LKMCPErrorUserInfoRecoverableKey = @"recoverable";
NSString * const LKMCPErrorUserInfoHintKey = @"hint";
NSString * const LKMCPErrorUserInfoSessionIDKey = @"sessionId";
NSString * const LKMCPErrorUserInfoTimestampKey = @"timestamp";

@implementation LKMCPError

+ (NSError *)errorWithCode:(NSString *)code
                   message:(NSString *)message
               recoverable:(BOOL)recoverable
                      hint:(NSString * _Nullable)hint
                 sessionId:(NSString * _Nullable)sessionId {
    NSMutableDictionary<NSString *, id> *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = message;
    userInfo[LKMCPErrorUserInfoCodeKey] = code;
    userInfo[LKMCPErrorUserInfoRecoverableKey] = @(recoverable);
    userInfo[LKMCPErrorUserInfoTimestampKey] = [self currentTimestampMs];
    if (hint.length > 0) {
        userInfo[LKMCPErrorUserInfoHintKey] = hint;
    }
    if (sessionId.length > 0) {
        userInfo[LKMCPErrorUserInfoSessionIDKey] = sessionId;
    }
    return [NSError errorWithDomain:LKMCPErrorDomain code:0 userInfo:userInfo];
}

+ (NSDictionary<NSString *, id> *)errorDataFromError:(NSError *)error
                                         defaultCode:(NSString *)defaultCode
                                      defaultMessage:(NSString *)defaultMessage
                                           sessionId:(NSString * _Nullable)sessionId {
    NSMutableDictionary<NSString *, id> *data = [NSMutableDictionary dictionary];
    NSString *code = error.userInfo[LKMCPErrorUserInfoCodeKey];
    data[@"code"] = code.length > 0 ? code : defaultCode;

    NSString *message = error.userInfo[NSLocalizedDescriptionKey];
    data[@"message"] = message.length > 0 ? message : defaultMessage;

    NSNumber *recoverable = error.userInfo[LKMCPErrorUserInfoRecoverableKey];
    data[@"recoverable"] = recoverable ?: @NO;

    NSString *hint = error.userInfo[LKMCPErrorUserInfoHintKey];
    if (hint.length > 0) {
        data[@"hint"] = hint;
    }

    NSString *errSessionId = error.userInfo[LKMCPErrorUserInfoSessionIDKey];
    NSString *resolvedSessionId = errSessionId.length > 0 ? errSessionId : sessionId;
    if (resolvedSessionId.length > 0) {
        data[@"sessionId"] = resolvedSessionId;
    }

    NSNumber *timestamp = error.userInfo[LKMCPErrorUserInfoTimestampKey];
    data[@"timestamp"] = timestamp ?: [self currentTimestampMs];
    return data;
}

+ (NSNumber *)currentTimestampMs {
    return @((long long)([[NSDate date] timeIntervalSince1970] * 1000.0));
}

@end
