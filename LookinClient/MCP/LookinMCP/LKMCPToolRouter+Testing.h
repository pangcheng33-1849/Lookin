//
//  LKMCPToolRouter+Testing.h
//  Lookin
//
//  Created by Codex on 2026/2/24.
//

#import "LKMCPToolRouter.h"

NS_ASSUME_NONNULL_BEGIN

@class LKMCPContextService;

#if DEBUG
/// DEBUG-only router helpers for test scenario argument injection.
@interface LKMCPToolRouter (Testing)

/// Applies `_scenarioFlags` to context service and returns cleaned arguments.
- (NSDictionary<NSString *, id> *)lk_debugArgumentsByApplyingScenarioFlags:(NSDictionary<NSString *, id> *)arguments
                                                             contextService:(LKMCPContextService *)contextService;

@end
#endif

NS_ASSUME_NONNULL_END
