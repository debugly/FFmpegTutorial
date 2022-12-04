//
//  MRMetalView.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/22.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRMetalView.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>

// Header shared between C code here, which executes Metal API commands, and .metal files, which
// uses these types as inputs to the shaders.
#import "MRMetalShaderTypes.h"
#import "AAPLMathUtilities.h"
#import "MRMetalBGRAPipeline.h"
#import "MRMetalNV12Pipeline.h"
#import "MRMetalNV21Pipeline.h"
#import "MRMetalYUV420PPipeline.h"
#import "MRMetalUYVY422Pipeline.h"
#import "MRMetalYUYV422Pipeline.h"
#import "MRMetalOffscreenRendering.h"

@interface MRMetalView ()
{
    CGRect _layerBounds;
    MRRenderingMode _renderingMode;
    
    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;

    CVMetalTextureCacheRef _metalTextureCache;
    /// These are the view and projection transforms.
    matrix_float4x4 _viewMatrix;
//    matrix_float4x4 _viewProjectionMatrix;
//    /// Metal resources and parameters for the sample animation.
//    matrix_float4x4 _projectionMatrix;
}

@property (atomic, assign) CVPixelBufferRef pixelBuffer;
@property (nonatomic, strong) __kindof MRMetalBasePipeline *metalPipeline;
@property (nonatomic, strong) id<MTLBuffer> mvp;
@property (atomic, assign) CGPoint ratio;//vector
@property (nonatomic, strong) MRMetalOffscreenRendering * offscreenRendering;

@end

@implementation MRMetalView

- (void)dealloc
{
    CVPixelBufferRelease(_pixelBuffer);
    CFRelease(_metalTextureCache);
}

- (BOOL)_setup
{
    self.device = MTLCreateSystemDefaultDevice();
    if (!self.device) {
        NSLog(@"No Support Metal.");
        return NO;
    }
    CVReturn ret = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, self.device, NULL, &_metalTextureCache);
    if (ret != kCVReturnSuccess) {
        NSAssert(NO, @"Create MetalTextureCache Failed:%d.",ret);
    }
    // Create the command queue
    _commandQueue = [self.device newCommandQueue]; // CommandQueue是渲染指令队列，保证渲染指令有序地提交到GPU
    //设置模型矩阵，逆时针旋转 90 度。
    
#warning 随机旋转
    int angle = arc4random() % 361;
    _viewMatrix = matrix4x4_rotation(2 * 3.14 * angle / 360, 0.0, 0.0, 1.0);
    
    MRMVPMatrix mvp = {_viewMatrix};
    self.mvp = [self.device newBufferWithBytes:&mvp
                                        length:sizeof(MRMVPMatrix)
                                       options:MTLResourceStorageModeShared];
    self.autoResizeDrawable = NO;
    self.enableSetNeedsDisplay = YES;
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self _setup];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)layout
{
    [super layout];
    _layerBounds = self.bounds;
}

- (void)setRenderingMode:(MRRenderingMode)renderingMode
{
    _renderingMode = renderingMode;
}

- (MRRenderingMode)renderingMode
{
    return _renderingMode;
}

- (CGSize)computeNormalizedSize:(CVPixelBufferRef)img
{
    int frameWidth = (int)CVPixelBufferGetWidth(img);
    int frameHeight = (int)CVPixelBufferGetHeight(img);
    // Compute normalized quad coordinates to draw the frame into.
    CGSize normalizedSamplingSize = CGSizeMake(1.0, 1.0);
    
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

- (void)setupPipelineIfNeed:(CVPixelBufferRef)pixelBuffer
{
    Class clazz = NULL;
    OSType type = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (type == kCVPixelFormatType_32BGRA) {
        clazz = [MRMetalBGRAPipeline class];
    } else if (type == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || type ==  kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        clazz = [MRMetalNV12Pipeline class];
    } else if (type == kCVPixelFormatType_420YpCbCr8PlanarFullRange || type ==  kCVPixelFormatType_420YpCbCr8Planar) {
        clazz = [MRMetalYUV420PPipeline class];
    } else if (type == kCVPixelFormatType_422YpCbCr8) {
        clazz = [MRMetalUYVY422Pipeline class];
    } else if (type == kCVPixelFormatType_422YpCbCr8FullRange || type == kCVPixelFormatType_422YpCbCr8_yuvs) {
        clazz = [MRMetalYUYV422Pipeline class];
    } else {
        NSAssert(NO, @"no suopport pixel:%d",type);
    }
    
    if (clazz) {
        [self setupPipelineWithClazz:clazz];
    }
}

- (void)setupNV21PipelineIfNeed
{
    [self setupPipelineWithClazz:[MRMetalNV21Pipeline class]];
}

- (void)setupPipelineWithClazz:(Class)clazz
{
    if (self.metalPipeline) {
        if ([self.metalPipeline class] != clazz) {
            NSAssert(NO, @"wrong pixel format:%@",NSStringFromClass(clazz));
        } else {
            return;
        }
    }
    self.metalPipeline = [clazz new];
}

- (void)_display:(CVPixelBufferRef)pixelBuffer isNV21:(BOOL)isNV21
{
    CGSize normalizedSize = [self computeNormalizedSize:pixelBuffer];
    CGPoint ratio = CGPointMake(normalizedSize.width, normalizedSize.height);
    
    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pixelBuffer) {
            CVPixelBufferRelease(self.pixelBuffer);
        }
        if (isNV21) {
            [self setupNV21PipelineIfNeed];
        } else {
            [self setupPipelineIfNeed:pixelBuffer];
        }
        self.ratio = ratio;
        self.pixelBuffer = pixelBuffer;
        [self setNeedsDisplay:YES];
    });
}

- (void)displayPixelBuffer:(CVPixelBufferRef)img
{
    [self _display:img isNV21:NO];
}

- (void)displayNV21PixelBuffer:(CVPixelBufferRef)img
{
    [self _display:img isNV21:YES];
}

/// Called whenever the view needs to render a frame.
- (void)drawRect:(NSRect)dirtyRect
{
    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor *renderPassDescriptor = self.currentRenderPassDescriptor;
    //MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer；同时也用来创建MTLRenderCommandEncoder
    if(renderPassDescriptor) {
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0f); // 设置默认颜色
        
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        // Set the region of the drawable to draw into.
        
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.drawableSize.width, self.drawableSize.height, -1.0, 1.0 }]; // 设置显示区域
        
        CVPixelBufferRef pixelBuffer = CVPixelBufferRetain(self.pixelBuffer);
        
        if (pixelBuffer) {
            [self.metalPipeline updateMVP:self.mvp];
            [self.metalPipeline updateVertexRatio:self.ratio device:self.device];
            //upload textures
            [self.metalPipeline uploadTextureWithEncoder:renderEncoder
                                                  buffer:pixelBuffer
                                            textureCache:_metalTextureCache
                                                  device:self.device
                                        colorPixelFormat:self.colorPixelFormat];
            
            CVPixelBufferRelease(pixelBuffer);
        }
        [renderEncoder endEncoding]; // 结束
        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:self.currentDrawable]; // 显示
    }
    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit]; // 提交；
}

- (CGImageRef)snapshot
{
    CVPixelBufferRef pixelBuffer = CVPixelBufferRetain(self.pixelBuffer);
    if (!pixelBuffer) {
        return nil;
    }
    
    int width  = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    CGSize targetSize = CGSizeMake(width, height);
    
    if (![self.offscreenRendering canReuse:targetSize]) {
        self.offscreenRendering = [MRMetalOffscreenRendering alloc];
    }
    
    MTLRenderPassDescriptor * passDescriptor = [self.offscreenRendering offscreenRender:CGSizeMake(width, height) device:self.device];
    if (!passDescriptor) {
        return NULL;
    }
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    
    if (!renderEncoder) {
        return NULL;
    }
    
    // Set the region of the drawable to draw into.
    [renderEncoder setViewport:(MTLViewport){0.0, 0.0, targetSize.width, targetSize.height, -1.0, 1.0}];
    
    [self.metalPipeline updateMVP:self.mvp];
    [self.metalPipeline updateVertexRatio:self.ratio device:self.device];
    //upload textures
    [self.metalPipeline uploadTextureWithEncoder:renderEncoder
                                          buffer:pixelBuffer
                                    textureCache:_metalTextureCache
                                          device:self.device
                                colorPixelFormat:self.colorPixelFormat];
    
    CVPixelBufferRelease(pixelBuffer);
    [renderEncoder endEncoding];
    [commandBuffer commit];
    
    return [self.offscreenRendering snapshot];
}

@end
