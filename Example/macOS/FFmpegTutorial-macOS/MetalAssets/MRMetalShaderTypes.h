//
//  MRMetalShaderTypes.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#ifndef MRMetalShaderTypes_h
#define MRMetalShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs
// match Metal API buffer set calls.
typedef enum MRVertexInputIndex
{
    MRVertexInputIndexVertices     = 0,
} MRVertexInputIndex;

//  This structure defines the layout of vertices sent to the vertex
//  shader. This header is shared between the .metal shader and C code, to guarantee that
//  the layout of the vertex array in the C code matches the layout that the .metal
//  vertex shader expects.
typedef struct
{
    vector_float4 position;
    vector_float2 textureCoordinate;
} MRVertex;

typedef struct {
    matrix_float3x3 matrix;
    vector_float3 offset;
} MRConvertMatrix;

typedef enum MRFragmentBufferIndex
{
    MRFragmentInputIndexMatrix     = 0,
} MRFragmentBufferIndex;

typedef enum MRFragmentTextureIndex
{
    MRFragmentTextureIndexTextureY  = 0,
    MRFragmentTextureIndexTextureU  = 1,
    MRFragmentTextureIndexTextureV  = 2,
} MRFragmentTextureIndex;

typedef enum MRYUVToRGBMatrixType
{
    MRYUVToRGBBT709Matrix = 0,
    MRYUVToRGBBT601Matrix = 1,
    MRUYVYToRGBMatrix = 2,
} MRYUVToRGBMatrixType;


#endif /* MRMetalShaderTypes_h */
