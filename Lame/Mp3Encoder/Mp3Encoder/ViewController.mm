//
//  ViewController.m
//  Mp3Encoder
//
//  Created by qianlongxu on 2020/1/16.
//  Copyright © 2020 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "ViewController.h"
#import "MRMp3Encoder.hpp"

@interface ViewController ()
{
    
}

@end

@implementation ViewController

- (void)test2Channel {
    MRMp3Encoder mp3Encoder;
    NSString *pcm = [[NSBundle mainBundle] pathForResource:@"LR" ofType:@"pcm"];
    const char *input = [pcm UTF8String];
    NSString *mp3 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LR.mp3"];
    const char *outer = [mp3 UTF8String];
    NSLog(@"input:%s",input);
    NSLog(@"output:%s",outer);
    
    mp3Encoder.init(input, outer, 44100, 2, 128);
    mp3Encoder.encode();
    mp3Encoder.destory();
}

- (void)testLChannel {
    MRMp3Encoder mp3Encoder;
    NSString *pcm = [[NSBundle mainBundle] pathForResource:@"L" ofType:@"pcm"];
    const char *input = [pcm UTF8String];
    NSString *mp3 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"L.mp3"];
    const char *outer = [mp3 UTF8String];
    NSLog(@"input:%s",input);
    NSLog(@"output:%s",outer);
    
    mp3Encoder.init(input, outer, 44100, 1, 128);
    mp3Encoder.encode();
    mp3Encoder.destory();
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
//    [self test2Channel];
    [self testLChannel];
}


@end
