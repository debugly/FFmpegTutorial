//
//  IJKMetalShaderTypes.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <simd/simd.h>

typedef enum IJKYUV2RGBColorMatrixType
{
    IJKYUV2RGBColorMatrixNone,
    IJKYUV2RGBColorMatrixBT601,
    IJKYUV2RGBColorMatrixBT709,
    IJKYUV2RGBColorMatrixBT2020
} IJKYUV2RGBColorMatrixType;

typedef enum IJKColorTransferFunc
{
    IJKColorTransferFuncLINEAR,
    IJKColorTransferFuncPQ,
    IJKColorTransferFuncHLG,
} IJKColorTransferFunc;

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs
// match Metal API buffer set calls.
typedef enum IJKVertexInputIndex
{
    IJKVertexInputIndexVertices  = 0,
} IJKVertexInputIndex;

//  This structure defines the layout of vertices sent to the vertex
//  shader. This header is shared between the .metal shader and C code, to guarantee that
//  the layout of the vertex array in the C code matches the layout that the .metal
//  vertex shader expects.

typedef struct
{
    vector_float2 position;
    vector_float2 textureCoordinate;
} IJKVertex;

typedef struct
{
    IJKVertex vertexes[4];
    matrix_float4x4 modelMatrix;
} IJKVertexData;

typedef struct {
    matrix_float3x3 colorMatrix;
    vector_float3 offset;
    vector_float4 adjustment;
    IJKColorTransferFunc transferFun;
    float hdrPercentage;
    bool hdr;
} IJKConvertMatrix;

typedef enum IJKFragmentBufferArguments
{
    IJKFragmentTextureIndexTextureY,
    IJKFragmentTextureIndexTextureU,
    IJKFragmentTextureIndexTextureV,
    IJKFragmentMatrixIndexConvert
} IJKFragmentBufferArguments;

typedef enum IJKFragmentBufferLocation
{
    IJKFragmentBufferLocation0,
} IJKFragmentBufferLocation;

typedef struct mp_format {
    uint32_t cvpixfmt;
    int planes;
    uint32_t formats[3];
} mp_format;

IJKConvertMatrix ijk_metal_create_color_matrix(IJKYUV2RGBColorMatrixType matrixType, int fullRange);
