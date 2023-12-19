//
//  IJKMetalRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "IJKMetalRenderer.h"
#import "IJKMathUtilities.h"
#import "IJKMetalPipelineMeta.h"

@interface IJKMetalRenderer()
{
    vector_float4 _colorAdjustment;
    id<MTLDevice> _device;
    MTLPixelFormat _colorPixelFormat;
}

// The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
@property (nonatomic, strong) id<MTLRenderPipelineState> renderPipeline;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
#if IJK_USE_METAL_2
// The buffer that contains arguments for the fragment shader.
@property (nonatomic, strong) id<MTLBuffer> fragmentShaderArgumentBuffer;
@property (nonatomic, strong) id<MTLArgumentEncoder> argumentEncoder;
#endif
@property (nonatomic, strong) id<MTLBuffer> convertMatrixBuff;
@property (nonatomic, assign) BOOL convertMatrixChanged;

@property (nonatomic, strong) IJKMetalPipelineMeta *pipelineMeta;
@property (nonatomic, assign) BOOL vertexChanged;
@property (nonatomic, strong) NSLock *pilelineLock;

@end

@implementation IJKMetalRenderer

- (instancetype)initWithDevice:(id<MTLDevice>)device
              colorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    self = [super init];
    if (self) {
        NSAssert(device, @"device can't be nil!");
        _device = device;
        _colorPixelFormat = colorPixelFormat;
        _colorAdjustment = (vector_float4){0.0};
        _pilelineLock = [[NSLock alloc]init];
        _hdrPercentage = 0.0;
    }
    return self;
}

- (void)lock
{
    [self.pilelineLock lock];
}

- (void)unlock
{
    [self.pilelineLock unlock];
}

- (BOOL)isHDR
{
    return self.pipelineMeta.hdr;
}

- (BOOL)matchPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    return [self.pipelineMeta metaMatchedCVPixelbuffer:pixelBuffer];
}

- (BOOL)createRenderPipelineIfNeed:(CVPixelBufferRef)pixelBuffer
{
    if (self.renderPipeline) {
        return YES;
    }
    
    if (!self.pipelineMeta) {
        self.pipelineMeta = [IJKMetalPipelineMeta createWithCVPixelbuffer:pixelBuffer];
    }
    
    if (!self.pipelineMeta) {
        return NO;
    }
    
    self.convertMatrixChanged = YES;
    NSLog(@"render pipeline:%s",[[self.pipelineMeta description]UTF8String]);
    
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    NSURL * libURL = [bundle URLForResource:@"default" withExtension:@"metallib"];
    
    NSError *error;
    
    id<MTLLibrary> defaultLibrary = [_device newLibraryWithFile:libURL.path error:&error];
    
    NSParameterAssert(defaultLibrary);
    // Load all the shader files with a .metal file extension in the project.
    //id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"mvpShader"];
    NSAssert(vertexFunction, @"can't find Vertex Function:vertexShader");
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:self.pipelineMeta.fragmentName];
    NSAssert(vertexFunction, @"can't find Fragment Function:%@",self.pipelineMeta.fragmentName);
#if IJK_USE_METAL_2
    id <MTLArgumentEncoder> argumentEncoder =
        [fragmentFunction newArgumentEncoderWithBufferIndex:IJKFragmentBufferLocation0];
    
    NSUInteger argumentBufferLength = argumentEncoder.encodedLength;

    _fragmentShaderArgumentBuffer = [_device newBufferWithLength:argumentBufferLength options:0];

    _fragmentShaderArgumentBuffer.label = @"Argument Buffer";
    
    [argumentEncoder setArgumentBuffer:_fragmentShaderArgumentBuffer offset:0];
#endif
    // Configure a pipeline descriptor that is used to create a pipeline state.
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = _colorPixelFormat; // 设置颜色格式
    pipelineStateDescriptor.sampleCount = 1;
    
    id<MTLRenderPipelineState> pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                                      error:&error]; // 创建图形渲染管道，耗性能操作不宜频繁调用
    // Pipeline State creation could fail if the pipeline descriptor isn't set up properly.
    //  If the Metal API validation is enabled, you can find out more information about what
    //  went wrong.  (Metal API validation is enabled by default when a debug build is run
    //  from Xcode.)
    NSAssert(pipelineState, @"Failed to create pipeline state: %@", error);
#if IJK_USE_METAL_2
    self.argumentEncoder = argumentEncoder;
#endif
    self.renderPipeline = pipelineState;
    return YES;
}

- (void)setVertexRatio:(CGSize)vertexRatio
{
    if (!CGSizeEqualToSize(self.vertexRatio, vertexRatio)) {
        _vertexRatio = vertexRatio;
        self.vertexChanged = YES;
    }
}

- (void)setTextureCrop:(CGSize)textureCrop
{
    if (!CGSizeEqualToSize(self.textureCrop, textureCrop)) {
        _textureCrop = textureCrop;
        self.vertexChanged = YES;
    }
}

- (void)setRotateType:(int)rotateType
{
    if (_rotateType != rotateType) {
        _rotateType = rotateType;
        self.vertexChanged = YES;
    }
}

- (void)setRotateDegrees:(float)rotateDegrees
{
    if (_rotateDegrees != rotateDegrees) {
        _rotateDegrees = rotateDegrees;
        self.vertexChanged = YES;
    }
}

- (void)setAutoZRotateDegrees:(float)autoZRotateDegrees
{
    if (_autoZRotateDegrees != autoZRotateDegrees) {
        _autoZRotateDegrees = autoZRotateDegrees;
        self.vertexChanged = YES;
    }
}

- (void)updateColorAdjustment:(vector_float4)s
{
    float s0 = s[0];
    float s1 = s[1];
    float s2 = s[2];
    float s3 = s[3];
    
    vector_float4 d = _colorAdjustment;
    float d0 = d[0];
    float d1 = d[1];
    float d2 = d[2];
    float d3 = d[3];
    
    if (s0 != d0 || s1 != d1 || s2 != d2 || s3 != d3) {
        _colorAdjustment = s;
        self.convertMatrixChanged = YES;
    }
}

- (void)updateVertexIfNeed
{
    if (!self.vertexChanged) {
        return;
    }
    
    self.vertexChanged = NO;
    
    float x = self.vertexRatio.width;
    float y = self.vertexRatio.height;
    /*
     //https://stackoverflow.com/questions/58702023/what-is-the-coordinate-system-used-in-metal
     
     triangle strip
       ↑y
     V3|V4
     --|--→x
     V1|V2
     📐-->V1V2V3
     📐-->V2V3V4
     
     texture
     |---->x
     |V3 V4
     |V1 V2
     ↓y
     */
    float max_t_y = 1.0 * (1 - self.textureCrop.height);
    float max_t_x = 1.0 * (1 - self.textureCrop.width);
    IJKVertex quadVertices[4] =
    {   //顶点坐标；                纹理坐标；
        { { -1.0 * x, -1.0 * y }, { 0.f, max_t_y } },
        { {  1.0 * x, -1.0 * y }, { max_t_x, max_t_y } },
        { { -1.0 * x,  1.0 * y }, { 0.f, 0.f } },
        { {  1.0 * x,  1.0 * y }, { max_t_x, 0.f } },
    };
    
    /// These are the view and projection transforms.
    matrix_float4x4 viewMatrix;
    float radian = radians_from_degrees(self.rotateDegrees);
    switch (self.rotateType) {
        case 1:
        {
            viewMatrix = matrix4x4_rotation(radian, 1.0, 0.0, 0.0);
            viewMatrix = matrix_multiply(viewMatrix, matrix4x4_translation(0.0, 0.0, -0.5));
        }
            break;
        case 2:
        {
            viewMatrix = matrix4x4_rotation(radian, 0.0, 1.0, 0.0);
            viewMatrix = matrix_multiply(viewMatrix, matrix4x4_translation(0.0, 0.0, -0.5));
        }
            break;
        case 3:
        {
            viewMatrix = matrix4x4_rotation(radian, 0.0, 0.0, 1.0);
        }
            break;
        default:
        {
            viewMatrix = matrix4x4_identity();
        }
            break;
    }
    
    if (self.autoZRotateDegrees != 0) {
        float zRadin = radians_from_degrees(self.autoZRotateDegrees);
        viewMatrix = matrix_multiply(matrix4x4_rotation(zRadin, 0.0, 0.0, 1.0),viewMatrix);
    }
    
    IJKVertexData data = {quadVertices[0],quadVertices[1],quadVertices[2],quadVertices[3],viewMatrix};
    self.vertexBuffer = [_device newBufferWithBytes:&data
                                             length:sizeof(data)
                                            options:MTLResourceStorageModeShared]; // 创建顶点缓存
}

- (void)updateConvertMatrixBufferIfNeed
{
    if (self.convertMatrixChanged || !self.convertMatrixBuff) {
        self.convertMatrixChanged = NO;
        
        IJKConvertMatrix convertMatrix = ijk_metal_create_color_matrix(self.pipelineMeta.convertMatrixType, self.pipelineMeta.fullRange);
        convertMatrix.adjustment = _colorAdjustment;
        convertMatrix.transferFun = self.pipelineMeta.transferFunc;
        convertMatrix.hdrPercentage = self.hdrPercentage;
        convertMatrix.hdr = self.pipelineMeta.hdr;
        self.convertMatrixBuff = [_device newBufferWithBytes:&convertMatrix
                                                      length:sizeof(IJKConvertMatrix)
                                                     options:MTLResourceStorageModeShared];
    }
}

#if IJK_USE_METAL_2
- (void)setHdrPercentage:(float)hdrPercentage
{
    if (0.0 <= hdrPercentage && hdrPercentage <= 1.0 && _hdrPercentage != hdrPercentage) {
        _hdrPercentage = hdrPercentage;
        self.convertMatrixChanged = YES;
    }
}

- (void)uploadTextureWithEncoder:(id<MTLRenderCommandEncoder>)encoder
                        textures:(NSArray*)textures
{
    [self updateVertexIfNeed];
    // Pass in the parameter data.
    [encoder setVertexBuffer:self.vertexBuffer
                      offset:0
                     atIndex:IJKVertexInputIndexVertices]; // 设置顶点缓存
 
    [self updateConvertMatrixBufferIfNeed];
    
    //Fragment Function(nv12FragmentShader): missing buffer binding at index 0 for fragmentShaderArgs[0].
    [self.argumentEncoder setArgumentBuffer:self.fragmentShaderArgumentBuffer offset:0];
    
    for (int i = 0; i < [textures count]; i++) {
        id<MTLTexture>t = textures[i];
        [self.argumentEncoder setTexture:t
                                 atIndex:IJKFragmentTextureIndexTextureY + i]; // 设置纹理
        
        // Indicate to Metal that the GPU accesses these resources, so they need
        // to map to the GPU's address space.
        if (@available(macOS 10.15, ios 13.0, *)) {
            [encoder useResource:t usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
        } else {
            // Fallback on earlier versions
            [encoder useResource:t usage:MTLResourceUsageRead];
        }
    }
    [self.argumentEncoder setBuffer:self.convertMatrixBuff offset:0 atIndex:IJKFragmentMatrixIndexConvert];
    
    // to map to the GPU's address space.
    if (@available(macOS 10.15, ios 13.0, *)) {
        [encoder useResource:self.convertMatrixBuff usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
    } else {
        // Fallback on earlier versions
        [encoder useResource:self.convertMatrixBuff usage:MTLResourceUsageRead];
    }
    
    [encoder setFragmentBuffer:self.fragmentShaderArgumentBuffer
                        offset:0
                       atIndex:IJKFragmentBufferLocation0];
    
    // 设置渲染管道，以保证顶点和片元两个shader会被调用
    [encoder setRenderPipelineState:self.renderPipeline];
    
    // Draw the triangle.
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                vertexStart:0
                vertexCount:4]; // 绘制
}

#else

- (void)uploadTextureWithEncoder:(id<MTLRenderCommandEncoder>)encoder
                        textures:(NSArray*)textures
{
    [self updateVertexIfNeed];
    // Pass in the parameter data.
    [encoder setVertexBuffer:self.vertexBuffer
                      offset:0
                     atIndex:IJKVertexInputIndexVertices]; // 设置顶点缓存
 
    for (int i = 0; i < [textures count]; i++) {
        id<MTLTexture>t = textures[i];
        [encoder setFragmentTexture:t atIndex:IJKFragmentTextureIndexTextureY + i];
    }
    
    [self updateConvertMatrixBufferIfNeed];
    
    [encoder setFragmentBuffer:self.convertMatrixBuff
                        offset:0
                       atIndex:IJKFragmentMatrixIndexConvert];
    
    // 设置渲染管道，以保证顶点和片元两个shader会被调用
    [encoder setRenderPipelineState:self.renderPipeline];
    
    // Draw the triangle.
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                vertexStart:0
                vertexCount:4]; // 绘制
}
#endif
@end
