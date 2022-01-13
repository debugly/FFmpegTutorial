//
//  OpenGLVersionHelper.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/1/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenGLVersionHelper : NSObject

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

//above all info
+ (NSString *)openglAllInfo:(BOOL)legacy;

@end

NS_ASSUME_NONNULL_END
