//
//  SupportURLProtocol.m
//  FFmpeg001
//
//  Created by xuqianlong on 2017/5/14.
//  Copyright © 2017年 xuqianlong. All rights reserved.
//

#import "SupportURLProtocol.h"
#import <libavformat/avformat.h>
#include <libavcodec/avcodec.h>

@interface SupportURLProtocol ()

@property (weak, nonatomic) IBOutlet UITextView *tx;

@end

@implementation SupportURLProtocol

- (void)viewDidLoad {
    [super viewDidLoad];
    
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
            protocolStr = [protocolStr stringByAppendingFormat:@"%s\n",p];
        }else{
            break;
        }
    }
    pup = NULL;
    return protocolStr;
}

@end
