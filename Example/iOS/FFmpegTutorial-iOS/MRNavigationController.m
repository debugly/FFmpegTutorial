//
//  MRNavigationController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/4/19.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRNavigationController.h"

@interface MRNavigationController ()<UINavigationControllerDelegate>

@end

@implementation MRNavigationController

__unused static UIInterfaceOrientation UIDeviceToInterfaceOrientation(UIDeviceOrientation orientation)
{
    switch (orientation) {
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationUnknown:
        {
            return UIInterfaceOrientationUnknown;
        }
        case UIDeviceOrientationLandscapeLeft:
        {
            return UIInterfaceOrientationLandscapeRight;
        }
        case UIDeviceOrientationLandscapeRight:
        {
            return UIInterfaceOrientationLandscapeLeft;
        }
        case UIDeviceOrientationPortrait:
        {
            return UIInterfaceOrientationPortrait;
        }
        case UIDeviceOrientationPortraitUpsideDown:
        {
            return UIInterfaceOrientationPortraitUpsideDown;
        }
    }
}

static UIDeviceOrientation UIInterfaceToDeviceOrientation(UIInterfaceOrientation orientation)
{
    switch (orientation) {
        case UIInterfaceOrientationUnknown:
        {
            return UIDeviceOrientationUnknown;
        }
        case UIInterfaceOrientationLandscapeRight:
        {
            return UIDeviceOrientationLandscapeLeft;
        }
        case UIInterfaceOrientationLandscapeLeft:
        {
            return UIDeviceOrientationLandscapeRight;
        }
        case UIInterfaceOrientationPortrait:
        {
            return UIDeviceOrientationPortrait;
        }
        case UIInterfaceOrientationPortraitUpsideDown:
        {
            return UIDeviceOrientationPortraitUpsideDown;
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.delegate = self;
}

- (UIInterfaceOrientation)navigationControllerPreferredInterfaceOrientationForPresentation:(UINavigationController *)navigationController
{
    return UIInterfaceOrientationLandscapeLeft;
}

//强制转屏
- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation{

    if ([[UIApplication sharedApplication] statusBarOrientation] == orientation) {
        return;
    }
    
    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        [[UIDevice currentDevice] setValue:@(UIDeviceOrientationUnknown) forKey:@"orientation"];
        [[UIDevice currentDevice] setValue:@(UIInterfaceToDeviceOrientation(orientation)) forKey:@"orientation"];
    }
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    UIInterfaceOrientationMask currentStatusBarMask = 1 << [[UIApplication sharedApplication] statusBarOrientation];
    UIInterfaceOrientationMask supportedMask = [viewController supportedInterfaceOrientations];
    
    //是否横屏 -> 横屏？
    BOOL ok = (UIInterfaceOrientationMaskLandscape & currentStatusBarMask) && (UIInterfaceOrientationMaskLandscape & supportedMask);
    
    if (!ok) {
        ok = currentStatusBarMask & supportedMask;
    }
    if (!ok) {
        
        UIInterfaceOrientation wantOritation = [viewController preferredInterfaceOrientationForPresentation];
        [self setInterfaceOrientation:wantOritation];
    }
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [[self visibleViewController]supportedInterfaceOrientations];
}

@end
