//
//  LKMCPRequirementCodeInfoBoardController.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class LKRequirementCodeInfoStore;

@interface LKMCPRequirementCodeInfoBoardController : NSWindowController

- (instancetype)initWithStore:(LKRequirementCodeInfoStore *)store;
- (void)showBoardForSessionId:(NSString *)sessionId;

@end

NS_ASSUME_NONNULL_END

