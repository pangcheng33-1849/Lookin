//
//  LKMCPRequirementCodeInfoBoardController.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class LKRequirementCodeInfoStore;

/// 全局 Code Info 看板窗口控制器。
@interface LKMCPRequirementCodeInfoBoardController : NSWindowController

/// 使用指定 store 初始化看板控制器。
- (instancetype)initWithStore:(LKRequirementCodeInfoStore *)store;
/// 展示指定会话的数据看板。
- (void)showBoardForSessionId:(NSString *)sessionId;

@end

NS_ASSUME_NONNULL_END
