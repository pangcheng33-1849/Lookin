//
//  LKMCPNotifications.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Requirement Code Info 变更广播通知。
extern NSString * const NotificationName_RequirementCodeInfoDidChange;
/// `userInfo` 中的会话 ID 键（NSString）。
extern NSString * const LKMCPRequirementCodeInfoChangedSessionIdKey;
/// `userInfo` 中的操作类型键（NSString，例如 append/remove/edit/clear）。
extern NSString * const LKMCPRequirementCodeInfoChangedOperationKey;

NS_ASSUME_NONNULL_END
