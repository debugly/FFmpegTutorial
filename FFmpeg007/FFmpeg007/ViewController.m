//
//  ViewController.m
//  FFmpeg002
//
//  Created by Matt Reach on 2018/2/10.
//  Copyright © 2017年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "ViewController.h"
#import "MRVideoPlayer.h"

#ifndef _weakSelf_SL
#define _weakSelf_SL     __weak   __typeof(self) $weakself = self;
#endif

#ifndef _strongSelf_SL
#define _strongSelf_SL   __strong __typeof($weakself) self = $weakself;
#endif

@interface ViewController ()

@property (nonatomic, strong) MRVideoPlayer *player;
@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;

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
    
    _weakSelf_SL
    [_player onBuffer:^{
        _strongSelf_SL
        [self.indicatorView startAnimating];
    }];
    
    [_player onBufferOK:^{
        _strongSelf_SL
        [self.indicatorView stopAnimating];
    }];
    
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:indicatorView];
    indicatorView.center = self.view.center;
    indicatorView.hidesWhenStopped = YES;
    [indicatorView sizeToFit];
    _indicatorView = indicatorView;
    [indicatorView startAnimating];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
