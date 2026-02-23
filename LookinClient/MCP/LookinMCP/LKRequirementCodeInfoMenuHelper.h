//
//  LKRequirementCodeInfoMenuHelper.h
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import <Cocoa/Cocoa.h>

@class LKHierarchyDataSource;
@class LookinDisplayItem;

NS_ASSUME_NONNULL_BEGIN

@interface LKRequirementCodeInfoMenuHelper : NSObject

+ (void)appendCodeInfoMenuToMenu:(NSMenu *)menu
                     displayItem:(LookinDisplayItem * _Nullable)displayItem
                      dataSource:(LKHierarchyDataSource * _Nullable)dataSource
                          target:(id)target
                 openBoardAction:(SEL)openBoardAction;

+ (void)openCodeInfoBoardForDataSource:(LKHierarchyDataSource * _Nullable)dataSource;

@end

NS_ASSUME_NONNULL_END
