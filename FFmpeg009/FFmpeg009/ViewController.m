//
//  ViewController.m
//  FFmpeg002
//
//  Created by Matt Reach on 2018/2/10.
//  Copyright © 2017年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "ViewController.h"
#import "MRVideoPlayer.h"
#import "MRAudioQueuePlayer.h"

#ifndef __weakSelf__
#define __weakSelf__     __weak   __typeof(self) $weakself = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__   __strong __typeof($weakself) self = $weakself;
#endif

@interface ViewController ()

@property (nonatomic, strong) MRVideoPlayer *videoPlayer;
@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) MRVideoPlayer *videoPlayer2;
@property (weak, nonatomic) UIActivityIndicatorView *indicatorView2;
@property (nonatomic, strong) UIView *contentView2;

@property (nonatomic, strong) MRAudioQueuePlayer *audioPlayer;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGFloat viewWidth = self.view.bounds.size.width;
    CGFloat btnWidth = viewWidth/2.0;
    CGFloat btnHeight = 84;
    CGFloat offsetY = 0;
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"Play Movie" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(playVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    btn.frame = CGRectMake(0,offsetY,btnWidth,btnHeight);
    btn.backgroundColor = [UIColor redColor];
    
    UIButton *btn2 = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn2 setTitle:@"Play Movie2" forState:UIControlStateNormal];
    [btn2 addTarget:self action:@selector(playVideo2) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn2];
    btn2.frame = CGRectMake(btnWidth,offsetY,btnWidth,btnHeight);
    btn2.backgroundColor = [UIColor greenColor];
    
    offsetY += btnHeight;
    
    UIButton *btn3 = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn3 setTitle:@"Play Audio" forState:UIControlStateNormal];
    [btn3 addTarget:self action:@selector(playAudio) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn3];
    CGFloat btn3Height = btnHeight * 0.8;
    btn3.frame = CGRectMake(0,offsetY,viewWidth,btn3Height);
    btn3.backgroundColor = [UIColor purpleColor];
    
    offsetY += btn3Height;
    
    CGFloat contentHeight = (self.view.bounds.size.height - offsetY)/2.0;
    _contentView = [[UIView alloc]initWithFrame:CGRectMake(0, offsetY, viewWidth, contentHeight)];
    _contentView.backgroundColor = [UIColor blueColor];
    [self.view addSubview:_contentView];
    
    offsetY += contentHeight;
    
    _contentView2 = [[UIView alloc]initWithFrame:CGRectMake(0, offsetY, viewWidth, contentHeight)];
    _contentView2.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:_contentView2];
}

- (void)playAudio
{
    if (_audioPlayer) {
        [_audioPlayer stop];
        _audioPlayer = nil;
    }else{
        _audioPlayer = [[MRAudioQueuePlayer alloc]init];
        ///使用本地server地址；
        [_audioPlayer playURLString:@"http://192.168.3.2/ffmpeg-test/test.mp3"];
    }
}

- (void)playVideo
{
    if (self.videoPlayer) {
        [self.videoPlayer stop];
        [self.videoPlayer removeRenderFromSuperView];
        self.videoPlayer = nil;
        [self.indicatorView removeFromSuperview];
        return;
    }
    
    NSString *moviePath = [[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    moviePath = @"http://debugly.github.io/repository/test.mp4";
    moviePath = @"http://192.168.3.2/ffmpeg-test/test.mp4";
    
    _videoPlayer = [[MRVideoPlayer alloc]init];
    [_videoPlayer playURLString:moviePath];
    [_videoPlayer addRenderToSuperView:self.contentView];
    
    __weakSelf__
    [_videoPlayer onBuffer:^{
        __strongSelf__
        [self.indicatorView startAnimating];
    }];
    
    [_videoPlayer onBufferOK:^{
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
    if (self.videoPlayer2) {
        [self.videoPlayer2 stop];
        [self.videoPlayer2 removeRenderFromSuperView];
        self.videoPlayer2 = nil;
        [self.indicatorView2 removeFromSuperview];
        return;
    }
    
    NSString *moviePath = [[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    moviePath = @"http://debugly.github.io/repository/test.mp4";
    moviePath = @"http://192.168.3.2/ffmpeg-test/test2.mp4";
    
    _videoPlayer2 = [[MRVideoPlayer alloc]init];
    [_videoPlayer2 playURLString:moviePath];
    [_videoPlayer2 addRenderToSuperView:self.contentView2];
    
    __weakSelf__
    [_videoPlayer2 onBuffer:^{
        __strongSelf__
        [self.indicatorView2 startAnimating];
    }];
    
    [_videoPlayer2 onBufferOK:^{
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
