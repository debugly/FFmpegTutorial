//
//  FFTOpenGLVersionHelper.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/1/12.
//
// 调用示例：
/*
 [FFTOpenGLVersionHelper prepareOpenGLContext:^{
    NSString *version = [FFTOpenGLVersionHelper version];
 } forLegacy:NO];
 */

#import <Foundation/Foundation.h>
#import <OpenGL/gl3.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFTOpenGLVersionHelper : NSObject

///准备OPENGL环境
+ (void)prepareOpenGLContext:(void(^)(void))completion forLegacy:(BOOL)legacy;

///根据枚举查询
+ (NSString *)glString:(const char *)name enu:(GLenum)s;

///厂商
+ (NSString *)vendor;

///渲染器
+ (NSString *)renderer;

///支持的GLSL版本
+ (NSString *)glslVersion;

///版本
+ (NSString *)version;

///扩展
+ (NSArray<NSString *> *)supportedExtensions:(BOOL)legacy;

//所有信息
+ (NSString *)openglAllInfo:(BOOL)legacy;

@end

NS_ASSUME_NONNULL_END
