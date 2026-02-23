//
//  LKMCPToolRouter.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LKMCPContextService, LKRequirementCodeInfoService;

@interface LKMCPToolRouter : NSObject

- (instancetype)initWithContextService:(nullable LKMCPContextService *)contextService
                       codeInfoService:(nullable LKRequirementCodeInfoService *)codeInfoService;

- (nullable NSDictionary<NSString *, id> *)routeToolName:(NSString *)toolName
                                                arguments:(nullable NSDictionary<NSString *, id> *)arguments
                                                    error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
