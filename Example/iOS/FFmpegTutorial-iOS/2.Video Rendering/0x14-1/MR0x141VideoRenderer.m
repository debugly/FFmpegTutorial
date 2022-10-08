//
//  MR0x141VideoRenderer.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/10/1.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x141VideoRenderer.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <AVFoundation/AVUtilities.h>
#import "MR0x141OpenGLHelper.h"
#import "MR0x141OpenGLCompiler.h"

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

@interface MR0x141VideoRenderer ()
{
    GLint uniforms[NUM_UNIFORMS];
    GLint attributers[NUM_ATTRIBUTES];

    // The pixel dimensions of the CAEAGLLayer.
    GLint _backingWidth;
    GLint _backingHeight;

    EAGLContext *_context;
    //for iphone
    CVOpenGLESTextureRef _brgaTexture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
    //for simulator
    GLuint _bgraTextureS;
    
    GLuint _frameBufferHandle;
    GLuint _colorBufferHandle;
}

@property MR0x141OpenGLCompiler* openglCompiler;

@end

@implementation MR0x141VideoRenderer

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        self.contentScaleFactor = [[UIScreen mainScreen] scale];

        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;

        eaglLayer.opaque = TRUE;
        eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking : [NSNumber numberWithBool:NO],
                                          kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8};

        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

        if (!_context || ![EAGLContext setCurrentContext:_context]) {
            return nil;
        }
        
        [self setupGL];
    }
    return self;
}

# pragma mark - OpenGL setup

- (void)setupGL
{
    [EAGLContext setCurrentContext:_context];
    
    if (!self.openglCompiler) {
        self.openglCompiler = [[MR0x141OpenGLCompiler alloc] initWithvshName:@"common.vsh" fshName:@"1_sampler2D.fsh"];

        if ([self.openglCompiler compileIfNeed]) {
            // Get uniform locations.
            uniforms[UNIFORM_0] = [self.openglCompiler getUniformLocation:"Sampler0"];
            attributers[ATTRIB_VERTEX] = [self.openglCompiler getAttribLocation:"position"];
            attributers[ATTRIB_TEXCOORD] = [self.openglCompiler getAttribLocation:"texCoord"];
            
            [self setupBuffers];
        }
    }
    VerifyGL(;);
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

- (void)cleanUpTextures
{
    if (_brgaTexture) {
        CFRelease(_brgaTexture);
        _brgaTexture = NULL;
    }
    
    if (_videoTextureCache) {
        // Periodic texture cache flush every frame
        CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
    }
}

- (void)dealloc
{
    [self cleanUpTextures];
    
    if (_bgraTextureS) {
        glDeleteTextures(1, &_bgraTextureS);
        _bgraTextureS = 0;
    }
    
    if (_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
    
    glDeleteFramebuffers(1, &_frameBufferHandle);
    glDeleteRenderbuffers(1, &_colorBufferHandle);
}

#pragma mark - OpenGLES drawing

- (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop

#endif
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (!pixelBuffer) {
        return;
    }
    
    [EAGLContext setCurrentContext:_context];
    // Use shader program.
    [self.openglCompiler active];
    
    VerifyGL(;);
    glActiveTexture(GL_TEXTURE0);
    VerifyGL(;);
    glUniform1i(uniforms[UNIFORM_0], 0);
    VerifyGL(;);
    int frameWidth  = (int)CVPixelBufferGetWidth(pixelBuffer);
    int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    if ([self supportsFastTextureUpload]) {
        // Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
        if (!_videoTextureCache) {
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
            if (err != noErr) {
                NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
                return;
            }
        }
        
        [self cleanUpTextures];
        
        /*
         CVOpenGLESTextureCacheCreateTextureFromImage will create GLES texture optimally from CVPixelBufferRef.
         */
        CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RGBA,
                                                           frameWidth,
                                                           frameHeight,
                                                           GL_BGRA,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &_brgaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        glBindTexture(CVOpenGLESTextureGetTarget(_brgaTexture), CVOpenGLESTextureGetName(_brgaTexture));
    } else {
        if (!_bgraTextureS) {
            glGenTextures(1, &_bgraTextureS);
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        glBindTexture(GL_TEXTURE_2D, _bgraTextureS);
        //internalformat 必须是 GL_RGBA，与创建 OpenGL 上下文指定的格式一样；
        //format 是当前数据的格式，可以是 GL_BGRA 也可以是 GL_RGBA，根据实际情况；但 CVPixelBufferRef 是不支持 RGBA 的；
        //这里指定好格式后，将会自动转换好对应关系，shader 无需做额外处理。
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, frameWidth, frameHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(pixelBuffer));
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    VerifyGL(;);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    // Set the view port to the entire view.
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
    VerifyGL(;);
    // Compute normalized quad coordinates to draw the frame into.
    // Compute normalized quad coordinates to draw the frame into.
    CGSize normalizedSamplingSize = CGSizeMake(1.0, 1.0);

    if (_contentMode == MRViewContentModeScaleAspectFit0x141 || _contentMode == MRViewContentModeScaleAspectFill0x141) {
        const size_t pictureWidth = CVPixelBufferGetWidth(pixelBuffer);
        const size_t pictureHeight = CVPixelBufferGetHeight(pixelBuffer);
        // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
        CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(pictureWidth, pictureHeight), self.layer.bounds);

        CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/self.layer.bounds.size.width, vertexSamplingRect.size.height/self.layer.bounds.size.height);

        // hold max
        if (_contentMode == MRViewContentModeScaleAspectFit0x141) {
            if (cropScaleAmount.width > cropScaleAmount.height) {
                normalizedSamplingSize.width = 1.0;
                normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
            }
            else {
                normalizedSamplingSize.height = 1.0;
                normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
            }
        } else if (_contentMode == MRViewContentModeScaleAspectFill0x141) {
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
    glVertexAttribPointer(attributers[ATTRIB_VERTEX], 2, GL_FLOAT, 0, 0, quadVertexData);
    glEnableVertexAttribArray(attributers[ATTRIB_VERTEX]);
    
    GLfloat quadTextureData[] =  { // 坐标不对可能导致画面显示方向不对
        0, 1,
        1, 1,
        0, 0,
        1, 0,
    };
    
    glVertexAttribPointer(attributers[ATTRIB_TEXCOORD], 2, GL_FLOAT, 0, 0, quadTextureData);
    glEnableVertexAttribArray(attributers[ATTRIB_TEXCOORD]);
    VerifyGL(;);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    VerifyGL(;);
}

@end

