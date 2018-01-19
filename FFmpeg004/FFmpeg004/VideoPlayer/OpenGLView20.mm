//
//  OpenGLView.m
//  MyTest
//
//  Created by smy on 12/20/11.
//  Copyright (c) 2011 ZY.SYM. All rights reserved.
//

#import "OpenGLView20.h"

enum AttribEnum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXTURE,
    ATTRIB_COLOR,
};

enum TextureType
{
    TEXY = 0,
    TEXU,
    TEXV,
    TEXC
};

#pragma mark - shaders

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)


static NSData * copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    @autoreleasepool {
        width = MIN(linesize, width);
        NSMutableData *md = [NSMutableData dataWithLength: width * height];//此处会增长内存，最好不要用这种静态函数，据说不好
        Byte *dst = (Byte *)md.mutableBytes;
        for (NSUInteger i = 0; i < height; ++i) {
            memcpy(dst, src, width);
            dst += width;
            src += linesize;
        }
        return md;
    }

}


//这些都是什么意思啊。。。
NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 uniform mat4 modelViewProjectionMatrix;
 varying vec2 v_texcoord;
 
 void main()
 {
     gl_Position = modelViewProjectionMatrix * position;
     v_texcoord = texcoord.xy;
 }
 );

NSString *const yuvFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D s_texture_y;
 uniform sampler2D s_texture_u;
 uniform sampler2D s_texture_v;
 
 void main()//为什么这里面又写了一个main函数？？？
 {
     highp float y = texture2D(s_texture_y, v_texcoord).r;
     highp float u = texture2D(s_texture_u, v_texcoord).r - 0.5;
     highp float v = texture2D(s_texture_v, v_texcoord).r - 0.5;
     
     highp float r = y + 1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     
     gl_FragColor = vec4(r,g,b,1.0);
 }
 );

static BOOL validateProgram(GLuint prog)
{
	GLint status;
	
    glValidateProgram(prog);
    
#ifdef DEBUG
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
		NSLog(@"Failed to validate program %d", prog);
        return NO;
    }
	
	return YES;
}

static GLuint compileShader(GLenum type, NSString *shaderString)
{
	GLint status;
	const GLchar *sources = (GLchar *)shaderString.UTF8String;
	
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        NSLog(@"Failed to create shader %d", type);
        return 0;
    }
    
    glShaderSource(shader, 1, &sources, NULL);
    glCompileShader(shader);
	
#ifdef DEBUG
	GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
		NSLog(@"Failed to compile shader:\n");
        return 0;
    }
    
	return shader;
}

static void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout)
{
	float r_l = right - left;
	float t_b = top - bottom;
	float f_n = far - near;
	float tx = - (right + left) / (right - left);
	float ty = - (top + bottom) / (top - bottom);
	float tz = - (far + near) / (far - near);
    
	mout[0] = 2.0f / r_l;
	mout[1] = 0.0f;
	mout[2] = 0.0f;
	mout[3] = 0.0f;
	
	mout[4] = 0.0f;
	mout[5] = 2.0f / t_b;
	mout[6] = 0.0f;
	mout[7] = 0.0f;
	
	mout[8] = 0.0f;
	mout[9] = 0.0f;
	mout[10] = -2.0f / f_n;
	mout[11] = 0.0f;
	
	mout[12] = tx;
	mout[13] = ty;
	mout[14] = tz;
	mout[15] = 1.0f;
}

//#define PRINT_CALL 1

@interface OpenGLView20()
{
    
}
//此处声明的是私有属性跟方法
/*
 初始化YUV纹理
 */
- (void)setupYUVTexture;
/*
 */
- (void)loadShader;

/**
 编译着色代码
 @param shader        代码
 @param shaderType    类型
 @return 成功返回着色器 失败返回－1
 */
//- (GLuint)compileShader:(NSString*)shaderCode withType:(GLenum)shaderType;

/**
 渲染
 */
- (void)render;
@end

@implementation OpenGLView20

- (BOOL)doInit
{
    //    self.contentScaleFactor = [UIScreen mainScreen].scale;
    //    _viewScale = [UIScreen mainScreen].scale;
    
    CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:TRUE], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                    nil];//kEAGLColorFormatRGBA8什么意思？// kEAGLDrawablePropertyRetainedBacking 为FALSE，表示不想保持呈现的内容，因此在下一次呈现时，应用程序必须完全重绘一次。将该设置为 TRUE 对性能和资源影像较大，因此只有当renderbuffer需要保持其内容不变时，我们才设置 kEAGLDrawablePropertyRetainedBacking  为 TRUE
    
    //    创建上下文对象，用的是opengles2.0版本吗？
    _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_glContext ||
        ![EAGLContext setCurrentContext:_glContext]) {
        
        NSLog(@"failed to setup EAGLContext");
        //        self = nil;
        return false;
    }
    
    glGenFramebuffers(1, &_framebuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_videoW);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_videoH);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        
        NSLog(@"failed to make complete framebuffer object %x", status);
        //        self = nil;
        return false;
    }
    
    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        
        NSLog(@"failed to setup GL %x", glError);
        //        self = nil;
        return false;
    }
    
    [self loadShader];
    
    _vertices[0] = -1.0f;  // x0
    _vertices[1] = -1.0f;  // y0
    _vertices[2] =  1.0f;  // ..
    _vertices[3] = -1.0f;
    _vertices[4] = -1.0f;
    _vertices[5] =  1.0f;
    _vertices[6] =  1.0f;  // x3
    _vertices[7] =  1.0f;  // y3
    
    NSLog(@"OK setup GL");
    
    return YES;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        if (![self doInit])
        {
            self = nil;
        }
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        if (![self doInit])
        {
            self = nil;
        }
    }
    return self;
}

- (void)layoutSubviews
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @synchronized(self)
        {
            [EAGLContext setCurrentContext:_glContext];
            [self destoryFrameAndRenderBuffer];
            [self createFrameAndRenderBuffer];
        }
        
        glViewport(1, 1, self.bounds.size.width*_viewScale - 2, self.bounds.size.height*_viewScale - 2);
        glViewport(0, 0, self.bounds.size.width, self.bounds.size.height);
        
    });
}

- (void)setupYUVTexture//创建纹理
{
    @autoreleasepool {//放入自动收放池中，不然内存暴涨
        const NSUInteger frameWidth = _pFrame->width;
        const NSUInteger frameHeight = _pFrame->height;
        
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        
        if (0 == _textureYUV[TEXY])
            glGenTextures(3, _textureYUV);
        
        NSData *luma = copyFrameData((UInt8 *)_pFrame->data[0],
                                     _pFrame->linesize[0],
                                     _pFrame->width,
                                     _pFrame->height);
        
        NSData *chromaB = copyFrameData((UInt8 *)_pFrame->data[1],
                                        _pFrame->linesize[1],
                                        _pFrame->width / 2,
                                        _pFrame->height / 2);
        
        NSData *chromaR = copyFrameData((UInt8 *)_pFrame->data[2],
                                        _pFrame->linesize[2],
                                        _pFrame->width / 2,
                                        _pFrame->height / 2);
        
        Byte *lumaByte = (Byte *)luma.bytes;
        Byte *chromaBByte = (Byte *)chromaB.bytes;
        Byte *chromaRByte = (Byte *)chromaR.bytes;
        const UInt8 *pixels[3] = { lumaByte, chromaBByte, chromaRByte };
        
        
        const NSUInteger widths[3]  = { frameWidth, frameWidth / 2, frameWidth / 2 };
        const NSUInteger heights[3] = { frameHeight, frameHeight / 2, frameHeight / 2 };
        
        for (int i = 0; i < 3; ++i) {
            
            glBindTexture(GL_TEXTURE_2D, _textureYUV[i]);
            
            glTexImage2D(GL_TEXTURE_2D,
                         0,
                         GL_LUMINANCE,
                         (int)widths[i],
                         (int)heights[i],
                         0,
                         GL_LUMINANCE,
                         GL_UNSIGNED_BYTE,
                         pixels[i]);
            
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        }

    }
    
    
}
- (void)updateVertices
{
    _videoH = _pFrame->height;
    _videoW = _pFrame->width;
    const BOOL fit      = (self.contentMode == UIViewContentModeScaleAspectFit);
    const float width   = _pFrame->width;
    const float height  = _pFrame->height;
    const float dH      = (float)_videoH / height;
    const float dW      = (float)_videoW	  / width;
    const float dd      = fit ? MIN(dH, dW) : MAX(dH, dW);
    const float h       = (height * dd / (float)_videoH);
    const float w       = (width  * dd / (float)_videoW );
    
    _vertices[0] = - w;
    _vertices[1] = - h;
    _vertices[2] =   w;
    _vertices[3] = - h;
    _vertices[4] = - w;
    _vertices[5] =   h;
    _vertices[6] =   w;
    _vertices[7] =   h;
}

//显示图像
- (void)render
{
    
    
    //这里的坐标怎么来的
    static const GLfloat texCoords[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    [EAGLContext setCurrentContext:_glContext];//设置上下文对象
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
	glUseProgram(_program);
    
    [self setupYUVTexture];//创建纹理
    
    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, _textureYUV[i]);
        glUniform1i(_uniformSamplers[i], i);
    }
    
    GLfloat modelviewProj[16];
    mat4f_LoadOrtho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewProj);
    glUniformMatrix4fv(_uniformMatrix, 1, GL_FALSE, modelviewProj);
    
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, _vertices);
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_TEXTURE, 2, GL_FLOAT, 0, 0, texCoords);
    glEnableVertexAttribArray(ATTRIB_TEXTURE);
    
#if 0
    if (!validateProgram(_program))
    {
        NSLog(@"Failed to validate program");
        return;
    }
#endif
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_glContext presentRenderbuffer:GL_RENDERBUFFER];

}

#pragma mark - 设置openGL
+ (Class)layerClass
{
    return [CAEAGLLayer class];//必须写这个方法，只有[CAEAGLLayer class]类型的layer，才能在上面描绘opengl内容
}

- (BOOL)createFrameAndRenderBuffer//创建渲染缓冲区？
{
    glGenFramebuffers(1, &_framebuffer);
    glGenRenderbuffers(1, &_renderBuffer);//为renderbuffer申请一个id（或叫名字），1表示申请的renderbuffer个数，申请到的id不会为0，因为0是opengl保留的，也不能使用id是0的renderbuffer
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);//将_framebuffer设置为当前framebuffer
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    
    if (![_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer])
    {
        NSLog(@"attach渲染缓冲区失败");
    }
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);//将指定的renderbuffer装配到装配点上
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"创建缓冲区错误 0x%x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    return YES;
}

//销毁生成的buffer
- (void)destoryFrameAndRenderBuffer
{
    if (_framebuffer)
    {
        glDeleteFramebuffers(1, &_framebuffer);
    }
    
    if (_renderBuffer)
    {
        glDeleteRenderbuffers(1, &_renderBuffer);
    }
    
    _framebuffer = 0;
    _renderBuffer = 0;
}
/**
 加载着色器
 */
- (void)loadShader
{
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    
	_program = glCreateProgram();
	
    vertShader = compileShader(GL_VERTEX_SHADER, vertexShaderString);
	if (!vertShader)
        goto exit;
    
	fragShader = compileShader(GL_FRAGMENT_SHADER, yuvFragmentShaderString);
    if (!fragShader)
        goto exit;
    
	glAttachShader(_program, vertShader);
	glAttachShader(_program, fragShader);
	glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIB_TEXTURE, "texcoord");
	
	glLinkProgram(_program);
    
    GLint status;
    glGetProgramiv(_program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
		NSLog(@"Failed to link program %d", _program);
        goto exit;
    }
    
    result = validateProgram(_program);
    
    _uniformMatrix = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    
	_uniformSamplers[0] = glGetUniformLocation(_program, "s_texture_y");
    _uniformSamplers[1] = glGetUniformLocation(_program, "s_texture_u");
    _uniformSamplers[2] = glGetUniformLocation(_program, "s_texture_v");
    
exit:
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result) {
        
        NSLog(@"OK setup GL programm");
        
    } else {
        
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - 接口
- (void)displayYUV420pData:(AVFrame *)pframe
{
    //_pYuvData = data;
    //    if (_offScreen || !self.window)
    //    {
    //        return;
    //    }
    //[self clearFrame];
    _pFrame = pframe;
    [self updateVertices];
    [self render];
}

//    什么时候清屏？调用清屏会出现画面一闪一闪的，有问题
-(void)clearFrame
{
    if ([self window])
    {
        [EAGLContext setCurrentContext:_glContext];
        //glClearColor(1.0, 1.0, 1.0, 1.0);//设置清屏颜色，默认是黑色
        glClear(GL_COLOR_BUFFER_BIT);//清除由mask指定的buffer，mask是什么？？？？？
        glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
        [_glContext presentRenderbuffer:GL_RENDERBUFFER];
    }
    
}

@end
