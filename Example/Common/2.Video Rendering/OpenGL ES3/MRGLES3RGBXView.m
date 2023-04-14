//
//  MRGLES3RGBXView.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/12/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRGLES3RGBXView.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <AVFoundation/AVUtilities.h>
#import <libavutil/frame.h>
#import "MROpenGLHelper.h"
#import "MROpenGLCompiler.h"

// Uniform index.
enum
{
    UNIFORM_0,
    NUM_UNIFORMS
};

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

@interface MRGLES3RGBXView ()
{
    GLint _uniforms[NUM_UNIFORMS];
    GLint _attributers[NUM_ATTRIBUTES];
    MRRenderingMode _renderingMode;
    
    // The pixel dimensions of the CAEAGLLayer.
    GLint _backingWidth;
    GLint _backingHeight;

    EAGLContext *_context;
    
    GLuint _frameBufferHandle;
    GLuint _colorBufferHandle;
}

@property MROpenGLCompiler* openglCompiler;

@end

@implementation MRGLES3RGBXView

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (BOOL)setup
{
    self.contentScaleFactor = [[UIScreen mainScreen] scale];

    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;

    eaglLayer.opaque = TRUE;
    eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking : [NSNumber numberWithBool:NO],
                                      kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8};

    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        return NO;
    }
    
    return [self setupGL];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setup];
    }
    return self;
}

# pragma mark - OpenGL setup

- (BOOL)setupGL
{
    [EAGLContext setCurrentContext:_context];
    
    if (!self.openglCompiler) {
        self.openglCompiler = [[MROpenGLCompiler alloc] initWithvshName:@"common_es3.vsh" fshName:@"1_sampler2D_es3.fsh"];

        if ([self.openglCompiler compileIfNeed]) {
            // Get uniform locations.
            _uniforms[UNIFORM_0] = [self.openglCompiler getUniformLocation:"Sampler0"];
            _attributers[ATTRIB_VERTEX] = [self.openglCompiler getAttribLocation:"position"];
            _attributers[ATTRIB_TEXCOORD] = [self.openglCompiler getAttribLocation:"texCoord"];
            
            [self setupBuffers];
            return YES;
        }
    }
    VerifyGL(;);
    return NO;
}

#pragma mark - Utilities

- (void)setupBuffers
{
    glDisable(GL_DEPTH_TEST);
    
    glGenFramebuffers(1, &_frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    glGenRenderbuffers(1, &_colorBufferHandle);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBufferHandle);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
    VerifyGL(;);
}

- (void)dealloc
{
    glDeleteFramebuffers(1, &_frameBufferHandle);
    glDeleteRenderbuffers(1, &_colorBufferHandle);
    VerifyGL(;);
}

- (void)setRenderingMode:(MRRenderingMode)renderingMode
{
    _renderingMode = renderingMode;
}

- (MRRenderingMode)renderingMode
{
    return _renderingMode;
}

#pragma mark - OpenGLES drawing

- (void)uploadFrameToTexture:(AVFrame * _Nonnull)frame
{
    //设置纹理和采样器的对应关系
    glUniform1i(_uniforms[UNIFORM_0], 0);
    glActiveTexture(GL_TEXTURE0);
    //internalformat 必须是 GL_RGBA，与创建 OpenGL 上下文指定的格式一样；
    //format 是当前数据的格式，可以是 GL_BGRA 也可以是 GL_RGBA，根据实际情况；
    //这里指定好格式后，将会自动转换好对应关系，shader 无需做额外处理。
    GLenum format = 0;
    if (frame->format == AV_PIX_FMT_BGRA) {
        format = GL_BGRA;
    } else if (frame->format == AV_PIX_FMT_BGR0) {
        format = GL_BGRA;
    } else if (frame->format == AV_PIX_FMT_RGBA) {
        format = GL_RGBA;
    } else if (frame->format == AV_PIX_FMT_RGB0) {
        format = GL_RGBA;
    } else {
        NSAssert(NO, @"can't support format:%d",format);
    }

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, frame->width, frame->height, 0, format, GL_UNSIGNED_BYTE, frame->data[0]);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (CGSize)computeNormalizedSize:(AVFrame * _Nonnull)frame
{
    GLsizei frameWidth = frame->width;
    GLsizei frameHeight = frame->height;
    // Compute normalized quad coordinates to draw the frame into.
    CGSize normalizedSamplingSize = CGSizeMake(1.0, 1.0);
    CGRect _layerBounds = CGRectMake(0, 0, _backingWidth, _backingHeight);
    
    if (_renderingMode == MRRenderingModeScaleAspectFit || _renderingMode == MRRenderingModeScaleAspectFill) {
        // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
        CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(frameWidth, frameHeight), _layerBounds);
        
        CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/_layerBounds.size.width, vertexSamplingRect.size.height/_layerBounds.size.height);
        
        // hold max
        if (_renderingMode == MRRenderingModeScaleAspectFit) {
            if (cropScaleAmount.width > cropScaleAmount.height) {
                normalizedSamplingSize.width = 1.0;
                normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
            }
            else {
                normalizedSamplingSize.height = 1.0;
                normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
            }
        } else if (_renderingMode == MRRenderingModeScaleAspectFill) {
            // hold min
            if (cropScaleAmount.width > cropScaleAmount.height) {
                normalizedSamplingSize.height = 1.0;
                normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
            }
            else {
                normalizedSamplingSize.width = 1.0;
                normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
            }
        }
    }
    return normalizedSamplingSize;
}

- (void)displayAVFrame:(AVFrame *)frame
{
    if (!frame) {
        return;
    }
    
    [EAGLContext setCurrentContext:_context];
    // Use shader program.
    [self.openglCompiler active];
    VerifyGL(;);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    VerifyGL(;);
    [self uploadFrameToTexture:frame];
    VerifyGL(;);
    CGSize normalizedSamplingSize = [self computeNormalizedSize:frame];
    
    /*
     The quad vertex data defines the region of 2D plane onto which we draw our pixel buffers.
     Vertex data formed using (-1,-1) and (1,1) as the bottom left and top right coordinates respectively, covers the entire screen.
     */
    GLfloat quadVertexData [] = {
        -1 * normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        -1 * normalizedSamplingSize.width, normalizedSamplingSize.height,
        normalizedSamplingSize.width, normalizedSamplingSize.height,
    };
    
    // 更新顶点数据
    glVertexAttribPointer(_attributers[ATTRIB_VERTEX], 2, GL_FLOAT, 0, 0, quadVertexData);
    glEnableVertexAttribArray(_attributers[ATTRIB_VERTEX]);
    GLfloat quadTextureData[] = { // 坐标不对可能导致画面显示方向不对
        0, 1,
        1, 1,
        0, 0,
        1, 0,
    };
    
    glVertexAttribPointer(_attributers[ATTRIB_TEXCOORD], 2, GL_FLOAT, 0, 0, quadTextureData);
    glEnableVertexAttribArray(_attributers[ATTRIB_TEXCOORD]);
    
    VerifyGL(;);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    // Set the view port to the entire view.
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    VerifyGL(;);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    VerifyGL(;);
}

@end

