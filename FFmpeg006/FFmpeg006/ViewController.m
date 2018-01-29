//
//  ViewController.m
//  FFmpeg006
//
//  Created by 许乾隆 on 2018/1/29.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "ViewController.h"
#import "MRMoviePlayer.h"

@interface ViewController ()

@property (nonatomic, strong) MRMoviePlayer *audioPlayer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _audioPlayer = [[MRMoviePlayer alloc]init];
    ///使用本地server地址；
//    [_player playURLString:@"http://localhost/ffmpeg-test/123.mp3"];
    
    NSString *moviePath = @"http://localhost/ffmpeg-test/test.mp4";
    
    [_audioPlayer addRenderToSuperView:self.view];
    [_audioPlayer playURLString:moviePath];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
