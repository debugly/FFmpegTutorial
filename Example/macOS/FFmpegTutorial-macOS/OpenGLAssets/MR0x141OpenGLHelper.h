//
//  MR0x141OpenGLHelper.h
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/9/30.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#ifndef MR0x141OpenGLHelper_h
#define MR0x141OpenGLHelper_h

#import <stdio.h>
#import <OpenGL/gl.h>

void MR_checkGLError(const char* op);
const char * GetGLErrorString(GLenum error);
void printf_opengl_string(const char *name, GLenum s);

#if DEBUG
#define debug_opengl_string(name,s) printf_opengl_string(name,s)
#else
#define debug_opengl_string(name,s)
#endif

#define VerifyGL(_f) \
{                    \
    _f;              \
    GLenum err = glGetError(); \
    while (err != GL_NO_ERROR)  \
    {  \
        NSLog(@"GLError: %s set in File:%s Line:%d\n", GetGLErrorString(err), __FILE__, __LINE__); \
        assert(0); \
        err = glGetError(); \
    } \
}
// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
extern const float kColorConversion601[9];

// BT.709, which is the standard for HDTV.
extern const float kColorConversion709[9];

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
extern const float kColorConversion601FullRange[9];

// for yuv422. (ref https://gist.github.com/roxlu/5795504)
extern const float kColorConversionYUV422[9];

#endif /* MR0x141OpenGLHelper_h */
