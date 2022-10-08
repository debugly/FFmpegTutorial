//
//  FFTOpenGLCompiler.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/8/2.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFTOpenGLHelper.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFTOpenGLCompiler : NSObject

@property (copy) NSString *vsh;
@property (copy) NSString *fsh;

- (instancetype)initWithvsh:(NSString *)vsh
                        fsh:(NSString *)fsh;
- (BOOL)compileIfNeed;
- (void)active;
- (int)getUniformLocation:(const char *)name;
- (int)getAttribLocation:(const char *)name;

@end

NS_ASSUME_NONNULL_END
