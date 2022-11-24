//
//  MRMetalShaders.metal
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands.
#include "MRMetalShaderTypes.h"

// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 clipSpacePosition [[position]];
    
//    // Since this member does not have a special attribute, the rasterizer
//    // interpolates its value with the values of the other triangle vertices
//    // and then passes the interpolated value to the fragment shader for each
//    // fragment in the triangle.
//    float4 color;
    
    float2 textureCoordinate; // 纹理坐标，会做插值处理
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
             constant MRVertex *vertices [[buffer(MRVertexInputIndexVertices)]])
{
    RasterizerData out;
    out.clipSpacePosition = vertices[vertexID].position;
    out.textureCoordinate = vertices[vertexID].textureCoordinate;
    return out;
}

/// @brief bgra fragment shader
/// @param stage_in表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
/// @param texture表明是纹理数据，MRFragmentTextureIndexTextureY 是索引
fragment float4 bgraFragmentShader(RasterizerData input [[stage_in]],
               texture2d<float> textureY [[ texture(MRFragmentTextureIndexTextureY) ]])
{
    // sampler是采样器
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    //auto converted bgra -> rgba
    return textureY.sample(textureSampler, input.textureCoordinate);
}
