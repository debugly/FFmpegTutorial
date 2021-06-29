//
//  MR0x01ViewController.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 04/18/2020.
//  Copyright (c) 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x01ViewController.h"
#import <FFmpegTutorial/FFVersionHelper.h>

@interface MR0x01ViewController ()

@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

@implementation MR0x01ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.textView.text = [FFVersionHelper ffmpegAllInfo];
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationLandscapeLeft;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
