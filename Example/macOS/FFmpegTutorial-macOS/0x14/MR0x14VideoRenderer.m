//
//  MR0x14VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x14VideoRenderer.h"
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>
#import <GLKit/GLKit.h>
#import "renderer_pixfmt.h"

// Uniform index.
enum
{
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};
static GLint uniforms[NUM_UNIFORMS];
static GLint textureDimension[2];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
static const GLfloat kColorConversion601[] = {
        1.164,  1.164, 1.164,
          0.0, -0.392, 2.017,
        1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
static const GLfloat kColorConversion709[] = {
        1.164,  1.164, 1.164,
          0.0, -0.213, 2.112,
        1.793, -0.533,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
static const GLfloat kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

typedef struct _Frame_Size
{
    int w;
    int h;
}Frame_Size;

@interface MR0x14VideoRenderer ()
{
    GLuint plane_textures[2];
    Frame_Size frameSize[2];
}

@property GLuint program;

@end

@implementation MR0x14VideoRenderer

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
            0
        };
        NSOpenGLPixelFormat *pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
        
        if (!pf)
        {
            NSLog(@"No OpenGL pixel format");
        }
        
        NSOpenGLContext* context = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
        
    #if ESSENTIAL_GL_PRACTICES_SUPPORT_GL3 && defined(DEBUG)
        // When we're using a CoreProfile context, crash if we call a legacy OpenGL function
        // This will make it much more obvious where and when such a function call is made so
        // that we can remove such calls.
        // Without this we'd simply get GL_INVALID_OPERATION error for calling legacy functions
        // but it would be more difficult to see where that function was called.
        CGLEnable([context CGLContextObj], kCGLCECrashOnRemovedFunctions);
    #endif
        
        [self setPixelFormat:pf];
        [self setOpenGLContext:context];
        CGLContextObj ctx = context.CGLContextObj;
        NSLog(@"CGLContextObj:%p",ctx);
    #if 1 || SUPPORT_RETINA_RESOLUTION
        // Opt-In to Retina resolution
        [self setWantsBestResolutionOpenGLSurface:YES];
    #endif // SUPPORT_RETINA_RESOLUTION
    }
    return self;
}


- (void)resetViewPort
{
    // We draw on a secondary thread through the display link. However, when
    // resizing the view, -drawRect is called on the main thread.
    // Add a mutex around to avoid the threads accessing the context
    // simultaneously when resizing.
    CGLLockContext([[self openGLContext] CGLContextObj]);
    
    // Get the view size in Points
    NSRect viewRectPoints = [self bounds];
    
#if SUPPORT_RETINA_RESOLUTION
    
    // Rendering at retina resolutions will reduce aliasing, but at the potential
    // cost of framerate and battery life due to the GPU needing to render more
    // pixels.
    
    // Any calculations the renderer does which use pixel dimentions, must be
    // in "retina" space.  [NSView convertRectToBacking] converts point sizes
    // to pixel sizes.  Thus the renderer gets the size in pixels, not points,
    // so that it can set it's viewport and perform and other pixel based
    // calculations appropriately.
    // viewRectPixels will be larger than viewRectPoints for retina displays.
    // viewRectPixels will be the same as viewRectPoints for non-retina displays
    NSRect viewRectPixels = [self convertRectToBacking:viewRectPoints];
    
#else //if !SUPPORT_RETINA_RESOLUTION
    
    // App will typically render faster and use less power rendering at
    // non-retina resolutions since the GPU needs to render less pixels.
    // There is the cost of more aliasing, but it will be no-worse than
    // on a Mac without a retina display.
    
    // Points:Pixels is always 1:1 when not supporting retina resolutions
    NSRect viewRectPixels = viewRectPoints;
    
#endif // !SUPPORT_RETINA_RESOLUTION
    
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

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    [[self openGLContext] makeCurrentContext];
    CGLLockContext([[self openGLContext] CGLContextObj]);
    {
        if (self.program == 0) {
            
            glDisable(GL_DEPTH_TEST);
            
            BOOL succ = [self loadShaders];
            NSAssert(succ, @"build error");
            
            glUseProgram(self.program);
            
            glUniform1i(uniforms[UNIFORM_Y], 0);
            glUniform1i(uniforms[UNIFORM_UV], 1);
        }
        
        int type = CVPixelBufferGetPixelFormatType(pixelBuffer);
         
        assert(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange == type || kCVPixelFormatType_420YpCbCr8BiPlanarFullRange == type);
        
        IOSurfaceRef surface  = CVPixelBufferGetIOSurface(pixelBuffer);
        uint32_t cvpixfmt = CVPixelBufferGetPixelFormatType(pixelBuffer);
        struct vt_format *f = vt_get_gl_format(cvpixfmt);
        if (!f) {
            printf("CVPixelBuffer has unsupported format type\n");
            return;
        }

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        glEnable(GL_TEXTURE_RECTANGLE);
        glUseProgram(self.program);
        
        if (0 == plane_textures[0])
            glGenTextures(2, plane_textures);
        
        //设置纹理和采样器的对应关系
        glUniform1i(uniforms[UNIFORM_Y], 0);
        glUniform1i(uniforms[UNIFORM_UV], 1);
        
        CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
        
        const GLfloat * preferredConversion = NULL;
        if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
            BOOL isFullYUVRange = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange == type;
            if (isFullYUVRange) {
                preferredConversion = kColorConversion601FullRange;
            }
            else {
                preferredConversion = kColorConversion601;
            }
        }
        else {
            preferredConversion = kColorConversion709;
        }
        
        glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, preferredConversion);
        
        const bool planar = CVPixelBufferIsPlanar(pixelBuffer);
        const int planes  = (int)CVPixelBufferGetPlaneCount(pixelBuffer);
        assert(planar && planes == f->planes || f->planes == 1);
        
        GLenum gl_target = GL_TEXTURE_RECTANGLE;
        
        for (int i = 0; i < f->planes; i++) {
            GLfloat w = (GLfloat)IOSurfaceGetWidthOfPlane(surface, i);
            GLfloat h = (GLfloat)IOSurfaceGetHeightOfPlane(surface, i);
            Frame_Size size = frameSize[i];
            if (size.w != w || size.h != h) {
                glUniform2f(textureDimension[i], w, h);
                size.w = w;
                size.h = h;
                frameSize[i] = size;
            }
            glActiveTexture(GL_TEXTURE0 + i);
            glBindTexture(gl_target, plane_textures[i]);
            struct vt_gl_plane_format plane_format = f->gl[i];
            CGLError err = CGLTexImageIOSurface2D(CGLGetCurrentContext(),
                                                  gl_target,
                                                  plane_format.gl_internal_format,
                                                  w,
                                                  h,
                                                  plane_format.gl_format,
                                                  plane_format.gl_type,
                                                  surface,
                                                  i);

            if (err != kCGLNoError) {
                printf("error creating IOSurface texture for plane %d: %s\n",
                       0, CGLErrorString(err));
                return;
            } else {
                glTexParameteri(gl_target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glTexParameteri(gl_target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameterf(gl_target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameterf(gl_target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            }
        }
        
        const size_t pictureWidth = CVPixelBufferGetWidth(pixelBuffer);
        const size_t pictureHeight = CVPixelBufferGetHeight(pixelBuffer);
        // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
        CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(pictureWidth, pictureHeight), self.layer.bounds);
        
        // Compute normalized quad coordinates to draw the frame into.
        CGSize normalizedSamplingSize = CGSizeMake(0.0, 0.0);
        CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/self.layer.bounds.size.width, vertexSamplingRect.size.height/self.layer.bounds.size.height);
        
        // Normalize the quad vertices.
        if (cropScaleAmount.width > cropScaleAmount.height) {
            normalizedSamplingSize.width = 1.0;
            normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
        }
        else {
            normalizedSamplingSize.height = 1.0;
            normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
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
        glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, quadVertexData);
        glEnableVertexAttribArray(ATTRIB_VERTEX);
        
        GLfloat quadTextureData[] =  { // 坐标不对可能导致画面显示方向不对
            0, 1,
            1, 1,
            0, 0,
            1, 0,
        };
        
        glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
        glEnableVertexAttribArray(ATTRIB_TEXCOORD);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    CGLFlushDrawable([[self openGLContext] CGLContextObj]);
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

#pragma mark -  OpenGL shader compilation

static void IJK_GLES2_printString(const char *name, GLenum s) {
    const char *v = (const char *) glGetString(s);
    NSLog(@"[GLES2] %s = %s\n", name, v);
}

- (BOOL)loadShaders
{
    IJK_GLES2_printString("Version", GL_VERSION);
    IJK_GLES2_printString("Vendor", GL_VENDOR);
    IJK_GLES2_printString("Renderer", GL_RENDERER);
    IJK_GLES2_printString("Extensions", GL_EXTENSIONS);
    
    GLuint vertShader, fragShader;
    NSURL *vertShaderURL, *fragShaderURL;
    
    self.program = glCreateProgram();
    
    // Create and compile the vertex shader.
    vertShaderURL = [[NSBundle mainBundle] URLForResource:@"common" withExtension:@"vsh"];
    
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER URL:vertShaderURL]) {
        NSAssert(NO, @"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderURL = [[NSBundle mainBundle] URLForResource:@"2_sampler2DRect" withExtension:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER URL:fragShaderURL]) {
        NSAssert(NO, @"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(self.program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(self.program, fragShader);
    
    // Bind attribute locations. This needs to be done prior to linking.
    glBindAttribLocation(self.program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(self.program, ATTRIB_TEXCOORD, "texCoord");
    
    // Link the program.
    if (![self linkProgram:self.program]) {
        NSAssert(NO, @"Failed link program");
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (self.program) {
            glDeleteProgram(self.program);
            self.program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_Y] = glGetUniformLocation(self.program, "SamplerY");
    uniforms[UNIFORM_UV] = glGetUniformLocation(self.program, "SamplerUV");
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(self.program, "colorConversionMatrix");
    
    GLint textureDimensionY = glGetUniformLocation(self.program, "textureDimensionY");
    assert(textureDimensionY >= 0);
    textureDimension[0] = textureDimensionY;
    
    GLint textureDimensionUV = glGetUniformLocation(self.program, "textureDimensionUV");
    assert(textureDimensionUV >= 0);
    textureDimension[1] = textureDimensionUV;
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(self.program, vertShader);
        glDeleteShader(vertShader);
    }
    
    if (fragShader) {
        glDetachShader(self.program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL
{
    NSError *error;
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (sourceString == nil) {
        NSLog(@"Failed to load vertex shader: %@", [error localizedDescription]);
        return NO;
    }
    
    GLint status;
    const GLchar *source;
    source = (GLchar *)[sourceString UTF8String];
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}


@end
