//
//  ViewController.m
//  FFmpeg005
//
//  Created by 许乾隆 on 2018/1/19.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "ViewController.h"
#import "MRAudioPlayer.h"

@interface ViewController ()

@property (nonatomic, strong) MRAudioPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _player = [[MRAudioPlayer alloc]init];
    ///使用本地server地址；
    [_player playURLString:@"http://localhost/ffmpeg-test/123.mp3"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
