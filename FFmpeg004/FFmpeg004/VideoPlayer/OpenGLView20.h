//
//  OpenGLView20.h
//  MyTest
//
//  Created by smy  on 12/20/11.
//  Copyright (c) 2011 ZY.SYM. All rights reserved.
//iOS中最少应有两个纹理单元，最多拥有8个

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/EAGL.h>
#include <sys/time.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include "pixfmt.h"


#define MAX_PLANES  3
typedef unsigned char   BYTE;
@interface OpenGLView20 : UIImageView
{
    @public
	/**
	 OpenGL绘图上下文
	 */
    EAGLContext             *_glContext;
	
	/**
	 帧缓冲区
	 */
    GLuint                  _framebuffer;
	
	/**
	 渲染缓冲区
	 */
    GLuint                  _renderBuffer;
	
	/**
	 着色器句柄
	 */
    GLuint                  _program;
	
	/**
	 YUV纹理数组
	 */
    GLuint                  _textureYUV[3];
	
	/**
	 视频宽度
	 */
    GLint                  _videoW;
	
	/**
	 视频高度
	 */
    GLint                  _videoH;
    
    GLsizei                 _viewScale;
    
    //void                    *_pYuvData;
    
    AVFrame                 *_pFrame;
    GLfloat         _vertices[8];
    GLint           _uniformMatrix;
    GLint _uniformSamplers[3];
    
#ifdef DEBUG
    struct timeval      _time;
    NSInteger           _frameRate;
    
#endif
    
}

#pragma mark - 接口
- (void)displayYUV420pData:(AVFrame *)pframe;

/**
 清除画面
 */
- (void)clearFrame;

@end
