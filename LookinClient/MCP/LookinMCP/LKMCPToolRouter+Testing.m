//
//  LKMCPToolRouter+Testing.m
//  Lookin
//
//  Created by Codex on 2026/2/24.
//

#import "LKMCPToolRouter+Testing.h"

#if DEBUG
#import "LKMCPContextService+Testing.h"
#import "LKMCPContextService.h"
#define LKMCPRouterTestingLog(fmt, ...) NSLog((@"[LookinMCP][Router][Testing] " fmt), ##__VA_ARGS__)

static NSString * const LKMCPScenarioFlagsArgumentKey = @"_scenarioFlags";

@implementation LKMCPToolRouter (Testing)

- (NSDictionary<NSString *,id> *)lk_debugArgumentsByApplyingScenarioFlags:(NSDictionary<NSString *,id> *)arguments
                                                            contextService:(LKMCPContextService *)contextService {
    NSDictionary<NSString *, id> *scenarioFlags = [arguments[LKMCPScenarioFlagsArgumentKey] isKindOfClass:[NSDictionary class]] ? arguments[LKMCPScenarioFlagsArgumentKey] : nil;
    [contextService lk_setScenarioOverrides:scenarioFlags];
    if (!scenarioFlags) {
        return arguments;
    }
    LKMCPRouterTestingLog(@"applied scenario flags: %@", scenarioFlags);

    NSMutableDictionary<NSString *, id> *mutableArguments = [arguments mutableCopy];
    [mutableArguments removeObjectForKey:LKMCPScenarioFlagsArgumentKey];
    return mutableArguments.copy;
}

@end

#endif
