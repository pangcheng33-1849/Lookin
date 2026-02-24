//
//  LKRequirementCodeInfoMenuHelper.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Cocoa/Cocoa.h>

@class LKHierarchyDataSource;
@class LookinDisplayItem;
@class NSMenuItem;

NS_ASSUME_NONNULL_BEGIN

/// Hierarchy / Preview 右键菜单中的 Code Info 相关能力封装。
@interface LKRequirementCodeInfoMenuHelper : NSObject

/// 向右键菜单追加 `Code Info` 子菜单。
/// @param menu 目标菜单。
/// @param displayItem 当前选中 display item，可为空。
/// @param dataSource 层级数据源，可为空。
/// @param target 菜单 action 目标。
/// @param openBoardAction 打开看板 action。
/// @param addCodeInfoAction 写入 codeInfo action。
+ (void)appendCodeInfoMenuToMenu:(NSMenu *)menu
                     displayItem:(LookinDisplayItem * _Nullable)displayItem
                      dataSource:(LKHierarchyDataSource * _Nullable)dataSource
                          target:(id)target
                 openBoardAction:(SEL)openBoardAction
               addCodeInfoAction:(SEL)addCodeInfoAction;

/// 打开全局 Code Info 看板。
+ (void)openCodeInfoBoardForDataSource:(LKHierarchyDataSource * _Nullable)dataSource;
/// 处理 “add code info to item...” 菜单动作。
/// @return 成功写入并触发刷新通知时返回 YES。
+ (BOOL)addCodeInfoFromMenuItem:(NSMenuItem *)menuItem
                      dataSource:(LKHierarchyDataSource * _Nullable)dataSource;

@end

NS_ASSUME_NONNULL_END
