//
//  FFTOpenGLVersionHelper.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/1/12.
//

#import "FFTOpenGLVersionHelper.h"
#import <OpenGL/gl3ext.h>
#import <AppKit/NSOpenGL.h>
#import <OpenGL/OpenGL.h>

//https://stackoverflow.com/questions/46322280/how-to-check-opengl-and-glsl-version-without-creating-a-window

@implementation FFTOpenGLVersionHelper

+ (NSString *)glString:(const char *)name enu:(GLenum)s
{
    const char *v = (const char *) glGetString(s);
#if DEBUG
    printf("[GL] %s = %s\n", name, v);
#endif
    const GLubyte *str = glGetString(s);
    return [NSString stringWithFormat:@"[%s]=%s",name,str];
}

+ (NSString *)vendor
{
    return [self glString:"Vendor" enu:GL_VENDOR];
}

+ (NSString *)renderer
{
    return [self glString:"Renderer" enu:GL_RENDERER];
}

+ (NSString *)glslVersion
{
    return [self glString:"GLSL Version" enu:GL_SHADING_LANGUAGE_VERSION];
}

+ (NSString *)version
{
    return [self glString:"Version" enu:GL_VERSION];
}

+ (NSArray<NSString *> *)supportedExtensions:(BOOL)legacy
{
    if (legacy) {
        const GLubyte *ext = glGetString(GL_EXTENSIONS);
        NSString *extStr = [NSString stringWithFormat:@"%s",ext];
        if (extStr.length > 0) {
            NSArray *r = [extStr componentsSeparatedByString:@" "];
            if ([[r lastObject] length] == 0) {
                return [r subarrayWithRange:NSMakeRange(0, [r count] - 1)];
            } else {
                return r;
            }
        }
    } else {
        GLint exts;
        glGetIntegerv(GL_NUM_EXTENSIONS, &exts);
        NSMutableArray *r = [NSMutableArray array];
        for (int n = 0; n < exts; n++) {
            const GLubyte *ext = glGetStringi(GL_EXTENSIONS, n);
            if (strlen((const char *)ext) > 0) {
                [r addObject:[NSString stringWithFormat:@"%s",ext]];
            }
        }
        return r;
    }
    return nil;
}

//https://www.khronos.org/opengl/wiki/Legacy_OpenGL

+ (NSOpenGLContext *)glContext:(BOOL)legacy
{
    NSOpenGLPixelFormat *pf = nil;
    if (legacy) {
        NSOpenGLPixelFormatAttribute attrs[] =
        {
            NSOpenGLPFAAccelerated,
            NSOpenGLPFANoRecovery,
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFADepthSize, 24,
            NSOpenGLPFAAllowOfflineRenderers, 1,
            0
        };
        
        pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    } else {
        NSOpenGLPixelFormatAttribute attrs[] =
        {
            NSOpenGLPFAAccelerated,
            NSOpenGLPFANoRecovery,
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFADepthSize, 24,
            NSOpenGLPFAAllowOfflineRenderers, 1,
            NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
            0
        };
        
        pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    }
    
    if (pf)
    {
        NSOpenGLContext* context = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
        return context;
    }
    return nil;
}

+ (void)prepareOpenGLContext:(void(^)(void))completion forLegacy:(BOOL)legacy
{
    if (!completion) {
        return;
    }
    
    NSOpenGLContext *glContext = [self glContext:legacy];
    [glContext makeCurrentContext];
    CGLLockContext([glContext CGLContextObj]);
    
    completion();
    
    CGLUnlockContext([glContext CGLContextObj]);
}

+ (NSString *)openglAllInfo:(BOOL)legacy
{
    NSMutableString *txt = [NSMutableString string];
    
    {
        //版本
        [txt appendFormat:@"\n【%@ OpenGL Info】\n",legacy ? @"Legacy" : @"Modern"];
    }
    
    {
        //版本
        [txt appendFormat:@"\n%@\n",[self version]];
    }
    
    {
        //厂商
        [txt appendFormat:@"\n%@\n",[self vendor]];
    }
    
    {
        //渲染器
        [txt appendFormat:@"\n%@\n",[self renderer]];
    }
    
    {
        //GL_SHADING_LANGUAGE_VERSION
        [txt appendFormat:@"\n%@\n",[self glslVersion]];
    }
    
    {
        //扩展
        [txt appendFormat:@"\nExtensions=%@\n",[self supportedExtensions:legacy]];
    }
    
    return [txt copy];
}

@end
