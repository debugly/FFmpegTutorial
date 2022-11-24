//
//  MRMetalRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

@import simd;
@import MetalKit;

#import "MRMetalRenderer.h"

// Header shared between C code here, which executes Metal API commands, and .metal files, which
// uses these types as inputs to the shaders.
#import "MRMetalShaderTypes.h"
#import "MRMetalBGRAPipeline.h"
#import "MRMetalNV12Pipeline.h"
#import "MRMetalNV21Pipeline.h"

@interface MRMetalRenderer ()

@property (atomic, assign) CVPixelBufferRef pixelBuffer;
@property (atomic, assign) CGPoint ratio;
@property (nonatomic, strong) __kindof MRMetalBasePipeline *metalPipeline;

@end

// Main class performing the rendering
@implementation MRMetalRenderer
{
    id<MTLDevice> _device;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;

    // The current size of the view, used as an input to the vertex shader.
    vector_uint2 _viewportSize;
    
    CVMetalTextureCacheRef _metalTextureCache;
}

- (void)dealloc
{
    CVPixelBufferRelease(_pixelBuffer);
    CFRelease(_metalTextureCache);
}

- (void)updateVertexWithxRatio:(float)xRatio yRatio:(float)yRatio
{
    if (xRatio != self.ratio.x || yRatio != self.ratio.y) {
        self.ratio = CGPointMake(xRatio, yRatio);
    }
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        _device = mtkView.device;
        
        CVReturn ret = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, _device, NULL, &_metalTextureCache);
        if (ret != kCVReturnSuccess) {
            NSAssert(NO, @"Create MetalTextureCache Failed:%d.",ret);
        }
        // Create the command queue
        _commandQueue = [_device newCommandQueue]; // CommandQueue是渲染指令队列，保证渲染指令有序地提交到GPU
    }
    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable to pass to the vertex shader.
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

- (void)setupPipelineIfNeed:(CVPixelBufferRef)pixelBuffer
{
    if (self.metalPipeline) {
        return;
    }
    
    OSType type = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (type == kCVPixelFormatType_32BGRA) {
        self.metalPipeline = [MRMetalBGRAPipeline new];
    } else if (type == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || type ==  kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        self.metalPipeline = [MRMetalNV12Pipeline new];
    } else {
        NSAssert(NO, @"no suopport pixel:%d",type);
    }
}

- (void)setupNV21PipelineIfNeed
{
    if (self.metalPipeline) {
        return;
    }
    self.metalPipeline = [MRMetalNV21Pipeline new];
}

/// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    //MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer；同时也用来创建MTLRenderCommandEncoder
    if(renderPassDescriptor) {
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0f); // 设置默认颜色
        
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, -1.0, 1.0 }]; // 设置显示区域
        
        CVPixelBufferRef pixelBuffer = CVPixelBufferRetain(self.pixelBuffer);
        
        if (pixelBuffer) {
            [self.metalPipeline updateVertexRatio:self.ratio device:_device];
            //upload textures
            [self.metalPipeline uploadTextureWithEncoder:renderEncoder
                                                  buffer:pixelBuffer
                                            textureCache:_metalTextureCache
                                                  device:_device
                                        colorPixelFormat:view.colorPixelFormat];
            
            CVPixelBufferRelease(pixelBuffer);
        }
        [renderEncoder endEncoding]; // 结束
        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:view.currentDrawable]; // 显示
    }
    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit]; // 提交；
}

- (void)display:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pixelBuffer) {
            CVPixelBufferRelease(self.pixelBuffer);
        }
        [self setupPipelineIfNeed:pixelBuffer];
        self.pixelBuffer = pixelBuffer;
    });
}

- (void)displayNV21:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pixelBuffer) {
            CVPixelBufferRelease(self.pixelBuffer);
        }
        [self setupNV21PipelineIfNeed];
        self.pixelBuffer = pixelBuffer;
    });
}

@end
