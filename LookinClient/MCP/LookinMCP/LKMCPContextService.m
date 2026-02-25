//
//  LKMCPContextService.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKMCPContextService.h"
#import "LKMCPError.h"
#import "LKAppsManager.h"
#import "LKInspectableApp.h"
#import "LKStaticHierarchyDataSource.h"
#import "LookinAppInfo.h"
#import "LookinDisplayItem.h"
#import "LookinObject.h"
#import "LookinAttributesGroup.h"
#import "LookinAttributesSection.h"
#import "LookinAttribute.h"
#import "LookinDashboardBlueprint.h"
#import "LookinAutoLayoutConstraint.h"
#import "LookinAutoLayoutConstraint+LookinClient.h"
#import "LookinDisplayItem+LookinClient.h"
#import "LookinHierarchyInfo.h"
#import <limits.h>
#import <math.h>
#import <stdlib.h>
#if DEBUG
#import "LKMCPContextService+Testing.h"
#endif
@import AppKit;
#define LKMCPContextLog(fmt, ...) NSLog((@"[LookinMCP][Context] " fmt), ##__VA_ARGS__)
static const NSInteger LKMCPHierarchyDepthMax = 16;

static BOOL LKMCPScenarioFlagEnabled(NSString *flagName) {
#if DEBUG
    NSString *raw = [[NSProcessInfo processInfo].environment[flagName] lowercaseString] ?: @"";
    if (raw.length == 0) {
        return NO;
    }
    static NSSet<NSString *> *truthyValues = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        truthyValues = [NSSet setWithArray:@[@"1", @"true", @"yes", @"on"]];
    });
    return [truthyValues containsObject:raw];
#else
    (void)flagName;
    return NO;
#endif
}

static BOOL LKMCPShouldDropSessionForSwitchScenario(void) {
#if DEBUG
    static NSUInteger counter = 0;
    @synchronized([LKMCPContextService class]) {
        counter += 1;
        return (counter % 2 == 1);
    }
#else
    return NO;
#endif
}

@implementation LKMCPContextService

- (NSString *)currentSessionId {
    if ([self _isScenarioEnabled:@"LOOKIN_MCP_SCENARIO_NO_SESSION"]) {
        return nil;
    }
    if ([self _isScenarioEnabled:@"LOOKIN_MCP_SCENARIO_SESSION_SWITCH"] && LKMCPShouldDropSessionForSwitchScenario()) {
        return nil;
    }
    LKInspectableApp *app = [LKAppsManager sharedInstance].inspectingApp;
    if (!app) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@", @(app.appInfo.appInfoIdentifier)];
}

- (NSDictionary<NSString *,id> *)healthStructuredContent {
    LKInspectableApp *app = [LKAppsManager sharedInstance].inspectingApp;
    NSMutableDictionary<NSString *, id> *payload = [NSMutableDictionary dictionary];
    payload[@"timestamp"] = [LKMCPError currentTimestampMs];
    if ([self _isScenarioEnabled:@"LOOKIN_MCP_SCENARIO_NO_SESSION"]) {
        payload[@"status"] = @"no_session";
        return payload;
    }
    if ([self _isScenarioEnabled:@"LOOKIN_MCP_SCENARIO_SESSION_SWITCH"] && LKMCPShouldDropSessionForSwitchScenario()) {
        payload[@"status"] = @"no_session";
        return payload;
    }
    if (!app) {
        payload[@"status"] = @"no_session";
        return payload;
    }
    payload[@"status"] = @"ok";
    payload[@"sessionId"] = [NSString stringWithFormat:@"%@", @(app.appInfo.appInfoIdentifier)];
    payload[@"appName"] = app.appInfo.appName ?: @"";
    payload[@"appBundleIdentifier"] = app.appInfo.appBundleIdentifier ?: @"";
    return payload;
}

- (NSDictionary<NSString *,id> *)selectedViewContextWithArguments:(NSDictionary<NSString *,id> *)arguments
                                                             error:(NSError *__autoreleasing  _Nullable *)error {
    NSString *sessionId = [self _validatedSessionIdWithError:error];
    if (sessionId.length == 0) {
        return nil;
    }
    NSInteger childrenDepth = 1;
    if (![self _readNonNegativeIntegerArgument:@"childrenDepth"
                                      arguments:arguments
                                   defaultValue:1
                                       required:NO
                                      sessionId:sessionId
                                       outValue:&childrenDepth
                                          error:error]) {
        return nil;
    }

    LookinDisplayItem *selectedItem = [self _selectedItemWithSessionId:sessionId error:error];
    if (!selectedItem) {
        return nil;
    }
    if (![self _ensureItemSupportsDashboardContext:selectedItem sessionId:sessionId error:error]) {
        return nil;
    }

    NSDictionary<NSString *, id> *response = @{
        @"session": [self _sessionPayloadForSessionId:sessionId],
        @"selectedNode": [self _buildContextPayloadForItem:selectedItem childrenDepth:childrenDepth]
    };
    LKMCPContextLog(@"selected view context generated, sessionId=%@, nodeId=%@, childrenDepth=%@", sessionId, [self _nodeIdForDisplayItem:selectedItem], @(childrenDepth));
    return response;
}

- (NSDictionary<NSString *,id> *)buildHierarchyPayloadByNodeId:(NSString *)nodeId
                                                      arguments:(NSDictionary<NSString *,id> *)arguments
                                                          error:(NSError *__autoreleasing  _Nullable *)error {
    NSString *sessionId = [self _validatedSessionIdWithError:error];
    if (sessionId.length == 0) {
        return nil;
    }
    if (![self _validateAllowedArgumentKeys:[NSSet setWithArray:@[@"nodeId", @"depth"]]
                                  arguments:arguments
                                  sessionId:sessionId
                                      error:error]) {
        return nil;
    }

    NSInteger depth = 1;
    if (![self _readNonNegativeIntegerArgument:@"depth"
                                      arguments:arguments
                                   defaultValue:1
                                       required:NO
                                      sessionId:sessionId
                                       outValue:&depth
                                          error:error]) {
        return nil;
    }
    if (depth > LKMCPHierarchyDepthMax) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:[NSString stringWithFormat:@"depth must be <= %ld.", (long)LKMCPHierarchyDepthMax]
                                   recoverable:YES
                                          hint:[NSString stringWithFormat:@"Use depth in range [0, %ld].", (long)LKMCPHierarchyDepthMax]
                                     sessionId:sessionId];
        }
        return nil;
    }

    NSString *trimmedNodeId = [self _trimmedString:nodeId];
    BOOL startsFromNode = trimmedNodeId.length > 0;
    NSArray<LookinDisplayItem *> *startItems = @[];
    if (startsFromNode) {
        LookinDisplayItem *item = [self _displayItemForNodeId:trimmedNodeId sessionId:sessionId error:error];
        if (!item) {
            return nil;
        }
        startItems = @[item];
    } else {
        NSArray<LookinDisplayItem *> *roots = [LKStaticHierarchyDataSource sharedInstance].rawHierarchyInfo.displayItems;
        if ([roots isKindOfClass:[NSArray class]]) {
            startItems = roots;
        }
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *serializedNodes = [NSMutableArray array];
    for (id itemObj in startItems) {
        if (![itemObj isKindOfClass:[LookinDisplayItem class]]) {
            continue;
        }
        [serializedNodes addObject:[self _buildHierarchyNodePayloadForItem:(LookinDisplayItem *)itemObj remainingDepth:depth]];
    }

    NSMutableDictionary<NSString *, id> *hierarchy = [@{
        @"startFrom": startsFromNode ? @"node" : @"roots",
        @"depth": @(depth),
        @"nodes": serializedNodes
    } mutableCopy];
    if (startsFromNode) {
        hierarchy[@"startNodeId"] = trimmedNodeId;
    }

    NSDictionary<NSString *, id> *response = @{
        @"session": [self _sessionPayloadForSessionId:sessionId],
        @"hierarchy": hierarchy
    };
    LKMCPContextLog(@"hierarchy payload generated, sessionId=%@, startFrom=%@, depth=%@, rootCount=%@", sessionId, hierarchy[@"startFrom"], @(depth), @(serializedNodes.count));
    return response;
}

- (NSDictionary<NSString *,id> *)buildViewContextPayloadByNodeId:(NSString *)nodeId
                                                        arguments:(NSDictionary<NSString *,id> *)arguments
                                                            error:(NSError *__autoreleasing  _Nullable *)error {
    NSString *sessionId = [self _validatedSessionIdWithError:error];
    if (sessionId.length == 0) {
        return nil;
    }
    if (![self _validateAllowedArgumentKeys:[NSSet setWithArray:@[@"nodeId", @"childrenDepth"]]
                                  arguments:arguments
                                  sessionId:sessionId
                                      error:error]) {
        return nil;
    }

    NSString *trimmedNodeId = [self _trimmedString:nodeId];
    if (trimmedNodeId.length == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"nodeId is required."
                                   recoverable:YES
                                          hint:@"Use nodeId as non-empty string."
                                     sessionId:sessionId];
        }
        return nil;
    }

    NSInteger childrenDepth = 1;
    if (![self _readNonNegativeIntegerArgument:@"childrenDepth"
                                      arguments:arguments
                                   defaultValue:1
                                       required:NO
                                      sessionId:sessionId
                                       outValue:&childrenDepth
                                          error:error]) {
        return nil;
    }

    LookinDisplayItem *item = [self _displayItemForNodeId:trimmedNodeId sessionId:sessionId error:error];
    if (!item) {
        return nil;
    }
    if (![self _ensureItemSupportsDashboardContext:item sessionId:sessionId error:error]) {
        return nil;
    }

    NSDictionary<NSString *, id> *response = @{
        @"session": [self _sessionPayloadForSessionId:sessionId],
        @"targetNode": [self _buildContextPayloadForItem:item childrenDepth:childrenDepth]
    };
    LKMCPContextLog(@"context payload generated by nodeId, sessionId=%@, nodeId=%@, childrenDepth=%@", sessionId, trimmedNodeId, @(childrenDepth));
    return response;
}

- (NSDictionary<NSString *,id> *)captureSelectedViewScreenshotWithArguments:(NSDictionary<NSString *,id> *)arguments
                                                                       error:(NSError *__autoreleasing  _Nullable *)error {
    NSString *sessionId = [self _validatedSessionIdWithError:error];
    if (sessionId.length == 0) {
        return nil;
    }
    if (![self _validateAllowedArgumentKeys:[NSSet setWithArray:@[@"format"]]
                                  arguments:arguments
                                  sessionId:sessionId
                                      error:error]) {
        return nil;
    }

    NSString *format = [arguments[@"format"] isKindOfClass:[NSString class]] ? arguments[@"format"] : @"png";
    if (![format isEqualToString:@"png"]) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"Only png format is supported."
                                   recoverable:YES
                                          hint:@"Use format=png."
                                     sessionId:sessionId];
        }
        return nil;
    }
    LookinDisplayItem *selectedItem = [self _selectedItemWithSessionId:sessionId error:error];
    if (!selectedItem) {
        return nil;
    }
    NSDictionary<NSString *, id> *result = [self _captureScreenshotPayloadForItem:selectedItem
                                                                            format:format
                                                                         sessionId:sessionId
                                                                             error:error];
    if (result) {
        LKMCPContextLog(@"selected screenshot captured, sessionId=%@, nodeId=%@", sessionId, result[@"nodeId"] ?: @"");
    }
    return result;
}

- (NSDictionary<NSString *,id> *)captureScreenshotByNodeId:(NSString *)nodeId
                                                  arguments:(NSDictionary<NSString *,id> *)arguments
                                                      error:(NSError *__autoreleasing  _Nullable *)error {
    NSString *sessionId = [self _validatedSessionIdWithError:error];
    if (sessionId.length == 0) {
        return nil;
    }
    if (![self _validateAllowedArgumentKeys:[NSSet setWithArray:@[@"nodeId", @"format"]]
                                  arguments:arguments
                                  sessionId:sessionId
                                      error:error]) {
        return nil;
    }

    NSString *trimmedNodeId = [self _trimmedString:nodeId];
    if (trimmedNodeId.length == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"nodeId is required."
                                   recoverable:YES
                                          hint:@"Use nodeId as non-empty string."
                                     sessionId:sessionId];
        }
        return nil;
    }

    NSString *format = [arguments[@"format"] isKindOfClass:[NSString class]] ? arguments[@"format"] : @"png";
    if (![format isEqualToString:@"png"]) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"Only png format is supported."
                                   recoverable:YES
                                          hint:@"Use format=png."
                                     sessionId:sessionId];
        }
        return nil;
    }

    LookinDisplayItem *item = [self _displayItemForNodeId:trimmedNodeId sessionId:sessionId error:error];
    if (!item) {
        return nil;
    }
    NSDictionary<NSString *, id> *result = [self _captureScreenshotPayloadForItem:item
                                                                            format:format
                                                                         sessionId:sessionId
                                                                             error:error];
    if (result) {
        LKMCPContextLog(@"screenshot captured by nodeId, sessionId=%@, nodeId=%@", sessionId, trimmedNodeId);
    }
    return result;
}

- (NSString *)_validatedSessionIdWithError:(NSError *__autoreleasing _Nullable *)error {
    NSString *sessionId = [self currentSessionId];
    if (sessionId.length > 0) {
        return sessionId;
    }
    if (error) {
        *error = [LKMCPError errorWithCode:LKMCPErrorCodeNoSession
                                   message:@"No active inspectable app session."
                               recoverable:YES
                                      hint:@"Connect an app in Lookin, then retry."
                                 sessionId:nil];
    }
    return nil;
}

- (NSDictionary<NSString *, id> *)_sessionPayloadForSessionId:(NSString *)sessionId {
    LKInspectableApp *app = [LKAppsManager sharedInstance].inspectingApp;
    return @{
        @"sessionId": sessionId ?: @"",
        @"appName": app.appInfo.appName ?: @"",
        @"appBundleIdentifier": app.appInfo.appBundleIdentifier ?: @"",
        @"timestamp": [LKMCPError currentTimestampMs]
    };
}

- (NSString *)_trimmedString:(NSString *)string {
    if (![string isKindOfClass:[NSString class]]) {
        return @"";
    }
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)_validateAllowedArgumentKeys:(NSSet<NSString *> *)allowedKeys
                           arguments:(NSDictionary<NSString *, id> *)arguments
                           sessionId:(NSString *)sessionId
                               error:(NSError *__autoreleasing _Nullable *)error {
    __block NSString *invalidKey = nil;
    [arguments enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (![key isKindOfClass:[NSString class]] || ![allowedKeys containsObject:key]) {
            invalidKey = [key isKindOfClass:[NSString class]] ? key : @"<non-string-key>";
            *stop = YES;
        }
        (void)obj;
    }];
    if (invalidKey.length == 0) {
        return YES;
    }
    if (error) {
        *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                   message:[NSString stringWithFormat:@"Unknown argument: %@.", invalidKey]
                               recoverable:YES
                                      hint:[NSString stringWithFormat:@"Allowed keys: %@.", [[allowedKeys allObjects] componentsJoinedByString:@", "]]
                                 sessionId:sessionId];
    }
    return NO;
}

- (BOOL)_readNonNegativeIntegerArgument:(NSString *)key
                              arguments:(NSDictionary<NSString *, id> *)arguments
                           defaultValue:(NSInteger)defaultValue
                               required:(BOOL)required
                              sessionId:(NSString *)sessionId
                               outValue:(NSInteger *)outValue
                                  error:(NSError *__autoreleasing _Nullable *)error {
    id rawValue = arguments[key];
    if (rawValue == nil) {
        if (required) {
            if (error) {
                *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                           message:[NSString stringWithFormat:@"%@ is required.", key]
                                       recoverable:YES
                                              hint:[NSString stringWithFormat:@"Use %@ as integer >= 0.", key]
                                         sessionId:sessionId];
            }
            return NO;
        }
        if (outValue) {
            *outValue = defaultValue;
        }
        return YES;
    }
    if (![rawValue isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:[NSString stringWithFormat:@"%@ must be integer.", key]
                                   recoverable:YES
                                          hint:[NSString stringWithFormat:@"Use %@ as integer >= 0.", key]
                                     sessionId:sessionId];
        }
        return NO;
    }
    double doubleValue = [rawValue doubleValue];
    if (floor(doubleValue) != doubleValue) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:[NSString stringWithFormat:@"%@ must be integer.", key]
                                   recoverable:YES
                                          hint:[NSString stringWithFormat:@"Use %@ as integer >= 0.", key]
                                     sessionId:sessionId];
        }
        return NO;
    }
    NSInteger value = [rawValue integerValue];
    if (value < 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:[NSString stringWithFormat:@"%@ must be >= 0.", key]
                                   recoverable:YES
                                          hint:[NSString stringWithFormat:@"Use %@ as integer >= 0.", key]
                                     sessionId:sessionId];
        }
        return NO;
    }
    if (outValue) {
        *outValue = value;
    }
    return YES;
}

- (LookinDisplayItem *)_selectedItemWithSessionId:(NSString *)sessionId
                                             error:(NSError *__autoreleasing _Nullable *)error {
    if ([self _isScenarioEnabled:@"LOOKIN_MCP_SCENARIO_NO_SELECTION"]) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeNoSelection
                                       message:@"No selected view in current session."
                                   recoverable:YES
                                          hint:@"Please select a view in Lookin and retry."
                                     sessionId:sessionId];
        }
        return nil;
    }
    LookinDisplayItem *selectedItem = [LKStaticHierarchyDataSource sharedInstance].selectedItem;
    if (selectedItem) {
        return selectedItem;
    }
    if (error) {
        *error = [LKMCPError errorWithCode:LKMCPErrorCodeNoSelection
                                   message:@"No selected view in current session."
                               recoverable:YES
                                      hint:@"Please select a view in Lookin and retry."
                                 sessionId:sessionId];
    }
    return nil;
}

- (BOOL)_ensureItemSupportsDashboardContext:(LookinDisplayItem *)item
                                  sessionId:(NSString *)sessionId
                                      error:(NSError *__autoreleasing _Nullable *)error {
    if (!item.customInfo && [item queryAllAttrGroupList].count > 0) {
        return YES;
    }
    if (error) {
        *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                   message:@"Target node does not support full dashboard context."
                               recoverable:YES
                                      hint:@"Select a regular UIKit view node and retry."
                                 sessionId:sessionId];
    }
    LKMCPContextLog(@"node rejected for context, nodeId=%@, reason=unsupported-dashboard-context", [self _nodeIdForDisplayItem:item]);
    return NO;
}

- (LookinDisplayItem *)_displayItemForNodeId:(NSString *)nodeId
                                    sessionId:(NSString *)sessionId
                                        error:(NSError *__autoreleasing _Nullable *)error {
    NSString *trimmedNodeId = [self _trimmedString:nodeId];
    if (trimmedNodeId.length == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"nodeId is required."
                                   recoverable:YES
                                          hint:@"Use nodeId as non-empty string."
                                     sessionId:sessionId];
        }
        return nil;
    }
    unsigned long oid = 0;
    if (![self _parseDisplayOidFromNodeId:trimmedNodeId oid:&oid sessionId:sessionId error:error]) {
        return nil;
    }
    LookinDisplayItem *item = [[LKStaticHierarchyDataSource sharedInstance] displayItemWithOid:oid];
    if (item) {
        return item;
    }
    if (error) {
        *error = [LKMCPError errorWithCode:LKMCPErrorCodeNodeNotFound
                                   message:[NSString stringWithFormat:@"Node not found for nodeId=%@.", trimmedNodeId]
                               recoverable:YES
                                      hint:@"Refresh hierarchy and use nodeId returned by context/hierarchy tool."
                                 sessionId:sessionId];
    }
    return nil;
}

- (BOOL)_parseDisplayOidFromNodeId:(NSString *)nodeId
                               oid:(unsigned long *)oid
                         sessionId:(NSString *)sessionId
                             error:(NSError *__autoreleasing _Nullable *)error {
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([nodeId rangeOfCharacterFromSet:nonDigits].location != NSNotFound) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"nodeId must be an unsigned integer string."
                                   recoverable:YES
                                          hint:@"Use nodeId returned by Lookin MCP tools."
                                     sessionId:sessionId];
        }
        return NO;
    }
    unsigned long long parsed = strtoull(nodeId.UTF8String, NULL, 10);
    if (parsed > ULONG_MAX) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"nodeId value is out of range."
                                   recoverable:YES
                                          hint:@"Use nodeId returned by Lookin MCP tools."
                                     sessionId:sessionId];
        }
        return NO;
    }
    if (oid) {
        *oid = (unsigned long)parsed;
    }
    return YES;
}

- (NSDictionary<NSString *, id> *)_buildHierarchyNodePayloadForItem:(LookinDisplayItem *)item
                                                      remainingDepth:(NSInteger)remainingDepth {
    NSMutableArray<NSDictionary<NSString *, id> *> *children = [NSMutableArray array];
    BOOL hasChildren = NO;
    for (id childObj in item.subitems) {
        if (![childObj isKindOfClass:[LookinDisplayItem class]]) {
            continue;
        }
        hasChildren = YES;
        if (remainingDepth > 0) {
            [children addObject:[self _buildHierarchyNodePayloadForItem:(LookinDisplayItem *)childObj
                                                           remainingDepth:remainingDepth - 1]];
        }
    }
    return @{
        @"nodeId": [self _nodeIdForDisplayItem:item],
        @"className": [item title] ?: @"",
        @"ivarNameOfParent": [item subtitle] ?: @"",
        @"hasChildren": @(hasChildren),
        @"children": children
    };
}

- (NSDictionary<NSString *, id> *)_captureScreenshotPayloadForItem:(LookinDisplayItem *)item
                                                             format:(NSString *)format
                                                          sessionId:(NSString *)sessionId
                                                              error:(NSError *__autoreleasing _Nullable *)error {
    (void)format;
    if ([self _isScenarioEnabled:@"LOOKIN_MCP_SCENARIO_SCREENSHOT_FAIL"]) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeScreenshotFailed
                                       message:@"Failed to write screenshot file."
                                   recoverable:YES
                                          hint:@"Check cache directory permission and retry."
                                     sessionId:sessionId];
        }
        return nil;
    }

    NSImage *image = item.groupScreenshot;
    if (!image) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeScreenshotFailed
                                       message:@"Target node has no screenshot."
                                   recoverable:YES
                                          hint:@"Refresh hierarchy and retry."
                                     sessionId:sessionId];
        }
        return nil;
    }

    NSData *tiffData = image.TIFFRepresentation;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:tiffData];
    NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (pngData.length == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeScreenshotFailed
                                       message:@"Failed to encode screenshot as PNG."
                                   recoverable:YES
                                          hint:@"Refresh hierarchy and retry."
                                     sessionId:sessionId];
        }
        return nil;
    }

    NSString *cacheRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"lookin-mcp-screenshots"];
    NSError *createError = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheRoot withIntermediateDirectories:YES attributes:nil error:&createError];
    if (createError) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeScreenshotFailed
                                       message:@"Failed to prepare screenshot directory."
                                   recoverable:YES
                                          hint:@"Check writable cache directory permission."
                                     sessionId:sessionId];
        }
        LKMCPContextLog(@"screenshot failed to create cache directory, error=%@", createError.localizedDescription ?: @"");
        return nil;
    }

    NSString *nodeId = [self _nodeIdForDisplayItem:item];
    NSNumber *timestamp = [LKMCPError currentTimestampMs];
    NSString *filePath = [cacheRoot stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@.png", nodeId, timestamp]];
    NSError *writeError = nil;
    BOOL writeOK = [pngData writeToFile:filePath options:NSDataWritingAtomic error:&writeError];
    if (!writeOK || writeError) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeScreenshotFailed
                                       message:@"Failed to write screenshot file."
                                   recoverable:YES
                                          hint:@"Check cache directory permission and retry."
                                     sessionId:sessionId];
        }
        LKMCPContextLog(@"screenshot write failed, path=%@, error=%@", filePath ?: @"", writeError.localizedDescription ?: @"");
        return nil;
    }

    return @{
        @"sessionId": sessionId,
        @"nodeId": nodeId,
        @"path": filePath,
        @"width": @((NSInteger)image.size.width),
        @"height": @((NSInteger)image.size.height),
        @"format": @"png",
        @"timestamp": timestamp
    };
}

- (BOOL)_isScenarioEnabled:(NSString *)flagName {
#if DEBUG
    id override = [self lk_scenarioOverrideForFlag:flagName];
    if (override != nil) {
        LKMCPContextLog(@"scenario override hit, %@=%@", flagName, override);
    }
    if ([override isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)override boolValue];
    }
    if ([override isKindOfClass:[NSString class]]) {
        NSString *raw = [(NSString *)override lowercaseString];
        if (raw.length > 0) {
            static NSSet<NSString *> *truthyValues = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken,^{
                truthyValues = [NSSet setWithArray:@[@"1", @"true", @"yes", @"on"]];
            });
            return [truthyValues containsObject:raw];
        }
    }
#endif
    return LKMCPScenarioFlagEnabled(flagName);
}

- (NSDictionary<NSString *, id> *)_buildContextPayloadForItem:(LookinDisplayItem *)item
                                                 childrenDepth:(NSInteger)childrenDepth {
    NSMutableDictionary<NSString *, id> *node = [NSMutableDictionary dictionary];
    node[@"identity"] = [self _identityForDisplayItem:item];
    node[@"iosRaw"] = [self _iosRawForDisplayItem:item];
    node[@"dashboard"] = [self _dashboardForDisplayItem:item];

    NSMutableDictionary<NSString *, id> *structureHints = [NSMutableDictionary dictionary];
    if (item.superItem) {
        structureHints[@"parent"] = [self _hintNodeForDisplayItem:item.superItem includeSubitemCount:NO];
    }

    if (childrenDepth > 0) {
        NSMutableArray<NSDictionary *> *children = [NSMutableArray array];
        [item.subitems enumerateObjectsUsingBlock:^(LookinDisplayItem *child, NSUInteger idx, BOOL *stop) {
            [children addObject:[self _hintNodeForDisplayItem:child includeSubitemCount:YES]];
        }];
        structureHints[@"childrenSummary"] = children;
    } else {
        structureHints[@"childrenSummary"] = @[];
    }
    node[@"structureHints"] = structureHints;
    return node;
}

- (NSDictionary<NSString *, id> *)_identityForDisplayItem:(LookinDisplayItem *)item {
    LookinObject *displaying = [item displayingObject];
    NSMutableDictionary<NSString *, id> *identity = [NSMutableDictionary dictionary];
    identity[@"nodeId"] = [self _nodeIdForDisplayItem:item];
    if (item.viewObject) {
        identity[@"viewOid"] = @(item.viewObject.oid);
    }
    if (item.layerObject) {
        identity[@"layerOid"] = @(item.layerObject.oid);
    }
    if (!item.viewObject && !item.layerObject && displaying) {
        identity[@"layerOid"] = @(displaying.oid);
    }
    return identity;
}

- (NSDictionary<NSString *, id> *)_iosRawForDisplayItem:(LookinDisplayItem *)item {
    LookinObject *obj = [item displayingObject];
    NSMutableDictionary<NSString *, id> *raw = [NSMutableDictionary dictionary];
    raw[@"classChainList"] = obj.classChainList ?: @[];
    raw[@"rawClassName"] = obj.rawClassName ?: @"";
    raw[@"memoryAddress"] = obj.memoryAddress ?: @"";
    raw[@"frame"] = [self _frameDict:item.frame];
    raw[@"bounds"] = [self _frameDict:item.bounds];
    raw[@"isHidden"] = @(item.isHidden);
    raw[@"alpha"] = @(item.alpha);
    raw[@"representedAsKeyWindow"] = @(item.representedAsKeyWindow);
    if (item.hostViewControllerObject.rawClassName.length > 0) {
        raw[@"hostViewControllerClassName"] = item.hostViewControllerObject.rawClassName;
    }
    if (obj.specialTrace.length > 0) {
        raw[@"specialTrace"] = obj.specialTrace;
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *ivarTraces = [NSMutableArray array];
    [obj.ivarTraces enumerateObjectsUsingBlock:^(id trace, NSUInteger idx, BOOL *stop) {
        NSString *relation = [self _stringForValue:[trace valueForKey:@"relation"]];
        NSString *hostClassName = [self _stringForValue:[trace valueForKey:@"hostClassName"]];
        NSString *ivarName = [self _stringForValue:[trace valueForKey:@"ivarName"]];
        if (relation.length == 0 && hostClassName.length == 0 && ivarName.length == 0) {
            return;
        }
        [ivarTraces addObject:@{
            @"relation": relation ?: @"",
            @"hostClassName": hostClassName ?: @"",
            @"ivarName": ivarName ?: @""
        }];
    }];
    raw[@"ivarTraces"] = ivarTraces;
    return raw;
}

- (NSDictionary<NSString *, id> *)_dashboardForDisplayItem:(LookinDisplayItem *)item {
    // Dashboard-first: keep output shape aligned with right-side Dashboard cards.
    NSMutableArray<NSDictionary<NSString *, id> *> *groups = [NSMutableArray array];
    NSArray<LookinAttributesGroup *> *allGroups = [item queryAllAttrGroupList];
    [allGroups enumerateObjectsUsingBlock:^(LookinAttributesGroup *group, NSUInteger idx, BOOL *stop) {
        NSMutableArray<NSDictionary<NSString *, id> *> *sections = [NSMutableArray array];
        [group.attrSections enumerateObjectsUsingBlock:^(LookinAttributesSection *section, NSUInteger secIdx, BOOL *secStop) {
            NSMutableArray<NSDictionary<NSString *, id> *> *attrs = [NSMutableArray array];
            [section.attributes enumerateObjectsUsingBlock:^(LookinAttribute *attr, NSUInteger attrIdx, BOOL *attrStop) {
                NSMutableDictionary<NSString *, id> *attrData = [NSMutableDictionary dictionary];
                attrData[@"attrIdentifier"] = attr.identifier ?: @"";
                attrData[@"attrTitle"] = [self _resolveAttrTitleForAttribute:attr];
                if (attr.displayTitle.length > 0) {
                    attrData[@"displayTitle"] = attr.displayTitle;
                }
                attrData[@"value"] = [self _jsonSafeValue:attr.value];
                attrData[@"extraValue"] = [self _jsonSafeValue:attr.extraValue];
                [attrs addObject:attrData];
            }];
            [sections addObject:@{
                @"sectionIdentifier": section.identifier ?: @"",
                @"sectionTitle": [self _resolveSectionTitleForSection:section],
                @"isUserCustom": @([section isUserCustom]),
                @"attributes": attrs
            }];
        }];

        [groups addObject:@{
            @"groupIdentifier": group.identifier ?: @"",
            @"groupTitle": [self _resolveGroupTitleForGroup:group],
            @"isUserCustom": @([group isUserCustom]),
            @"sections": sections
        }];
    }];
    return @{@"groups": groups};
}

- (NSString *)_resolveGroupTitleForGroup:(LookinAttributesGroup *)group {
    if (group.userCustomTitle.length > 0) {
        return group.userCustomTitle;
    }
    NSString *resolved = [LookinDashboardBlueprint groupTitleWithGroupID:group.identifier];
    if (resolved.length > 0) {
        return resolved;
    }
    return group.identifier ?: @"";
}

- (NSString *)_resolveSectionTitleForSection:(LookinAttributesSection *)section {
    if (![section isUserCustom]) {
        NSString *resolved = [LookinDashboardBlueprint sectionTitleWithSectionID:section.identifier];
        if (resolved.length > 0) {
            return resolved;
        }
        return section.identifier ?: @"";
    }
    LookinAttribute *attr = section.attributes.firstObject;
    if (attr.displayTitle.length > 0) {
        return attr.displayTitle;
    }
    return section.identifier ?: @"";
}

- (NSString *)_resolveAttrTitleForAttribute:(LookinAttribute *)attr {
    if (attr.displayTitle.length > 0) {
        return attr.displayTitle;
    }
    NSString *resolved = [LookinDashboardBlueprint fullTitleWithAttrID:attr.identifier];
    if (resolved.length > 0) {
        return resolved;
    }
    return attr.identifier ?: @"";
}

- (NSDictionary<NSString *, id> *)_hintNodeForDisplayItem:(LookinDisplayItem *)item includeSubitemCount:(BOOL)includeSubitemCount {
    NSMutableDictionary<NSString *, id> *hint = [NSMutableDictionary dictionary];
    hint[@"nodeId"] = [self _nodeIdForDisplayItem:item];
    hint[@"className"] = [item displayingObject].rawClassName ?: @"";
    hint[@"frame"] = [self _frameDict:item.frame];
    if (includeSubitemCount) {
        hint[@"subitemCount"] = @(item.subitems.count);
    }
    return hint;
}

- (NSDictionary<NSString *, NSNumber *> *)_frameDict:(CGRect)frame {
    return @{
        @"x": @(frame.origin.x),
        @"y": @(frame.origin.y),
        @"width": @(frame.size.width),
        @"height": @(frame.size.height)
    };
}

- (NSString *)_nodeIdForDisplayItem:(LookinDisplayItem *)item {
    if (item.viewObject) {
        return [NSString stringWithFormat:@"%@", @(item.viewObject.oid)];
    }
    if (item.layerObject) {
        return [NSString stringWithFormat:@"%@", @(item.layerObject.oid)];
    }
    LookinObject *displaying = [item displayingObject];
    return [NSString stringWithFormat:@"%@", @(displaying.oid)];
}

- (id)_jsonSafeValue:(id)value {
    if (!value) {
        return [NSNull null];
    }
    if ([value isKindOfClass:[LookinAutoLayoutConstraint class]]) {
        // AutoLayout constraints are structured instead of plain description text.
        return [self _jsonSafeConstraint:(LookinAutoLayoutConstraint *)value];
    }
    if ([value isKindOfClass:[NSString class]] ||
        [value isKindOfClass:[NSNumber class]] ||
        [value isKindOfClass:[NSNull class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [NSMutableArray array];
        for (id obj in (NSArray *)value) {
            [array addObject:[self _jsonSafeValue:obj]];
        }
        return array;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSString *safeKey = [key isKindOfClass:[NSString class]] ? key : [key description];
            dict[safeKey] = [self _jsonSafeValue:obj];
        }];
        return dict;
    }
    return [value description] ?: @"";
}

- (NSDictionary<NSString *, id> *)_jsonSafeConstraint:(LookinAutoLayoutConstraint *)constraint {
    NSString *firstItemText = [LookinAutoLayoutConstraint descriptionWithItemObject:constraint.firstItem
                                                                                type:constraint.firstItemType
                                                                            detailed:NO] ?: @"";
    NSString *firstAttrText = [LookinAutoLayoutConstraint descriptionWithAttributeInt:constraint.firstAttribute] ?: @"";
    NSString *relationSymbol = [LookinAutoLayoutConstraint symbolWithRelation:constraint.relation] ?: @"?";
    NSString *relationText = [LookinAutoLayoutConstraint descriptionWithRelation:constraint.relation] ?: @"Unknown";

    NSMutableDictionary<NSString *, id> *payload = [NSMutableDictionary dictionary];
    payload[@"expression"] = [self _constraintExpression:constraint
                                           firstItemText:firstItemText
                                           firstAttrText:firstAttrText
                                          relationSymbol:relationSymbol];
    payload[@"effective"] = @(constraint.effective);
    payload[@"active"] = @(constraint.active);
    payload[@"shouldBeArchived"] = @(constraint.shouldBeArchived);
    payload[@"multiplier"] = @(constraint.multiplier);
    payload[@"constant"] = @(constraint.constant);
    payload[@"priority"] = @(constraint.priority);
    payload[@"firstItem"] = @{
        @"typeRawValue": @(constraint.firstItemType),
        @"type": [self _constraintItemTypeText:constraint.firstItemType],
        @"description": firstItemText,
        @"nodeId": constraint.firstItem ? [NSString stringWithFormat:@"%@", @(constraint.firstItem.oid)] : @"",
        @"className": constraint.firstItem.rawClassName ?: @""
    };
    payload[@"firstAttribute"] = @{
        @"rawValue": @(constraint.firstAttribute),
        @"name": firstAttrText
    };
    payload[@"relation"] = @{
        @"rawValue": @(constraint.relation),
        @"symbol": relationSymbol,
        @"name": relationText
    };

    NSString *secondAttrText = [LookinAutoLayoutConstraint descriptionWithAttributeInt:constraint.secondAttribute] ?: @"";
    if (constraint.secondAttribute == 0) {
        payload[@"secondItem"] = [NSNull null];
        payload[@"secondAttribute"] = @{
            @"rawValue": @(constraint.secondAttribute),
            @"name": secondAttrText
        };
    } else {
        NSString *secondItemText = [LookinAutoLayoutConstraint descriptionWithItemObject:constraint.secondItem
                                                                                     type:constraint.secondItemType
                                                                                 detailed:NO] ?: @"";
        payload[@"secondItem"] = @{
            @"typeRawValue": @(constraint.secondItemType),
            @"type": [self _constraintItemTypeText:constraint.secondItemType],
            @"description": secondItemText,
            @"nodeId": constraint.secondItem ? [NSString stringWithFormat:@"%@", @(constraint.secondItem.oid)] : @"",
            @"className": constraint.secondItem.rawClassName ?: @""
        };
        payload[@"secondAttribute"] = @{
            @"rawValue": @(constraint.secondAttribute),
            @"name": secondAttrText
        };
    }
    if (constraint.identifier.length > 0) {
        payload[@"identifier"] = constraint.identifier;
    }
    return payload;
}

- (NSString *)_constraintExpression:(LookinAutoLayoutConstraint *)constraint
                      firstItemText:(NSString *)firstItemText
                      firstAttrText:(NSString *)firstAttrText
                     relationSymbol:(NSString *)relationSymbol {
    NSMutableString *result = [NSMutableString string];
    [result appendFormat:@"%@.%@ %@", firstItemText, firstAttrText, relationSymbol];

    if (constraint.secondAttribute == 0) {
        [result appendFormat:@" %@", @(constraint.constant)];
    } else {
        NSString *secondItemText = [LookinAutoLayoutConstraint descriptionWithItemObject:constraint.secondItem
                                                                                     type:constraint.secondItemType
                                                                                 detailed:NO] ?: @"";
        NSString *secondAttrText = [LookinAutoLayoutConstraint descriptionWithAttributeInt:constraint.secondAttribute] ?: @"";
        [result appendFormat:@" %@.%@", secondItemText, secondAttrText];
        if (constraint.multiplier != 1) {
            [result appendFormat:@" * %@", @(constraint.multiplier)];
        }
        if (constraint.constant > 0) {
            [result appendFormat:@" + %@", @(constraint.constant)];
        } else if (constraint.constant < 0) {
            [result appendFormat:@" - %@", @(-constraint.constant)];
        }
    }

    if (constraint.priority != 1000) {
        [result appendFormat:@" @ %@", @(constraint.priority)];
    }
    return result;
}

- (NSString *)_constraintItemTypeText:(LookinConstraintItemType)type {
    switch (type) {
        case LookinConstraintItemTypeUnknown:
            return @"unknown";
        case LookinConstraintItemTypeNil:
            return @"nil";
        case LookinConstraintItemTypeView:
            return @"view";
        case LookinConstraintItemTypeSelf:
            return @"self";
        case LookinConstraintItemTypeSuper:
            return @"super";
        case LookinConstraintItemTypeLayoutGuide:
            return @"layoutGuide";
    }
}

- (NSString *)_stringForValue:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    if ([value respondsToSelector:@selector(description)]) {
        return [value description];
    }
    return @"";
}

@end
