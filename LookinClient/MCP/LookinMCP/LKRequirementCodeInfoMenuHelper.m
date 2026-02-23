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
#import "LKAppsManager.h"
#import "LKInspectableApp.h"
#import "LookinAppInfo.h"
#import "LookinHierarchyInfo.h"

@implementation LKRequirementCodeInfoMenuHelper

+ (void)appendCodeInfoMenuToMenu:(NSMenu *)menu
                     displayItem:(LookinDisplayItem *)displayItem
                      dataSource:(LKHierarchyDataSource *)dataSource
                          target:(id)target
                 openBoardAction:(SEL)openBoardAction {
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
    NSArray<NSDictionary<NSString *, NSString *> *> *records = sessionId.length > 0 ? [[LKRequirementCodeInfoStore sharedInstance] recordsForSessionId:sessionId] : @[];

    [submenu addItem:[NSMenuItem separatorItem]];
    if (records.count == 0) {
        [submenu addItem:({
            NSMenuItem *emptyItem = [NSMenuItem new];
            emptyItem.title = NSLocalizedString(@"No requirement items. Call set_requirement_items first.", nil);
            emptyItem.enabled = NO;
            emptyItem;
        })];
    } else {
        [records enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *record, NSUInteger idx, BOOL *stop) {
            NSString *rid = record[@"requirementId"] ?: @"";
            NSString *desc = record[@"description"] ?: @"";
            NSString *title = desc.length > 0 ? [NSString stringWithFormat:@"%@ - %@", rid, desc] : rid;
            [submenu addItem:({
                NSMenuItem *item = [NSMenuItem new];
                item.title = title;
                item.enabled = NO;
                item;
            })];
        }];
    }

    [menu addItem:rootItem];
}

+ (void)openCodeInfoBoardForDataSource:(LKHierarchyDataSource *)dataSource {
    NSString *sessionId = [self _sessionIdFromDataSource:dataSource] ?: @"";
    [[LKRequirementCodeInfoStore sharedInstance] showRequirementCodeInfoBoardForSessionId:sessionId];
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

@end
