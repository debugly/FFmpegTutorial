//
//  FFTVideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/10/6
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "FFTVideoRenderer.h"
#import <OpenGL/gl.h>
#import <OpenGL/gl3.h>
#import <OpenGL/glext.h>
#import <OpenGL/gl3ext.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>
#import <GLKit/GLKit.h>
#import "FFTOpenGLCompiler.h"
#import <libavutil/frame.h>
#import "FFTConvertUtil.h"
#import "FFTShaderFile.h"

// Uniform index.
enum
{
    UNIFORM_0,
    UNIFORM_1,
    NUM_UNIFORMS
};

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

@interface FFTVideoRenderer ()
{
    //color conversion matrix uniform
    GLint _ccmUniform;
    GLint _uniforms[NUM_UNIFORMS];
    GLint _textureDimensions[NUM_UNIFORMS];
    GLint _attributers[NUM_ATTRIBUTES];
    GLuint _textures[NUM_UNIFORMS];
    CGRect _layerBounds;
    MRViewContentMode _contentMode;
    /// 顶点对象
    GLuint _vbo;
    GLuint _vao;
    
    AVFrame * _lastFrame;
    
    CGSize _fboTextureSize;
    GLuint _fbo;
    GLuint _colorTexture;
}

@property FFTOpenGLCompiler * openglCompiler;

@end

@implementation FFTVideoRenderer

- (void)dealloc
{
    glDeleteBuffers(1, &_vbo);
    glDeleteVertexArrays(1, &_vao);
    glDeleteTextures(sizeof(_textures)/sizeof(GLuint), _textures);
    [self destroyFBO];
    av_frame_free(&_lastFrame);
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        [self prepareGLContext];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self prepareGLContext];
    }
    return self;
}

- (void)prepareGLContext
{
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0
    };
    NSOpenGLPixelFormat *pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    
    if (!pf)
    {
        NSLog(@"No OpenGL pixel format");
    }
    
    NSOpenGLContext* context = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
    
#if defined(DEBUG)
    // When we're using a CoreProfile context, crash if we call a legacy OpenGL function
    // This will make it much more obvious where and when such a function call is made so
    // that we can remove such calls.
    // Without this we'd simply get GL_INVALID_OPERATION error for calling legacy functions
    // but it would be more difficult to see where that function was called.
    CGLEnable([context CGLContextObj], kCGLCECrashOnRemovedFunctions);
#endif
    [self setPixelFormat:pf];
    [self setOpenGLContext:context];
    [self setWantsBestResolutionOpenGLSurface:YES];
    
    [self drawInitBackgroundColor];
    _lastFrame = av_frame_alloc();
}

- (void)drawInitBackgroundColor
{
    [[self openGLContext] makeCurrentContext];
    CGLLockContext([[self openGLContext] CGLContextObj]);
    glClearColor(0.2,0.2,0.2,0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    CGLFlushDrawable([[self openGLContext] CGLContextObj]);
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

- (void)setupOpenGLProgram
{
    if (!self.openglCompiler) {
        
        self.openglCompiler = [[FFTOpenGLCompiler alloc] initWithvsh:[FFTShaderFile commonV3vsh]
                                                                fsh:[FFTShaderFile nv12RectV3fhs]];
        
        if ([self.openglCompiler compileIfNeed]) {
            // Get uniform locations.
            _uniforms[UNIFORM_0] = [self.openglCompiler getUniformLocation:"Sampler0"];
            _uniforms[UNIFORM_1] = [self.openglCompiler getUniformLocation:"Sampler1"];
            _textureDimensions[UNIFORM_0] = [self.openglCompiler getUniformLocation:"textureDimension0"];
            _textureDimensions[UNIFORM_1] = [self.openglCompiler getUniformLocation:"textureDimension1"];
            
            _ccmUniform = [self.openglCompiler getUniformLocation:"colorConversionMatrix"];
            
            _attributers[ATTRIB_VERTEX]   = [self.openglCompiler getAttribLocation:"position"];
            _attributers[ATTRIB_TEXCOORD] = [self.openglCompiler getAttribLocation:"texCoord"];
            
            glGenVertexArrays(1, &_vao);
            /// 创建顶点缓存对象
            glGenBuffers(1, &_vbo);
            
            glGenTextures(sizeof(_textures)/sizeof(GLuint), _textures);
        }
    }
}

- (void)resetViewPort
{
    // We draw on a secondary thread through the display link. However, when
    // resizing the view, -drawRect is called on the main thread.
    // Add a mutex around to avoid the threads accessing the context
    // simultaneously when resizing.
    CGLLockContext([[self openGLContext] CGLContextObj]);
    
    // Get the view size in Points
    _layerBounds = [self bounds];
    
    NSRect viewRectPixels = [self convertRectToBacking:_layerBounds];
    
    GLsizei backingWidth = viewRectPixels.size.width;
    GLsizei backingHeight = viewRectPixels.size.height;
    // Set the new dimensions in our renderer
    glViewport(0, 0, backingWidth, backingHeight);
    
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

- (void)initGL
{
    // The reshape function may have changed the thread to which our OpenGL
    // context is attached before prepareOpenGL and initGL are called.  So call
    // makeCurrentContext to ensure that our OpenGL context current to this
    // thread (i.e. makeCurrentContext directs all OpenGL calls on this thread
    // to [self openGLContext])
    [[self openGLContext] makeCurrentContext];
    
    // Synchronize buffer swaps with vertical refresh rate
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    
    [self setupOpenGLProgram];
    
    glDisable(GL_DEPTH_TEST);
    //glEnable(GL_TEXTURE_RECTANGLE);
    glGenTextures(sizeof(_textures)/sizeof(GLuint), _textures);
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];

    // Make all the OpenGL calls to setup rendering
    //  and build the necessary rendering objects
    [self initGL];
}

- (void)reshape
{
    [super reshape];
    [self resetViewPort];
}

- (void)setContentMode:(MRViewContentMode)contentMode
{
    _contentMode = contentMode;
}

- (MRViewContentMode)contentMode
{
    return _contentMode;
}

- (void)uploadFrameToTexture:(AVFrame * _Nonnull)frame
{
    //for y plane
    {
        //设置纹理和采样器的对应关系
        glUniform1i(_uniforms[UNIFORM_0], 0);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_RECTANGLE, _textures[0]);
        
        //设置矩形纹理尺寸
        glUniform2f(_textureDimensions[UNIFORM_0], frame->width, frame->height);
        //opengl 3 error: GL_INVALID_ENUM GL_LUMINANCE
        glTexImage2D(GL_TEXTURE_RECTANGLE, 0, GL_RED, frame->width, frame->height, 0, GL_RED, GL_UNSIGNED_BYTE, frame->data[0]);
        VerifyGL(;);
        glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    VerifyGL(;);
    //for uv plane
    {
        //设置纹理和采样器的对应关系
        glUniform1i(_uniforms[UNIFORM_1], 1);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_RECTANGLE, _textures[1]);
        //设置矩形纹理尺寸
        glUniform2f(_textureDimensions[UNIFORM_1], frame->width/2, frame->height/2);
        
        //opengl 3 error: GL_INVALID_ENUM GL_LUMINANCE_ALPHA
        glTexImage2D(GL_TEXTURE_RECTANGLE, 0, GL_RG, frame->width/2, frame->height/2, 0, GL_RG, GL_UNSIGNED_BYTE, frame->data[1]);
        VerifyGL(;);
        glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    VerifyGL(;);
}

- (CGSize)computeNormalizedSize:(AVFrame * _Nonnull)frame
{
    GLsizei frameWidth = frame->width;
    GLsizei frameHeight = frame->height;
    // Compute normalized quad coordinates to draw the frame into.
    CGSize normalizedSamplingSize = CGSizeMake(1.0, 1.0);
    
    if (_contentMode == MRViewContentModeScaleAspectFit || _contentMode == MRViewContentModeScaleAspectFill) {
        // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
        CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(frameWidth, frameHeight), _layerBounds);
        
        CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/_layerBounds.size.width, vertexSamplingRect.size.height/_layerBounds.size.height);
        
        // hold max
        if (_contentMode == MRViewContentModeScaleAspectFit) {
            if (cropScaleAmount.width > cropScaleAmount.height) {
                normalizedSamplingSize.width = 1.0;
                normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
            }
            else {
                normalizedSamplingSize.height = 1.0;
                normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
            }
        } else if (_contentMode == MRViewContentModeScaleAspectFill) {
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

- (void)updateArrayBuffer:(CGSize)normalizedSamplingSize
{
    /*
     The quad vertex data defines the region of 2D plane onto which we draw our pixel buffers.
     Vertex data formed using (-1,-1) and (1,1) as the bottom left and top right coordinates respectively, covers the entire screen.
     */
    GLfloat quadData [] = {
        -1 * normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        -1 * normalizedSamplingSize.width, normalizedSamplingSize.height,
        normalizedSamplingSize.width, normalizedSamplingSize.height,
        //Texture Postition
        0, 1,
        1, 1,
        0, 0,
        1, 0,
    };
    
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    /// 将CPU数据发送到GPU,数据类型GL_ARRAY_BUFFER
    /// GL_STATIC_DRAW 表示数据不会被修改,将其放置在GPU显存的更合适的位置,增加其读取速度
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadData), quadData, GL_DYNAMIC_DRAW);
    
    // 更新顶点数据
    glBindVertexArray(_vao);
    glEnableVertexAttribArray(_attributers[ATTRIB_VERTEX]);
    glEnableVertexAttribArray(_attributers[ATTRIB_TEXCOORD]);
    /// 指定顶点着色器位置为0的参数的数据读取方式与数据类型
    /// 第一个参数: 参数位置
    /// 第二个参数: 一次读取数据
    /// 第三个参数: 数据类型
    /// 第四个参数: 是否归一化数据
    /// 第五个参数: 间隔多少个数据读取下一次数据
    /// 第六个参数: 指定读取第一个数据在顶点数据中的偏移量
    glVertexAttribPointer(_attributers[ATTRIB_VERTEX], 2, GL_FLOAT, GL_FALSE, 0, (void*)0);
    
    // texture coord attribute
    glVertexAttribPointer(_attributers[ATTRIB_TEXCOORD], 2, GL_FLOAT, GL_FALSE, 0, (void*)(8 * sizeof(float)));
}

- (void)drawFrame:(AVFrame * _Nonnull)frame
{
    glUniformMatrix3fv(_ccmUniform, 1, GL_FALSE, kColorConversion709);
    VerifyGL(;);
    
    [self uploadFrameToTexture:frame];
    VerifyGL(;);
    
    CGSize normalizedSamplingSize = [self computeNormalizedSize:frame];
    [self updateArrayBuffer:normalizedSamplingSize];
    VerifyGL(;);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    VerifyGL(;)
}

- (void)displayAVFrame:(AVFrame *)frame
{
    av_frame_ref(_lastFrame, frame);
    
    [[self openGLContext] makeCurrentContext];
    CGLLockContext([[self openGLContext] CGLContextObj]);
    
    [self.openglCompiler active];
    glClearColor(0.0,0.0,0.0,0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    [self drawFrame:frame];
    
    CGLFlushDrawable([[self openGLContext] CGLContextObj]);
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

- (void)destroyFBO
{
    glDeleteFramebuffers(1, &_fbo);
    glDeleteFramebuffers(1, &_colorTexture);
    _fboTextureSize = CGSizeZero;
}

// Create texture and framebuffer objects to render and snapshot.
- (BOOL)prepareFBOIfNeed:(CGSize)size
{
    if (CGSizeEqualToSize(CGSizeZero, size)) {
        return NO;
    }
    
    if (CGSizeEqualToSize(_fboTextureSize, size)) {
        return YES;
    } else {
        [self destroyFBO];
    }
    
    // Create a texture object that you apply to the model.
    glGenTextures(1, &_colorTexture);
    glBindTexture(GL_TEXTURE_2D, _colorTexture);

    // Set up filter and wrap modes for the texture object.
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // Mipmap generation is not accelerated on iOS, so you can't enable trilinear filtering.
#if TARGET_IOS
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
#else
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
#endif

    // Allocate a texture image to which you can render to. Pass `NULL` for the data parameter
    // becuase you don't need to load image data. You generate the image by rendering to the texture.
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                 size.width, size.height, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    glGenFramebuffers(1, &_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _colorTexture, 0);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) {
        _fboTextureSize = size;
        return YES;
    } else {
    #if DEBUG
        NSAssert(NO, @"Failed to make complete framebuffer object %x.",  glCheckFramebufferStatus(GL_FRAMEBUFFER));
    #endif
        return NO;
    }
}

- (NSImage *)snapshot
{
    if (_lastFrame) {
        CGSize picSize = self.videoSize;
        if ([self prepareFBOIfNeed:picSize]) {
            [[self openGLContext] makeCurrentContext];
            CGLLockContext([[self openGLContext] CGLContextObj]);
            
            // Bind the snapshot FBO and render the scene.
            glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
            glViewport(0, 0, picSize.width, picSize.height);
            // Bind the texture that you previously render to (i.e. the snapshot texture).
            glBindTexture(GL_TEXTURE_2D, _colorTexture);
            
            [self drawFrame:_lastFrame];
            
            CGLFlushDrawable([[self openGLContext] CGLContextObj]);
            
            NSImage *img = [FFTConvertUtil snapshotFBO:_colorTexture size:picSize];
            
            // Bind the default FBO to render to the screen.
            NSSize pixelSize = [self convertSizeToBacking:self.bounds.size];
            glViewport(0, 0, pixelSize.width, pixelSize.height);
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            
            CGLUnlockContext([[self openGLContext] CGLContextObj]);
            
            return img;
        }
    }
    return nil;
}

@end
