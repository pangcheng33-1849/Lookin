//
//  LKMCPServerRuntime.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LKMCPToolRouter;

@interface LKMCPServerRuntime : NSObject

+ (instancetype)sharedInstance;

@property(nonatomic, assign, readonly, getter=isRunning) BOOL running;
@property(nonatomic, assign, readonly) NSUInteger listeningPort;
@property(nonatomic, copy, nullable) NSString *sessionId;
@property(nonatomic, strong, readonly) LKMCPToolRouter *toolRouter;

- (BOOL)startWithPort:(NSUInteger)port error:(NSError **)error;
- (void)stop;

- (nullable NSDictionary<NSString *, id> *)handleToolRequestWithName:(NSString *)toolName
                                                            arguments:(nullable NSDictionary<NSString *, id> *)arguments
                                                                error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END