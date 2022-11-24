//
//  MR0x174VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/24.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x174VideoRenderer.h"
#import <OpenGL/gl.h>
#import <OpenGL/gl3.h>
#import <OpenGL/glext.h>
#import <OpenGL/gl3ext.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>
#import <GLKit/GLKit.h>
#import "MR0x141OpenGLCompiler.h"
#import <MRFFmpegPod/libavutil/frame.h>
#import "renderer_pixfmt.h"

#define GL_TEXTURE_TARGET GL_TEXTURE_RECTANGLE
#define USE_RECTANGLE 1
#define USE_IOSURFACE 0

// Uniform index.
enum
{
    UNIFORM_0,
    UNIFORM_1,
    UNIFORM_2,
    NUM_UNIFORMS
};

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

@interface MR0x174VideoRenderer ()
{
    //color conversion matrix uniform
    GLint _ccmUniform;
    GLint _uniforms[NUM_UNIFORMS];
    GLint _textureDimensions[NUM_UNIFORMS];
    GLint _attributers[NUM_ATTRIBUTES];
    GLuint _textures[NUM_UNIFORMS];
    CGRect _layerBounds;
    MR0x141ContentMode _contentMode;
    /// 顶点对象
    GLuint _vbo;
    GLuint _vao;
}

@property MR0x141OpenGLCompiler * openglCompiler;

@end

@implementation MR0x174VideoRenderer

- (void)dealloc
{
    glDeleteBuffers(1, &_vbo);
    glDeleteVertexArrays(1, &_vao);
    glDeleteTextures(sizeof(_textures)/sizeof(GLuint), _textures);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
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
    }
    return self;
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
        self.openglCompiler = [[MR0x141OpenGLCompiler alloc] initWithvshName:@"common_v3.vsh" fshName:@"3_sampler2D_Rect_v3.fsh"];
        
        if ([self.openglCompiler compileIfNeed]) {
            // Get uniform locations.
            _uniforms[UNIFORM_0] = [self.openglCompiler getUniformLocation:"Sampler0"];
            _uniforms[UNIFORM_1] = [self.openglCompiler getUniformLocation:"Sampler1"];
            _uniforms[UNIFORM_2] = [self.openglCompiler getUniformLocation:"Sampler2"];
            _textureDimensions[UNIFORM_0] = [self.openglCompiler getUniformLocation:"textureDimension0"];
            _textureDimensions[UNIFORM_1] = [self.openglCompiler getUniformLocation:"textureDimension1"];
            _textureDimensions[UNIFORM_2] = [self.openglCompiler getUniformLocation:"textureDimension2"];
            
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

- (void)setContentMode:(MR0x141ContentMode)contentMode
{
    _contentMode = contentMode;
}

- (MR0x141ContentMode)contentMode
{
    return _contentMode;
}

- (void)uploadFrameToTexture:(uint8_t *[AV_NUM_DATA_POINTERS])data size:(CGSize)size
{
    for (int i = 0; i < 3; i++) {
        int width = size.width;
        int height = size.height;
    
        if (i > 0) {
            width /= 2;
            height /= 2;
        }
        
        int offset = 0;
        
        //为了实现实时切换纹理上传的方式，因此各自创建了纹理，需要修改于采样器的对应关系。
        VerifyGL(glUniform1i(_uniforms[UNIFORM_0 + i], i + offset));
        VerifyGL(glActiveTexture(GL_TEXTURE0 + i + offset));
        VerifyGL(glBindTexture(GL_TEXTURE_TARGET, _textures[i + offset]));
        //设置矩形纹理尺寸
        VerifyGL(glUniform2f(_textureDimensions[UNIFORM_0 + i], width, height));
        
        glTexImage2D(GL_TEXTURE_RECTANGLE, 0, GL_RED, width, height, 0, GL_RED, GL_UNSIGNED_BYTE, data[i]);
        
        glTexParameteri(GL_TEXTURE_TARGET, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_TARGET, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_TARGET, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_TARGET, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}

- (BOOL)uploadTexture:(CVPixelBufferRef)pixelBuffer
{
    int width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    int height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);

    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    uint8 * src0 = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    uint8 * src1 = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    uint8 * src2 = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2);
    uint8 * data [3] = {src0,src1,src2};
    [self uploadFrameToTexture:data size:CGSizeMake(width, height)];

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    return succ;
}

- (BOOL)doUploadTexture2:(GLenum)gl_target pixelBuffer:(CVPixelBufferRef _Nonnull)pixelBuffer plane_format:(const struct vt_gl_plane_format *)plane_format i:(int)i
{
    int w = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, i);
    int h = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
#if USE_IOSURFACE
    IOSurfaceRef surface = CVPixelBufferGetIOSurface(pixelBuffer);
    
    CGLError err = CGLTexImageIOSurface2D(CGLGetCurrentContext(),
                                          gl_target,
                                          plane_format->gl_internal_format,
                                          w,
                                          h,
                                          plane_format->gl_format,
                                          plane_format->gl_type,
                                          surface,
                                          i);
    return err == kCGLNoError;
#else
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    glTexImage2D(gl_target, 0, plane_format->gl_internal_format, w, h, 0, plane_format->gl_format, plane_format->gl_type, CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i));
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return YES;
#endif
}

- (BOOL)uploadTexture2:(CVPixelBufferRef)pixelBuffer
{
    struct vt_format * f = vt_get_gl_format(kCVPixelFormatType_420YpCbCr8Planar);
    
    if (!f) {
        NSAssert(!f,@"please add pixel format:kCVPixelFormatType_32BGRA to renderer_pixfmt.h");
        return NO;
    }

    BOOL succ = NO;
    for (int i = 0; i < 3; i++) {
        struct vt_gl_plane_format plane_format = f->gl[i];
        //为了实现实时切换纹理上传的方式，因此各自创建了纹理，需要修改于采样器的对应关系。
        VerifyGL(glUniform1i(_uniforms[UNIFORM_0 + i], i));
        VerifyGL(glActiveTexture(GL_TEXTURE0 + i));
        VerifyGL(glBindTexture(GL_TEXTURE_TARGET, _textures[i]));
        //设置矩形纹理尺寸
        int w = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, i);
        int h = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
        VerifyGL(glUniform2f(_textureDimensions[UNIFORM_0 + i], w, h));
        
        succ = [self doUploadTexture2:GL_TEXTURE_TARGET pixelBuffer:pixelBuffer plane_format:&plane_format i:i];
        
        glTexParameteri(GL_TEXTURE_TARGET, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_TARGET, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_TARGET, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_TARGET, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    
    return succ;
}

- (CGSize)computeNormalizedSize:(CGSize)size
{
    GLsizei frameWidth = size.width;
    GLsizei frameHeight = size.height;
    // Compute normalized quad coordinates to draw the frame into.
    CGSize normalizedSamplingSize = CGSizeMake(1.0, 1.0);
    
    if (_contentMode == MR0x141ContentModeScaleAspectFit || _contentMode == MR0x141ContentModeScaleAspectFill) {
        // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
        CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(frameWidth, frameHeight), _layerBounds);
        
        CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/_layerBounds.size.width, vertexSamplingRect.size.height/_layerBounds.size.height);
        
        // hold max
        if (_contentMode == MR0x141ContentModeScaleAspectFit) {
            if (cropScaleAmount.width > cropScaleAmount.height) {
                normalizedSamplingSize.width = 1.0;
                normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
            }
            else {
                normalizedSamplingSize.height = 1.0;
                normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
            }
        } else if (_contentMode == MR0x141ContentModeScaleAspectFill) {
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

- (void)doDisplay:(CGSize(^)(void))block
{
    [[self openGLContext] makeCurrentContext];
    CGLLockContext([[self openGLContext] CGLContextObj]);
    
    [self.openglCompiler active];
    glClearColor(0.0,0.0,0.0,0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glUniformMatrix3fv(_ccmUniform, 1, GL_FALSE, kColorConversion709);
    VerifyGL(;);
    
    CGSize size = block();
    CGSize normalizedSamplingSize = [self computeNormalizedSize:size];
    [self updateArrayBuffer:normalizedSamplingSize];
    VerifyGL(;);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    VerifyGL(;);
    
    CGLFlushDrawable([[self openGLContext] CGLContextObj]);
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

- (void)displayAVFrame:(AVFrame *)frame
{
    [self doDisplay:^CGSize{
        [self uploadFrameToTexture:frame->data size:CGSizeMake(frame->width, frame->height)];
        VerifyGL(;);
        return CGSizeMake(frame->width, frame->height);
    }];
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    [self doDisplay:^CGSize{
        [self uploadTexture2:pixelBuffer];
        VerifyGL(;);
        int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        return CGSizeMake(frameWidth, frameHeight);
    }];
}

- (NSImage *)snapshot
{
    return nil;
}

@end
