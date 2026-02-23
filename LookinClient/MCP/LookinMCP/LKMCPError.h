//
//  LKMCPError.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const LKMCPErrorDomain;

extern NSString * const LKMCPErrorCodeNoSession;
extern NSString * const LKMCPErrorCodeNoSelection;
extern NSString * const LKMCPErrorCodeDuplicateRequirementID;
extern NSString * const LKMCPErrorCodeRequirementNotFound;
extern NSString * const LKMCPErrorCodeBadArgument;
extern NSString * const LKMCPErrorCodeScreenshotFailed;

extern NSString * const LKMCPErrorUserInfoCodeKey;
extern NSString * const LKMCPErrorUserInfoRecoverableKey;
extern NSString * const LKMCPErrorUserInfoHintKey;
extern NSString * const LKMCPErrorUserInfoSessionIDKey;
extern NSString * const LKMCPErrorUserInfoTimestampKey;

@interface LKMCPError : NSObject

+ (NSError *)errorWithCode:(NSString *)code
                   message:(NSString *)message
               recoverable:(BOOL)recoverable
                      hint:(nullable NSString *)hint
                 sessionId:(nullable NSString *)sessionId;

+ (NSDictionary<NSString *, id> *)errorDataFromError:(NSError *)error
                                         defaultCode:(NSString *)defaultCode
                                      defaultMessage:(NSString *)defaultMessage
                                           sessionId:(nullable NSString *)sessionId;

+ (NSNumber *)currentTimestampMs;

@end

NS_ASSUME_NONNULL_END
