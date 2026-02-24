//
//  LKMCPToolRouter.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKMCPToolRouter.h"
#import "LKMCPContextService.h"
#import "LKRequirementBindingService.h"
#import "LKRequirementBindingStore.h"
#import "LKMCPError.h"
#if DEBUG
#import "LKMCPToolRouter+Testing.h"
#endif

#define LKMCPRouterLog(fmt, ...) NSLog((@"[LookinMCP][Router] " fmt), ##__VA_ARGS__)

@interface LKMCPToolRouter ()

@property(nonatomic, strong) LKMCPContextService *contextService;
@property(nonatomic, strong) LKRequirementCodeInfoService *codeInfoService;

@end

@implementation LKMCPToolRouter

- (instancetype)initWithContextService:(LKMCPContextService * _Nullable)contextService
                       codeInfoService:(LKRequirementCodeInfoService * _Nullable)codeInfoService {
    self = [super init];
    if (self) {
        _contextService = contextService ?: [[LKMCPContextService alloc] init];
        if (codeInfoService) {
            _codeInfoService = codeInfoService;
        } else {
            LKRequirementCodeInfoStore *store = [LKRequirementCodeInfoStore sharedInstance];
            _codeInfoService = [[LKRequirementCodeInfoService alloc] initWithStore:store];
        }
    }
    return self;
}

- (NSDictionary<NSString *,id> *)routeToolName:(NSString *)toolName
                                      arguments:(NSDictionary<NSString *,id> *)arguments
                                          error:(NSError *__autoreleasing  _Nullable *)error {
    NSDictionary<NSString *, id> *safeArguments = [arguments isKindOfClass:[NSDictionary class]] ? arguments : @{};
#if DEBUG
    safeArguments = [self lk_debugArgumentsByApplyingScenarioFlags:safeArguments contextService:self.contextService];
#endif

    if (toolName.length == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"Tool name is empty."
                                   recoverable:YES
                                          hint:@"Use one of lookin.* tool names."
                                     sessionId:nil];
        }
        LKMCPRouterLog(@"reject empty tool name");
        return nil;
    }

    if ([toolName isEqualToString:@"lookin.health"]) {
        return [self.contextService healthStructuredContent];
    }

    if ([toolName isEqualToString:@"lookin.get_selected_view_context"]) {
        return [self.contextService selectedViewContextWithArguments:safeArguments error:error];
    }

    if ([toolName isEqualToString:@"lookin.capture_selected_view_screenshot"]) {
        return [self.contextService captureSelectedViewScreenshotWithArguments:safeArguments error:error];
    }

    NSString *sessionId = [self.contextService currentSessionId];
    if (sessionId.length == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeNoSession
                                       message:@"No active inspectable app session."
                                   recoverable:YES
                                          hint:@"Connect an app in Lookin, then retry."
                                     sessionId:nil];
        }
        LKMCPRouterLog(@"tool requires session but no active session, name=%@", toolName);
        return nil;
    }

    if ([toolName isEqualToString:@"lookin.set_requirement_items"]) {
        return [self.codeInfoService setRequirementItemsWithArguments:safeArguments sessionId:sessionId error:error];
    }
    if ([toolName isEqualToString:@"lookin.get_requirement_code_info"]) {
        return [self.codeInfoService getRequirementCodeInfoWithSessionId:sessionId error:error];
    }

    if (error) {
        *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                   message:[NSString stringWithFormat:@"Unsupported tool: %@", toolName]
                               recoverable:YES
                                      hint:@"Use one of documented lookin.* tools."
                                 sessionId:sessionId];
    }
    LKMCPRouterLog(@"unsupported tool name=%@", toolName ?: @"");
    return nil;
}

@end
