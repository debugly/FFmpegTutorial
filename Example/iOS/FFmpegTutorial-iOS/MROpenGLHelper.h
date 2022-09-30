//
//  MROpenGLHelper.h
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/9/30.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#ifndef MROpenGLHelper_h
#define MROpenGLHelper_h

#include <stdio.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>

const char * GetGLErrorString(GLenum error);

#define VerifyGL(_f) \
{                    \
    _f;              \
    GLenum err = glGetError(); \
    while (err != GL_NO_ERROR)  \
    {  \
        NSLog(@"GLError: %s set in File:%s Line:%d\n", GetGLErrorString(err), __FILE__, __LINE__); \
        err = glGetError(); \
    } \
}

#endif /* MROpenGLHelper_h */
