//
//  NSNavigationController.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/11/28.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSNavigationController : NSViewController

@property (nonatomic, strong)NSViewController *rootViewController;

- (instancetype)initWithRootViewController:(NSViewController *)rootViewController;
- (void)pushViewController:(NSViewController *)viewController animated:(BOOL)animated;
- (nullable NSViewController *)popViewControllerAnimated:(BOOL)animated;

@end

@interface NSViewController (NSNavigationController)

@property(nullable,nonatomic,readonly,strong) NSNavigationController *navigationController; // If this view controller has been pushed onto a navigation controller, return it.

@end

NS_ASSUME_NONNULL_END
