//
//  LKMCPContextService+Testing.m
//  Lookin
//
//  Created by Codex on 2026/2/24.
//

#import "LKMCPContextService+Testing.h"

#if DEBUG
#import <objc/runtime.h>
#define LKMCPContextTestingLog(fmt, ...) NSLog((@"[LookinMCP][Context][Testing] " fmt), ##__VA_ARGS__)

static const void *kLKMCPScenarioOverridesKey = &kLKMCPScenarioOverridesKey;

@implementation LKMCPContextService (Testing)

- (void)lk_setScenarioOverrides:(NSDictionary<NSString *,id> *)scenarioOverrides {
    NSDictionary<NSString *, id> *normalized = [scenarioOverrides isKindOfClass:[NSDictionary class]] ? [scenarioOverrides copy] : @{};
    objc_setAssociatedObject(self, kLKMCPScenarioOverridesKey, normalized, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (normalized.count > 0) {
        LKMCPContextTestingLog(@"scenario overrides updated: %@", normalized);
    }
}

- (id)lk_scenarioOverrideForFlag:(NSString *)flagName {
    NSDictionary<NSString *, id> *overrides = objc_getAssociatedObject(self, kLKMCPScenarioOverridesKey);
    if (![overrides isKindOfClass:[NSDictionary class]] || flagName.length == 0) {
        return nil;
    }
    return overrides[flagName];
}

@end

#endif
