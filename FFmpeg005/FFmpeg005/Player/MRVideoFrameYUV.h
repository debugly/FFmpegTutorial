//
//  MRVideoFrameYUV.h
//  FFmpeg004
//
//  Created by 许乾隆 on 2017/12/3.
//  Copyright © 2017年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import <Foundation/Foundation.h>
#import <UIKit/UIImage.h>

@interface MRVideoFrameYUV : NSObject

@property (readwrite, nonatomic, strong) NSData *luma;
@property (readwrite, nonatomic, strong) NSData *chromaB;
@property (readwrite, nonatomic, strong) NSData *chromaR;

//- (UIImage *)toImage;

@end
