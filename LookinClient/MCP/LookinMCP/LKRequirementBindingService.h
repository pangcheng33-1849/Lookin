//
//  LKRequirementCodeInfoService.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LKRequirementCodeInfoStore;

@interface LKRequirementCodeInfoService : NSObject

- (instancetype)initWithStore:(LKRequirementCodeInfoStore *)store;

- (nullable NSDictionary<NSString *, id> *)setRequirementItemsWithArguments:(NSDictionary<NSString *, id> *)arguments
                                                                   sessionId:(NSString *)sessionId
                                                                       error:(NSError **)error;

- (nullable NSDictionary<NSString *, id> *)getRequirementCodeInfoWithSessionId:(NSString *)sessionId
                                                                          error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
