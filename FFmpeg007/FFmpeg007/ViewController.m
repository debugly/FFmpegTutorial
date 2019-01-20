//
//  ViewController.m
//  FFmpeg002
//
//  Created by Matt Reach on 2018/2/10.
//  Copyright © 2017年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "ViewController.h"
#import "MRVideoPlayer.h"

#ifndef __weakSelf__
#define __weakSelf__     __weak   __typeof(self) $weakself = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__   __strong __typeof($weakself) self = $weakself;
#endif

@interface ViewController ()

@property (nonatomic, strong) MRVideoPlayer *player;
@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) MRVideoPlayer *player2;
@property (weak, nonatomic) UIActivityIndicatorView *indicatorView2;
@property (nonatomic, strong) UIView *contentView2;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGFloat viewWidth = self.view.bounds.size.width;
    CGFloat btnWidth = viewWidth/2.0;
    CGFloat btnHeight = 84;
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"Play Movie" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(playVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    btn.frame = CGRectMake(0,0,btnWidth,btnHeight);
    btn.backgroundColor = [UIColor redColor];
    
    UIButton *btn2 = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn2 setTitle:@"Play Movie2" forState:UIControlStateNormal];
    [btn2 addTarget:self action:@selector(playVideo2) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn2];
    btn2.frame = CGRectMake(btnWidth,0,btnWidth,btnHeight);
    btn2.backgroundColor = [UIColor greenColor];
    
    CGFloat contentHeight = (self.view.bounds.size.height - btnHeight)/2.0;
    _contentView = [[UIView alloc]initWithFrame:CGRectMake(0, btnHeight, viewWidth, contentHeight)];
    _contentView.backgroundColor = [UIColor blueColor];
    [self.view addSubview:_contentView];
    
    _contentView2 = [[UIView alloc]initWithFrame:CGRectMake(0, btnHeight + contentHeight, viewWidth, contentHeight)];
    _contentView2.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:_contentView2];
    
}

- (void)playVideo
{
    if (self.player) {
        [self.player stop];
        [self.player removeRenderFromSuperView];
        self.player = nil;
        [self.indicatorView removeFromSuperview];
        return;
    }
    
    NSString *moviePath = [[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    moviePath = @"http://debugly.github.io/repository/test.mp4";
    moviePath = @"http://192.168.3.2/ffmpeg-test/test.mp4";
    
    _player = [[MRVideoPlayer alloc]init];
    [_player playURLString:moviePath];
    [_player addRenderToSuperView:self.contentView];
    
    __weakSelf__
    [_player onBuffer:^{
        __strongSelf__
        [self.indicatorView startAnimating];
    }];
    
    [_player onBufferOK:^{
        __strongSelf__
        [self.indicatorView stopAnimating];
    }];
    
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.contentView addSubview:indicatorView];
    indicatorView.center = CGPointMake(self.contentView.bounds.size.width/2.0, self.contentView.bounds.size.height/2.0);
    indicatorView.hidesWhenStopped = YES;
    [indicatorView sizeToFit];
    _indicatorView = indicatorView;
    [indicatorView startAnimating];
}

- (void)playVideo2
{
    if (self.player2) {
        [self.player2 stop];
        [self.player2 removeRenderFromSuperView];
        self.player2 = nil;
        [self.indicatorView2 removeFromSuperview];
        return;
    }
    
    NSString *moviePath = [[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    moviePath = @"http://debugly.github.io/repository/test.mp4";
    moviePath = @"http://192.168.3.2/ffmpeg-test/test2.mp4";
    
    _player2 = [[MRVideoPlayer alloc]init];
    [_player2 playURLString:moviePath];
    [_player2 addRenderToSuperView:self.contentView2];
    
    __weakSelf__
    [_player2 onBuffer:^{
        __strongSelf__
        [self.indicatorView2 startAnimating];
    }];
    
    [_player2 onBufferOK:^{
        __strongSelf__
        [self.indicatorView2 stopAnimating];
    }];
    
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.contentView2 addSubview:indicatorView];
    indicatorView.center = CGPointMake(self.contentView2.bounds.size.width/2.0, self.contentView2.bounds.size.height/2.0);;
    indicatorView.hidesWhenStopped = YES;
    [indicatorView sizeToFit];
    _indicatorView2 = indicatorView;
    [indicatorView startAnimating];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
