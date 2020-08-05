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
    
    NSMutableString *txt = [NSMutableString string];
    
    {
        //编译配置信息
        NSString *configuration = [FFVersionHelper configuration];
        //各个库的版本信息
        NSString *libsVersion = [FFVersionHelper formatedLibsVersion];
        
        [txt appendFormat:@"\n【FFMpeg Build Info】\n%@\n【FFMpeg Libs Version】\n%@",configuration,libsVersion];
    }
    
    {
        //支持的输入流协议
        NSString *inputProtocol = [[FFVersionHelper supportedInputProtocols] componentsJoinedByString:@","];
        //支持的输出流协议
        NSString *outputProtocol = [[FFVersionHelper supportedOutputProtocols] componentsJoinedByString:@","];
        
        [txt appendFormat:@"\n【Input protocols】: \n%@\n【Output protocols】: \n%@",inputProtocol,outputProtocol];
    }
    
    self.textView.text = txt;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{
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
