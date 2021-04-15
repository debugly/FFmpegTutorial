//
//  NSNavigationController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/11/28.
//

#import "NSNavigationController.h"

static CGFloat kNavigationBarHeight = 64;

@interface NSNavigationController ()

@property (nonatomic, strong) NSMutableArray *viewControllerArr;
@property (nonatomic, strong) NSView *navigationBar;
@property (nonatomic, strong) NSView *contentView;
@property (nonatomic, weak) NSButton *backView;
@property (nonatomic, weak) NSTextField *titleLb;

@end

@implementation NSNavigationController

@synthesize title = _title;

- (NSMutableArray *)viewControllerArr
{
    if (!_viewControllerArr) {
        _viewControllerArr = [NSMutableArray array];
    }
    return _viewControllerArr;
}

- (instancetype)initWithRootViewController:(NSViewController *)rootViewController
{
    self = [self init];
    if (self) {
        [self.viewControllerArr addObject:rootViewController];
        [self addChildViewController:rootViewController];
    }
    return self;
}

- (void)loadView
{
    self.view = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 800, 600)];
//    NSVisualEffectView *effectView = [[NSVisualEffectView alloc] initWithFrame:CGRectMake(0, 0, 800, 600)];
//    effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
//    effectView.state = NSVisualEffectStateFollowsWindowActiveState;
//    effectView.material = NSVisualEffectMaterialLight;
//    self.view = effectView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
    CGFloat y = self.view.bounds.size.height - kNavigationBarHeight;
    {
        self.navigationBar = [[NSView alloc] initWithFrame:CGRectMake(0, y, self.view.bounds.size.width, kNavigationBarHeight)];
        [self.navigationBar setWantsLayer:YES];
        self.navigationBar.layer.backgroundColor = [[NSColor colorWithWhite:0.9 alpha:0.8]CGColor];
        [self.view addSubview:self.navigationBar];
        self.navigationBar.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin | NSViewMinYMargin;
        
        NSTextField *titleLb = [[NSTextField alloc] init];
        titleLb.editable = NO;
        //点击的时候不显示蓝色外框
        titleLb.focusRingType = NSFocusRingTypeNone;
        titleLb.bordered = NO;
        titleLb.backgroundColor = [NSColor clearColor];
        titleLb.font = [NSFont boldSystemFontOfSize:16];
        titleLb.usesSingleLineMode = YES;
        [self.navigationBar addSubview:titleLb];
        if (self.title) {
            titleLb.stringValue = self.title;
        }
        self.titleLb = titleLb;
        [self updateTitleFrame];
        
        NSButton *backView = [[NSButton alloc] init];
        [backView setButtonType:NSButtonTypeSwitch];
        backView.image = [NSImage imageNamed:@"back"];
        backView.frame = CGRectMake(10, (CGRectGetHeight(self.navigationBar.bounds) - 20 - 20)/2.0, 20, 20);
        [backView setTarget:self];
        [backView setAction:@selector(onClickedBack:)];
        [self.navigationBar addSubview:backView];
        self.backView = backView;
        [backView setHidden:YES];
        
        NSBox *horizontalSeparator = [[NSBox alloc] initWithFrame:NSMakeRect(0,0,CGRectGetWidth(self.navigationBar.bounds),1.0)];
        [horizontalSeparator setBoxType:NSBoxSeparator];
        [self.navigationBar addSubview:horizontalSeparator];
        horizontalSeparator.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
    
    {
        CGRect contentRect = self.view.bounds;
        contentRect.size.height = y;
        self.contentView = [[NSView alloc] initWithFrame:contentRect];
        [self.view addSubview:self.contentView];
        self.contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
    
    {
        NSViewController *rootViewController = [self.viewControllerArr firstObject];
        if (rootViewController) {
            [self.contentView addSubview:rootViewController.view];
            self.title = rootViewController.title;
            rootViewController.view.frame = [rootViewController.view superview].bounds;
            rootViewController.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        }
    }
}

- (void)updateTitleFrame
{
    if (!CGRectIsEmpty(self.navigationBar.bounds)) {
        CGFloat height = CGRectGetHeight(self.navigationBar.bounds);
        [self.titleLb sizeToFit];
        NSRect rect = CGRectZero;
        rect.size = self.titleLb.bounds.size;
        rect.origin.y = (height - rect.size.height) / 2.0;
        rect.origin.x = CGRectGetMidX(self.navigationBar.bounds) - rect.size.width / 2.0;
        self.titleLb.frame = rect;
        self.titleLb.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin;
    }
}

- (void)setTitle:(NSString *)title
{
    if (![_title isEqualToString:title]) {
        _title = title;
        if (_title) {
            self.titleLb.stringValue = title;
        } else {
            self.titleLb.stringValue = @"";
        }
        [self updateTitleFrame];
    }
}

- (void)onClickedBack:(NSButton *)sender
{
    [self popViewControllerAnimated:YES];
}

- (void)pushViewController:(NSViewController *)toVC animated:(BOOL)animated
{
    NSViewController *fromViewController = [self.viewControllerArr lastObject];
    [self.viewControllerArr addObject:toVC];
    [self.view addSubview:toVC.view];
    toVC.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addChildViewController:toVC];
    __weakSelf__
    [self transitionFromViewController:fromViewController toViewController:toVC options:animated?NSViewControllerTransitionSlideLeft:NSViewControllerTransitionNone completionHandler:^{
        __strongSelf__
        self.title = toVC.title;
    }];
    [self.backView setHidden:NO];
}

- (nullable NSViewController *)popViewControllerAnimated:(BOOL)animated
{
    NSViewController *popViewController = nil;
    if ([self.viewControllerArr count] > 1) {
        popViewController = [self.viewControllerArr lastObject];
        [self.viewControllerArr removeObject:popViewController];
        NSViewController *backVC = [self.viewControllerArr lastObject];
        BOOL animated = YES;
        [self transitionFromViewController:popViewController toViewController:backVC options:animated?NSViewControllerTransitionSlideRight:NSViewControllerTransitionNone completionHandler:^{
            [popViewController.view removeFromSuperview];
            [popViewController removeFromParentViewController];
            self.title = backVC.title;
            if ([self.viewControllerArr count] == 1) {
                [self.backView setHidden:YES];
            }
        }];
    }
    return popViewController;
}

@end

@implementation NSViewController (NSNavigationController)

- (NSNavigationController *)navigationController
{
    BOOL parentIsNav = [[self parentViewController] isKindOfClass:[NSNavigationController class]];
    if (parentIsNav) {
        return (NSNavigationController *)[self parentViewController];
    } else {
        return nil;
    }
}

@end
