//
//  MRVideoFrame.h
//  FFmpeg004
//
//  Created by Matt Reach on 2017/10/20.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIImage.h>

@interface MRVideoFrame : NSObject

@property (assign, nonatomic) float duration;
@property (strong, nonatomic) UIImage *image;

@end
