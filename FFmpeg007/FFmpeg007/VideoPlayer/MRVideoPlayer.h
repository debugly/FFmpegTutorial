//
//  MRVideoPlayer.h
//  FFmpeg004
//
//  Created by Matt Reach on 2018/1/20.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MRVideoPlayer : NSObject

/**
 将渲染view添加到指定父视图上，画面将在父视图区域内展示

 @param superView 最好是一个干净的父视图，不要其他的子控件
 */
- (void)addRenderToSuperView:(UIView *)superView;
- (void)removeRenderFromSuperView;
- (void)playURLString:(NSString *)url;

@end
