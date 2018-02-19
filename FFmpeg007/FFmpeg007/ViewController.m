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
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) MRVideoPlayer *player2;
@property (weak, nonatomic) UIActivityIndicatorView *indicatorView2;
@property (nonatomic, strong) UIView *contentView2;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"Movie1" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(play1) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    CGFloat viewWidth = self.view.bounds.size.width;
    CGFloat btnWidth = viewWidth/2.0;
    CGFloat btnHeight = 84;
    btn.frame = CGRectMake(0,0,btnWidth,btnHeight);
    btn.backgroundColor = [UIColor redColor];
    
    UIButton *btn2 = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn2 setTitle:@"Movie2" forState:UIControlStateNormal];
    [btn2 addTarget:self action:@selector(play2) forControlEvents:UIControlEventTouchUpInside];
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

- (void)play1
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
    [self.contentView addSubview:indicatorView];
    indicatorView.center = CGPointMake(self.contentView.bounds.size.width/2.0, self.contentView.bounds.size.height/2.0);
    indicatorView.hidesWhenStopped = YES;
    [indicatorView sizeToFit];
    _indicatorView = indicatorView;
    [indicatorView startAnimating];

}

- (void)play2
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
    
    _weakSelf_SL
    [_player2 onBuffer:^{
        _strongSelf_SL
        [self.indicatorView2 startAnimating];
    }];
    
    [_player2 onBufferOK:^{
        _strongSelf_SL
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
