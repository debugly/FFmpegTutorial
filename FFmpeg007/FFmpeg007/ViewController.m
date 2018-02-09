//
//  ViewController.m
//  FFmpeg002
//
//  Created by Matt Reach on 2018/1/20.
//  Copyright © 2017年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "ViewController.h"
#import "MRVideoPlayer.h"

@interface ViewController ()

@property (nonatomic, strong) MRVideoPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSString *moviePath = [[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    moviePath = @"http://debugly.github.io/repository/test.mp4";
    
    _player = [[MRVideoPlayer alloc]init];
    [_player playURLString:moviePath];
    [_player addRenderToSuperView:self.view];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
