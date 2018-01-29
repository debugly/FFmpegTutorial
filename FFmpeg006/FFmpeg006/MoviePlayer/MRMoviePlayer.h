//
//  MRMoviePlayer.h
//  FFmpeg006
//
//  Created by 许乾隆 on 2018/1/29.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MRMoviePlayer : NSObject

- (void)playURLString:(NSString *)url;
- (void)addRenderToSuperView:(UIView *)superView;
- (void)removeRenderFromSuperView;

@end
