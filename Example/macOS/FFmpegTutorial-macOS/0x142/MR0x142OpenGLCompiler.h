//
//  MR0x142OpenGLCompiler.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/8/1.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x142OpenGLCompiler : NSObject

@property (copy) NSString *vshName;
@property (copy) NSString *fshName;

- (instancetype)initWithvshName:(NSString *)vshName
                        fshName:(NSString *)fshName;
- (BOOL)compileIfNeed;
- (void)active;
- (int)getUniformLocation:(const char *)name;
- (int)getAttribLocation:(const char *)name;

@end

NS_ASSUME_NONNULL_END
