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

@interface LKRequirementCodeInfoMenuHelper : NSObject

+ (void)appendCodeInfoMenuToMenu:(NSMenu *)menu
                     displayItem:(LookinDisplayItem * _Nullable)displayItem
                      dataSource:(LKHierarchyDataSource * _Nullable)dataSource
                          target:(id)target
                 openBoardAction:(SEL)openBoardAction
               addCodeInfoAction:(SEL)addCodeInfoAction;

+ (void)openCodeInfoBoardForDataSource:(LKHierarchyDataSource * _Nullable)dataSource;
+ (BOOL)addCodeInfoFromMenuItem:(NSMenuItem *)menuItem
                      dataSource:(LKHierarchyDataSource * _Nullable)dataSource;

@end

NS_ASSUME_NONNULL_END
