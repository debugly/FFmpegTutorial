//
//  MR0x141OpenGLHelper.c
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/9/30.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x141OpenGLHelper.h"
#import <Foundation/Foundation.h>

void printf_opengl_string(const char *name, GLenum s)
{
    const char *v = (const char *) glGetString(s);
    NSLog(@"[OpenGL] %s = %s\n", name, v);
}

void MR_checkGLError(const char* op) {
    for (GLint error = glGetError(); error; error = glGetError()) {
        printf("[GL] after %s() glError (0x%x)\n", op, error);
    }
}
const char * GetGLErrorString(GLenum error)
{
    const char *str;
    switch( error )
    {
        case GL_NO_ERROR:
            str = "GL_NO_ERROR";
            break;
        case GL_INVALID_ENUM:
            str = "GL_INVALID_ENUM";
            break;
        case GL_INVALID_VALUE:
            str = "GL_INVALID_VALUE";
            break;
        case GL_INVALID_OPERATION:
            str = "GL_INVALID_OPERATION";
            break;
        case GL_OUT_OF_MEMORY:
            str = "GL_OUT_OF_MEMORY";
            break;
        case GL_INVALID_FRAMEBUFFER_OPERATION:
            str = "GL_INVALID_FRAMEBUFFER_OPERATION";
            break;
#if defined __gl_h_
        case GL_STACK_OVERFLOW:
            str = "GL_STACK_OVERFLOW";
            break;
        case GL_STACK_UNDERFLOW:
            str = "GL_STACK_UNDERFLOW";
            break;
        case GL_TABLE_TOO_LARGE:
            str = "GL_TABLE_TOO_LARGE";
            break;
#endif
        default:
            str = "(ERROR: Unknown Error Enum)";
            break;
    }
    return str;
}

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
const float kColorConversion601[9] = {
        1.164,  1.164, 1.164,
          0.0, -0.392, 2.017,
        1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
const float kColorConversion709[9] = {
        1.164,  1.164, 1.164,
          0.0, -0.213, 2.112,
        1.793, -0.533,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
const float kColorConversion601FullRange[9] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

// for yuv422. OpenGL API接受的矩阵要求是列主序的，如果一个OpenGL的应用使用的是行主序的矩阵，那么在将矩阵传给OpenGL API前，需要先转换为列主序；数学上是行主序的，因此需要先转置。
const float kColorConversionYUV422[9] = {
    1.164383,  1.164383,  1.164383,
    0.000000, -0.391762, 2.017232,
    1.596027,  -0.812968,  0.000000,
};
