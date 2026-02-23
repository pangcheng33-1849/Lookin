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

@interface LKMCPToolRouter ()

@property(nonatomic, strong) LKMCPContextService *contextService;
@property(nonatomic, strong) LKRequirementBindingService *bindingService;

@end

@implementation LKMCPToolRouter

- (instancetype)initWithContextService:(LKMCPContextService * _Nullable)contextService
                        bindingService:(LKRequirementBindingService * _Nullable)bindingService {
    self = [super init];
    if (self) {
        _contextService = contextService ?: [[LKMCPContextService alloc] init];
        if (bindingService) {
            _bindingService = bindingService;
        } else {
            LKRequirementBindingStore *store = [LKRequirementBindingStore sharedInstance];
            _bindingService = [[LKRequirementBindingService alloc] initWithStore:store];
        }
    }
    return self;
}

- (NSDictionary<NSString *,id> *)routeToolName:(NSString *)toolName
                                      arguments:(NSDictionary<NSString *,id> *)arguments
                                          error:(NSError *__autoreleasing  _Nullable *)error {
    NSDictionary<NSString *, id> *safeArguments = [arguments isKindOfClass:[NSDictionary class]] ? arguments : @{};
    if (toolName.length == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"Tool name is empty."
                                   recoverable:YES
                                          hint:@"Use one of lookin.* tool names."
                                     sessionId:nil];
        }
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
        return nil;
    }

    if ([toolName isEqualToString:@"lookin.set_requirement_items"]) {
        return [self.bindingService setRequirementItemsWithArguments:safeArguments sessionId:sessionId error:error];
    }
    if ([toolName isEqualToString:@"lookin.get_requirement_bindings"]) {
        return [self.bindingService getRequirementBindingsWithSessionId:sessionId error:error];
    }

    if (error) {
        *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                   message:[NSString stringWithFormat:@"Unsupported tool: %@", toolName]
                               recoverable:YES
                                      hint:@"Use one of documented lookin.* tools."
                                 sessionId:sessionId];
    }
    return nil;
}

@end
