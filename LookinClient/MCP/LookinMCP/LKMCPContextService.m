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
@import AppKit;

@interface LKMCPContextService ()

@end

@implementation LKMCPContextService

- (NSString *)currentSessionId {
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
    NSString *sessionId = [self currentSessionId];
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

    NSInteger childrenDepth = 1;
    id depthObj = arguments[@"childrenDepth"];
    if (depthObj != nil) {
        if (![depthObj isKindOfClass:[NSNumber class]]) {
            if (error) {
                *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                           message:@"childrenDepth must be integer."
                                       recoverable:YES
                                              hint:@"Use childrenDepth >= 0."
                                         sessionId:sessionId];
            }
            return nil;
        }
        childrenDepth = [depthObj integerValue];
        if (childrenDepth < 0) {
            if (error) {
                *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                           message:@"childrenDepth must be >= 0."
                                       recoverable:YES
                                              hint:@"Use childrenDepth >= 0."
                                         sessionId:sessionId];
            }
            return nil;
        }
    }

    LookinDisplayItem *selectedItem = [LKStaticHierarchyDataSource sharedInstance].selectedItem;
    if (!selectedItem) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeNoSelection
                                       message:@"No selected view in current session."
                                   recoverable:YES
                                          hint:@"Please select a view in Lookin and retry."
                                     sessionId:sessionId];
        }
        return nil;
    }
    if (selectedItem.customInfo || [selectedItem queryAllAttrGroupList].count == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"Selected node does not support full dashboard context."
                                   recoverable:YES
                                          hint:@"Select a regular UIKit view node and retry."
                                     sessionId:sessionId];
        }
        return nil;
    }

    LKInspectableApp *app = [LKAppsManager sharedInstance].inspectingApp;
    NSMutableDictionary<NSString *, id> *response = [NSMutableDictionary dictionary];
    response[@"session"] = @{
        @"sessionId": sessionId,
        @"appName": app.appInfo.appName ?: @"",
        @"appBundleIdentifier": app.appInfo.appBundleIdentifier ?: @"",
        @"timestamp": [LKMCPError currentTimestampMs]
    };
    response[@"selectedNode"] = [self _buildSelectedNode:selectedItem childrenDepth:childrenDepth];
    return response;
}

- (NSDictionary<NSString *,id> *)captureSelectedViewScreenshotWithArguments:(NSDictionary<NSString *,id> *)arguments
                                                                       error:(NSError *__autoreleasing  _Nullable *)error {
    NSString *sessionId = [self currentSessionId];
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
    if (arguments[@"highlightSelectedRegion"] && ![arguments[@"highlightSelectedRegion"] isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"highlightSelectedRegion must be boolean."
                                   recoverable:YES
                                          hint:@"Use true/false for highlightSelectedRegion."
                                     sessionId:sessionId];
        }
        return nil;
    }
    if (arguments[@"scale"]) {
        if (![arguments[@"scale"] isKindOfClass:[NSNumber class]] || [arguments[@"scale"] doubleValue] <= 0) {
            if (error) {
                *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                           message:@"scale must be a positive number."
                                       recoverable:YES
                                              hint:@"Use scale > 0."
                                         sessionId:sessionId];
            }
            return nil;
        }
    }

    LookinDisplayItem *selectedItem = [LKStaticHierarchyDataSource sharedInstance].selectedItem;
    if (!selectedItem) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeNoSelection
                                       message:@"No selected view in current session."
                                   recoverable:YES
                                          hint:@"Please select a view in Lookin and retry."
                                     sessionId:sessionId];
        }
        return nil;
    }

    NSImage *image = selectedItem.groupScreenshot;
    if (!image) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeScreenshotFailed
                                       message:@"Selected node has no screenshot."
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
        return nil;
    }

    NSString *nodeId = [self _nodeIdForDisplayItem:selectedItem];
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

- (NSDictionary<NSString *, id> *)_buildSelectedNode:(LookinDisplayItem *)item childrenDepth:(NSInteger)childrenDepth {
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
