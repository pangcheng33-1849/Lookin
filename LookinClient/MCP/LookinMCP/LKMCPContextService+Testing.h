//
//  LKMCPContextService+Testing.h
//  Lookin
//
//  Created by Codex on 2026/2/24.
//

#import "LKMCPContextService.h"

NS_ASSUME_NONNULL_BEGIN

#if DEBUG
/// DEBUG-only testing hooks for scenario simulation.
@interface LKMCPContextService (Testing)

/// Overrides scenario flags in-memory for current process.
- (void)lk_setScenarioOverrides:(nullable NSDictionary<NSString *, id> *)scenarioOverrides;
/// Reads a scenario override by flag name.
- (nullable id)lk_scenarioOverrideForFlag:(NSString *)flagName;

@end
#endif

NS_ASSUME_NONNULL_END
