//
//  LKRequirementBindingService.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LKRequirementBindingStore;

@interface LKRequirementBindingService : NSObject

- (instancetype)initWithStore:(LKRequirementBindingStore *)store;

- (nullable NSDictionary<NSString *, id> *)setRequirementItemsWithArguments:(NSDictionary<NSString *, id> *)arguments
                                                                   sessionId:(NSString *)sessionId
                                                                       error:(NSError **)error;

- (nullable NSDictionary<NSString *, id> *)getRequirementBindingsWithSessionId:(NSString *)sessionId
                                                                          error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
