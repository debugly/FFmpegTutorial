//
//  MR0x01ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/14.
//

#import "MR0x01ViewController.h"
#import <FFmpegTutorial/FFVersionHelper.h>

@interface MR0x01ViewController ()

@property (unsafe_unretained) IBOutlet NSTextView *textView;

@end

@implementation MR0x01ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    self.title = @"0x01";
    
    NSMutableString *txt = [NSMutableString string];
    
    {
        //编译配置信息
        [txt appendFormat:@"\n【FFMpeg Build Info】\n%@",[FFVersionHelper configuration]];
    }
    
    [txt appendString:@"\n"];
    
    {
        //各个lib库的版本信息
        [txt appendFormat:@"\n\n【FFMpeg Libs Version】\n%@",[FFVersionHelper formatedLibsVersion]];
    }
    
    [txt appendString:@"\n"];
    
    {
        //支持的输入流协议
        NSString *inputProtocol = [[FFVersionHelper supportedInputProtocols] componentsJoinedByString:@","];
        [txt appendFormat:@"\n\n【Input protocols】 \n%@",inputProtocol];
    }
    
    [txt appendString:@"\n"];
    
    {
        //支持的输出流协议
        NSString *outputProtocol = [[FFVersionHelper supportedOutputProtocols] componentsJoinedByString:@","];
        
        [txt appendFormat:@"\n\n【Output protocols】 \n%@",outputProtocol];
    }
    
    [txt appendString:@"\n"];
    
    self.textView.string = txt;
}

@end
