//
//  SupportURLProtocol.m
//  FFmpeg001
//
//  Created by Matt Reach on 2017/5/14.
//  Copyright © 2017 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "SupportURLProtocol.h"
#import <libavformat/avformat.h>

@interface SupportURLProtocol ()

@property (weak, nonatomic) IBOutlet UITextView *tx;

@end

@implementation SupportURLProtocol

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ///ffmpeg v3不需要；
    //av_register_all();
    
    NSString *inputProtocol = [self supportProtocols:YES];
    NSString *outputProtocol = [self supportProtocols:NO];
    
    self.tx.text = [NSString stringWithFormat:@"input protocol : \n%@\n==========\noutput protocol : \n%@",inputProtocol,outputProtocol];
}

- (NSString *)supportProtocols:(BOOL)inputOrOutput
{
    char *pup = NULL;
    void **a_pup = (void **)&pup;
    
    int flag = inputOrOutput ? 0 : 1;
    
    NSString *protocolStr = @"";
    while (1) {
        const char *p = avio_enum_protocols(a_pup, flag);
        if (p != NULL) {
            protocolStr = [protocolStr stringByAppendingFormat:@"    %s\n",p];
        }else{
            break;
        }
    }
    pup = NULL;
    return protocolStr;
}

@end
