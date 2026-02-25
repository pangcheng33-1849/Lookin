//
//  LKRequirementCodeInfoMenuHelper.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKRequirementCodeInfoMenuHelper.h"
#import "LKHierarchyDataSource.h"
#import "LookinDisplayItem.h"
#import "LKRequirementBindingStore.h"
#import "LKMCPNotifications.h"
#import "LKAppsManager.h"
#import "LKInspectableApp.h"
#import "LookinAppInfo.h"
#import "LookinHierarchyInfo.h"
#import "LookinAttrIdentifiers.h"
#import "LookinAttributesGroup.h"
#import "LookinAttributesSection.h"
#import "LookinAttribute.h"
#import "Lookin-Swift.h"
#define LKMCPCodeInfoMenuLog(fmt, ...) NSLog((@"[LookinMCP][CodeInfoMenu] " fmt), ##__VA_ARGS__)

static NSString * const LKMCPCodeInfoMenuPayloadRequirementId = @"requirementId";
static NSString * const LKMCPCodeInfoMenuPayloadDisplayItem = @"displayItem";
static NSString * const LKMCPDisableCodeInfoMenuDefaultsKey = @"mcp_disable_code_info_menu";
static NSString * const LKMCPDisableCodeInfoBoardDefaultsKey = @"mcp_disable_code_info_board";

static BOOL LKMCPFlagEnabled(NSString *envName, NSString *defaultsKey) {
    NSString *raw = [[NSProcessInfo processInfo].environment[envName] lowercaseString];
    if (raw.length == 0) {
        raw = [[[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey] respondsToSelector:@selector(stringValue)]
            ? [[[[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey] stringValue] lowercaseString]
            : @"";
    }
    if (raw.length == 0) {
        return NO;
    }
    static NSSet<NSString *> *truthy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        truthy = [NSSet setWithArray:@[@"1", @"true", @"yes", @"on"]];
    });
    return [truthy containsObject:raw];
}

@implementation LKRequirementCodeInfoMenuHelper

+ (void)appendCodeInfoMenuToMenu:(NSMenu *)menu
                     displayItem:(LookinDisplayItem *)displayItem
                      dataSource:(LKHierarchyDataSource *)dataSource
                          target:(id)target
                 openBoardAction:(SEL)openBoardAction
               addCodeInfoAction:(SEL)addCodeInfoAction {
    if (LKMCPFlagEnabled(@"LOOKIN_MCP_DISABLE_CODE_INFO_MENU", LKMCPDisableCodeInfoMenuDefaultsKey)) {
        LKMCPCodeInfoMenuLog(@"menu injection skipped by feature flag");
        return;
    }
    if (!displayItem) {
        return;
    }
    if (menu.itemArray.count > 0 && !menu.itemArray.lastObject.isSeparatorItem) {
        [menu addItem:[NSMenuItem separatorItem]];
    }

    NSMenuItem *rootItem = [NSMenuItem new];
    rootItem.title = NSLocalizedString(@"Code Info", nil);

    NSMenu *submenu = [NSMenu new];
    submenu.autoenablesItems = YES;
    rootItem.submenu = submenu;

    [submenu addItem:({
        NSMenuItem *openBoardItem = [NSMenuItem new];
        openBoardItem.title = NSLocalizedString(@"Open Code Info Board…", nil);
        openBoardItem.target = target;
        openBoardItem.action = openBoardAction;
        openBoardItem;
    })];

    NSString *sessionId = [self _sessionIdFromDataSource:dataSource];
    NSArray<LKRequirementCodeInfoRecord *> *records = sessionId.length > 0 ? [[LKRequirementCodeInfoStore sharedInstance] recordModelsForSessionId:sessionId] : @[];

    [submenu addItem:[NSMenuItem separatorItem]];
    if (records.count == 0) {
        [submenu addItem:({
            NSMenuItem *emptyItem = [NSMenuItem new];
            emptyItem.title = NSLocalizedString(@"No requirement items. Call set_requirement_items first.", nil);
            emptyItem.enabled = NO;
            emptyItem;
        })];
    } else {
        [records enumerateObjectsUsingBlock:^(LKRequirementCodeInfoRecord *record, NSUInteger idx, BOOL *stop) {
            NSString *rid = record.requirementId ?: @"";
            NSString *desc = record.itemDescription ?: @"";
            NSString *title = desc.length > 0 ? [NSString stringWithFormat:@"%@-%@", rid, desc] : rid;
            [submenu addItem:({
                NSMenuItem *item = [NSMenuItem new];
                item.title = [NSString stringWithFormat:NSLocalizedString(@"add code info to item<%@>", nil), title];
                item.target = target;
                item.action = addCodeInfoAction;
                item.enabled = (rid.length > 0);
                item.representedObject = @{
                    LKMCPCodeInfoMenuPayloadRequirementId: rid ?: @"",
                    LKMCPCodeInfoMenuPayloadDisplayItem: displayItem
                };
                item;
            })];
        }];
    }

    [menu addItem:rootItem];
}

+ (void)openCodeInfoBoardForDataSource:(LKHierarchyDataSource *)dataSource {
    if (LKMCPFlagEnabled(@"LOOKIN_MCP_DISABLE_CODE_INFO_BOARD", LKMCPDisableCodeInfoBoardDefaultsKey)) {
        LKMCPCodeInfoMenuLog(@"open board skipped by feature flag");
        return;
    }
    NSString *sessionId = [self _sessionIdFromDataSource:dataSource] ?: @"";
    [[LKRequirementCodeInfoStore sharedInstance] showRequirementCodeInfoBoardForSessionId:sessionId];
}

+ (BOOL)addCodeInfoFromMenuItem:(NSMenuItem *)menuItem
                      dataSource:(LKHierarchyDataSource *)dataSource {
    NSDictionary *payload = [menuItem.representedObject isKindOfClass:[NSDictionary class]] ? (NSDictionary *)menuItem.representedObject : nil;
    NSString *requirementId = [payload[LKMCPCodeInfoMenuPayloadRequirementId] isKindOfClass:[NSString class]] ? payload[LKMCPCodeInfoMenuPayloadRequirementId] : @"";
    LookinDisplayItem *displayItem = [payload[LKMCPCodeInfoMenuPayloadDisplayItem] isKindOfClass:[LookinDisplayItem class]] ? payload[LKMCPCodeInfoMenuPayloadDisplayItem] : nil;
    if (requirementId.length == 0 || !displayItem) {
        LKMCPCodeInfoMenuLog(@"add code info aborted: invalid payload");
        return NO;
    }

    NSString *sessionId = [self _sessionIdFromDataSource:dataSource];
    if (sessionId.length == 0) {
        LKMCPCodeInfoMenuLog(@"add code info aborted: missing session");
        return NO;
    }

    NSString *codeInfo = [self _generatedCodeInfoTextFromDisplayItem:displayItem];
    if (codeInfo.length == 0) {
        LKMCPCodeInfoMenuLog(@"add code info aborted: generated codeInfo empty, requirementId=%@", requirementId);
        return NO;
    }

    LKRequirementCodeInfoStore *store = [LKRequirementCodeInfoStore sharedInstance];
    NSArray<LKRequirementCodeInfoRecord *> *records = [store recordModelsForSessionId:sessionId];
    if (records.count == 0) {
        LKMCPCodeInfoMenuLog(@"add code info aborted: no records in session=%@", sessionId);
        return NO;
    }

    NSMutableArray<LKRequirementCodeInfoRecord *> *mutableRecords = [records mutableCopy];
    NSUInteger targetIndex = [mutableRecords indexOfObjectPassingTest:^BOOL(LKRequirementCodeInfoRecord *obj, NSUInteger idx, BOOL *stop) {
        return [obj.requirementId isEqualToString:requirementId];
    }];
    if (targetIndex == NSNotFound) {
        LKMCPCodeInfoMenuLog(@"add code info aborted: requirement not found, requirementId=%@", requirementId);
        return NO;
    }

    LKRequirementCodeInfoRecord *updatedRecord = [mutableRecords[targetIndex] copy];
    updatedRecord.codeInfo = [codeInfo copy];
    mutableRecords[targetIndex] = updatedRecord;

    [store saveRecordModels:[mutableRecords copy] sessionId:sessionId];
    [[NSNotificationCenter defaultCenter] postNotificationName:NotificationName_RequirementCodeInfoDidChange
                                                        object:nil
                                                      userInfo:@{
        LKMCPRequirementCodeInfoChangedSessionIdKey: sessionId ?: @"",
        LKMCPRequirementCodeInfoChangedOperationKey: @"edit"
    }];
    LKMCPCodeInfoMenuLog(@"add code info success, requirementId=%@, sessionId=%@", requirementId, sessionId);
    return YES;
}

+ (NSString *)_sessionIdFromDataSource:(LKHierarchyDataSource *)dataSource {
    LookinAppInfo *dataSourceAppInfo = dataSource.rawHierarchyInfo.appInfo;
    if (dataSourceAppInfo) {
        return [NSString stringWithFormat:@"%@", @(dataSourceAppInfo.appInfoIdentifier)];
    }

    LKInspectableApp *app = [LKAppsManager sharedInstance].inspectingApp;
    if (!app) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@", @(app.appInfo.appInfoIdentifier)];
}

+ (NSString *)_generatedCodeInfoTextFromDisplayItem:(LookinDisplayItem *)displayItem {
    // Current policy: only first class and first relation are written into codeInfo.
    NSString *firstClass = [self _firstClassTextFromDisplayItem:displayItem];
    NSString *firstRelation = [self _firstRelationTextFromDisplayItem:displayItem];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (firstClass.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"Class: %@", firstClass]];
    }
    if (firstRelation.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"Relation: %@", firstRelation]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

+ (NSString *)_firstClassTextFromDisplayItem:(LookinDisplayItem *)displayItem {
    LookinAttribute *classAttr = [self _attributeWithIdentifier:LookinAttr_Class_Class_Class fromDisplayItem:displayItem];
    if (!classAttr) {
        return nil;
    }

    if (![classAttr.value isKindOfClass:[NSArray class]]) {
        return nil;
    }
    id firstList = [(NSArray *)classAttr.value firstObject];
    if ([firstList isKindOfClass:[NSArray class]]) {
        NSString *firstRawClass = [self _trimmedTextFromRawValue:[(NSArray *)firstList firstObject]];
        if (firstRawClass.length == 0) {
            return nil;
        }
        NSString *demangled = [LKSwiftDemangler completedParseWithInput:firstRawClass];
        return [self _trimmedTextFromRawValue:demangled];
    }
    if ([firstList isKindOfClass:[NSString class]]) {
        NSString *demangled = [LKSwiftDemangler completedParseWithInput:firstList];
        return [self _trimmedTextFromRawValue:demangled];
    }
    return nil;
}

+ (NSString *)_firstRelationTextFromDisplayItem:(LookinDisplayItem *)displayItem {
    LookinAttribute *relationAttr = [self _attributeWithIdentifier:LookinAttr_Relation_Relation_Relation fromDisplayItem:displayItem];
    if (!relationAttr) {
        return nil;
    }

    if ([relationAttr.value isKindOfClass:[NSArray class]]) {
        NSString *firstRaw = [self _trimmedTextFromRawValue:[(NSArray *)relationAttr.value firstObject]];
        if (firstRaw.length == 0) {
            return nil;
        }
        return [self _demangleRelationText:firstRaw];
    }
    return nil;
}

+ (LookinAttribute *)_attributeWithIdentifier:(NSString *)identifier fromDisplayItem:(LookinDisplayItem *)displayItem {
    if (identifier.length == 0 || !displayItem) {
        return nil;
    }
    NSArray<LookinAttributesGroup *> *groups = [displayItem queryAllAttrGroupList];
    for (LookinAttributesGroup *group in groups) {
        for (LookinAttributesSection *section in group.attrSections) {
            for (LookinAttribute *attribute in section.attributes) {
                if ([attribute.identifier isEqualToString:identifier]) {
                    return attribute;
                }
            }
        }
    }
    return nil;
}

+ (NSString *)_trimmedTextFromRawValue:(id)rawValue {
    if (![rawValue isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *text = [(NSString *)rawValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return text.length > 0 ? text : nil;
}

+ (NSString *)_demangleRelationText:(NSString *)rawText {
    if (rawText.length == 0) {
        return nil;
    }
    NSString *trimmed = [self _trimmedTextFromRawValue:rawText];
    if (trimmed.length == 0) {
        return nil;
    }

    {
        // Pattern: (AAA : BBB *)
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\(\\s*(\\w+)\\s*:\\s*(\\w+)\\s*\\*\\s*\\)" options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)];
        if (match && match.numberOfRanges == 3) {
            NSString *raw1 = [trimmed substringWithRange:[match rangeAtIndex:1]];
            NSString *raw2 = [trimmed substringWithRange:[match rangeAtIndex:2]];
            NSString *demangled1 = [LKSwiftDemangler simpleParseWithInput:raw1];
            NSString *demangled2 = [LKSwiftDemangler simpleParseWithInput:raw2];

            NSString *newText = [trimmed stringByReplacingCharactersInRange:[match rangeAtIndex:1] withString:demangled1 ?: raw1];
            newText = [newText stringByReplacingOccurrencesOfString:raw2 withString:demangled2 ?: raw2];
            return [self _trimmedTextFromRawValue:newText];
        }
    }

    {
        // Pattern: (AAA *)
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\(\\s*(\\w+)\\s*\\*\\s*\\)" options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)];
        if (match && match.numberOfRanges >= 2) {
            NSRange range = [match rangeAtIndex:1];
            NSString *rawClassName = [trimmed substringWithRange:range];
            NSString *demangled = [LKSwiftDemangler simpleParseWithInput:rawClassName];
            NSString *newText = [trimmed stringByReplacingCharactersInRange:range withString:demangled ?: rawClassName];
            return [self _trimmedTextFromRawValue:newText];
        }
    }

    return trimmed;
}

@end
