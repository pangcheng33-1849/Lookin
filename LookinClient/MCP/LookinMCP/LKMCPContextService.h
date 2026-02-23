//
//  LKMCPContextService.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LKMCPContextService : NSObject

- (void)setScenarioOverrides:(nullable NSDictionary<NSString *, id> *)scenarioOverrides;

- (nullable NSString *)currentSessionId;

- (NSDictionary<NSString *, id> *)healthStructuredContent;

- (nullable NSDictionary<NSString *, id> *)selectedViewContextWithArguments:(NSDictionary<NSString *, id> *)arguments
                                                                       error:(NSError **)error;

- (nullable NSDictionary<NSString *, id> *)captureSelectedViewScreenshotWithArguments:(NSDictionary<NSString *, id> *)arguments
                                                                                 error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
