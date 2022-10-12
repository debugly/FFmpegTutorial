//
//  MR0x151VideoRenderer.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/7/10.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x151VideoRenderer.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <AVFoundation/AVUtilities.h>
#import "MR0x141OpenGLHelper.h"
#import "MR0x141OpenGLCompiler.h"

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

@interface MR0x151VideoRenderer ()
{
    //color conversion matrix uniform
    GLint ccmUniform;
    GLint uniforms[NUM_UNIFORMS];
    GLint attributers[NUM_ATTRIBUTES];
    
    // The pixel dimensions of the CAEAGLLayer.
    GLint _backingWidth;
    GLint _backingHeight;

    EAGLContext *_context;
    //for iphone
    CVOpenGLESTextureRef _textureRefs[NUM_UNIFORMS];
    CVOpenGLESTextureCacheRef _videoTextureCache;
    //for simulator
    GLuint _textures[NUM_UNIFORMS];
    
    GLuint _frameBufferHandle;
    GLuint _colorBufferHandle;
}

@property MR0x141OpenGLCompiler * openglCompiler;

@end

@implementation MR0x151VideoRenderer

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

        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

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
        self.openglCompiler = [[MR0x141OpenGLCompiler alloc] initWithvshName:@"common.vsh" fshName:@"2_sampler2D.fsh"];

        if ([self.openglCompiler compileIfNeed]) {
            for (int i = 0; i < NUM_UNIFORMS; i++) {
                // Get uniform locations.
                char name[10] = {0};
                sprintf(name, "Sampler%d",i);
                uniforms[UNIFORM_0 + i] = [self.openglCompiler getUniformLocation:name];
            }
            ccmUniform = [self.openglCompiler getUniformLocation:"colorConversionMatrix"];
            
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

- (void)dealloc
{
    int count = sizeof(_textureRefs)/sizeof(CVOpenGLESTextureRef);
    for (int i = 0; i < count; i ++) {
        CVOpenGLESTextureRef t = _textureRefs[i];
        if (t) {
            CFRelease(t);
            _textureRefs[i] = NULL;
        }
    }
    
    if (_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
    
    glDeleteTextures(sizeof(_textures)/sizeof(GLuint), _textures);
    
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
    
    CVReturn err;
    
    if ([EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context]; // 非常重要的一行代码
    }
    
    for (int i = 0; i < NUM_UNIFORMS; i ++) {
        
        glActiveTexture(GL_TEXTURE0 + i);
        glUniform1i(uniforms[UNIFORM_0 + i], i);
        
        int frameWidth  = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, i);
        int frameHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
        GLenum format = i == 0 ? GL_LUMINANCE : GL_LUMINANCE_ALPHA;
        
        if ([self supportsFastTextureUpload]) {
            // Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
            if (!_videoTextureCache) {
                CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
                if (err != noErr) {
                    NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
                    return;
                }
            }
            
            // Periodic texture cache flush every frame
            CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
            
            CVOpenGLESTextureRef *tp = &_textureRefs[i];
            if (*tp) {
                CFRelease(*tp);
                *tp = NULL;
            }
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               _videoTextureCache,
                                                               pixelBuffer,
                                                               NULL,
                                                               GL_TEXTURE_2D,
                                                               format,
                                                               frameWidth,
                                                               frameHeight,
                                                               format,
                                                               GL_UNSIGNED_BYTE,
                                                               i,
                                                               tp);
            if (err) {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            glBindTexture(CVOpenGLESTextureGetTarget(*tp), CVOpenGLESTextureGetName(*tp));
        } else {
            GLuint texture = _textures[i];
            if (!texture) {
                glGenTextures(1, &_textures[i]);
            }
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            glBindTexture(GL_TEXTURE_2D, texture);
            glTexImage2D(GL_TEXTURE_2D, 0, format, frameWidth, frameHeight, 0, format, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddressOfPlane(pixelBuffer,i));
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        }
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    // Set the view port to the entire view.
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUniformMatrix3fv(ccmUniform, 1, GL_FALSE, kColorConversion709);
    
    // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
    [self.openglCompiler active];
    // Compute normalized quad coordinates to draw the frame into.
    // Compute normalized quad coordinates to draw the frame into.
    CGSize normalizedSamplingSize = CGSizeMake(1.0, 1.0);

    if (_contentMode == MRViewContentModeScaleAspectFit0x151 || _contentMode == MRViewContentModeScaleAspectFill0x151) {
        const size_t pictureWidth = CVPixelBufferGetWidth(pixelBuffer);
        const size_t pictureHeight = CVPixelBufferGetHeight(pixelBuffer);
        // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
        CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(pictureWidth, pictureHeight), self.layer.bounds);

        CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/self.layer.bounds.size.width, vertexSamplingRect.size.height/self.layer.bounds.size.height);

        // hold max
        if (_contentMode == MRViewContentModeScaleAspectFit0x151) {
            if (cropScaleAmount.width > cropScaleAmount.height) {
                normalizedSamplingSize.width = 1.0;
                normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
            }
            else {
                normalizedSamplingSize.height = 1.0;
                normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
            }
        } else if (_contentMode == MRViewContentModeScaleAspectFill0x151) {
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
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    if ([EAGLContext currentContext] == _context) {
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
}

@end

